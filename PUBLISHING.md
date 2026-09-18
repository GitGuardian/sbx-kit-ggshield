# Publishing the gitguardian kit

This kit is a `kind: mixin`, so it does **not** build a container image - it
layers onto whatever base agent image `--kit` is applied to. "Publishing" here
means pushing the **kit artifact** (the `spec.yaml` plus any `files/`) to an OCI
registry with `sbx kit push`. For a `schemaVersion: "2"` kit this produces a
tar+gzip layer with the spec in the manifest config blob and standard OCI
annotations, so registries and tooling can read kit metadata without pulling
layers.

## Prerequisites

- **A release-channel `sbx` on `PATH` - not a development build.** See
  [Publish from a release build](#publish-from-a-release-build) below; a dev
  build silently produces an artifact that no released `sbx` can resolve.
- `docker login` completed for the target registry - `sbx kit push` uses the
  Docker credential store. For Docker Hub:

  ```console
  docker login -u <dockerhub-id>
  # paste a Docker Hub access token as the password
  ```

## One repo, one tag

There is a single spec (`spec.yaml`) published as a single tag,
`ggshield-kit:latest`. Consumers pin by digest (sbx rejects OCI tags at
consume time), so the tag is only a label that points at the digest to copy.

The install step passes `--agent` explicitly for each assistant rather than
relying on `machine setup`'s auto-detection. Detection looks for `~/.claude`,
`~/.codex` and friends, and at build time the agent has never run, so a fresh
sandbox has none of them: bare `machine setup` finds nothing, installs nothing,
and still exits 0 - a silently unhooked sandbox. The assistant list is read back
from `ggshield` itself (an invalid `--agent` makes it print its choices).

## Publish

```console
./scripts/publish.sh                    # push to docker.io/gitguardian/ggshield-kit:latest
./scripts/publish.sh <namespace>        # push under <namespace>
./scripts/publish.sh <namespace> <tag>  # push under a tag other than :latest
```

`publish.sh` validates the spec, pushes, verifies the OCI layer media type, and
prints the digest to pin.

Or push directly:

```console
sbx kit validate .
sbx kit push . docker.io/gitguardian/ggshield-kit:latest
```

`sbx kit inspect` renders a spec's resolved policy surface, and is the quickest
way to confirm a spec says what you think before it goes out (it works on a
local directory as well as on an OCI reference):

```console
$ sbx kit inspect .
  Name:           gitguardian
  Kind:           mixin
  ...
  Policies:
    Network:      4 allow, 0 deny
    Credentials:  1 sources
    Environment:  1 variables, 0 proxy-managed
    Commands:     2 install, 0 startup, 0 init files
```

Note that `sbx kit inspect` / `pull` on an `oci://` reference authenticate
against the registry through your Docker account, so consumers need `sbx login`
even for this public repo.

The `-kit` suffix in the repo name follows the Docker Sandboxes convention:
`docker.io/<ns>/<kit>-kit` for the artifact, keeping `<kit>-image` free for a
container image (not used by a mixin).

## Publish from GitHub Actions

`.github/workflows/publish-kit.yml` runs the same `scripts/publish.sh` on a
runner, so CI and a laptop publish identical artifacts.

**One-time setup** in the GitHub repo, under *Settings → Secrets and variables
→ Actions*:

| Kind     | Name                  | Value                                              |
|----------|-----------------------|----------------------------------------------------|
| Secret   | `DOCKERHUB_USERNAME`  | The Docker Hub account used to log in (the login, not the email). It needs push rights in the `gitguardian` org — an org owner, or a member of a team granted *Read & Write* on `gitguardian/ggshield-kit`. |
| Secret   | `DOCKERHUB_TOKEN`     | That account's **access token**, *Read & Write* scope |
| Variable | `DOCKERHUB_NAMESPACE` | Optional — overrides the default `gitguardian` namespace (e.g. to publish from a fork) |

Create the token at *Docker Hub → Account settings → Personal access tokens*.
A password works too, but a scoped token is revocable on its own. An
organisation access token works as well, if the org uses them.

The namespace defaults to **`gitguardian`** in both the workflow and
`scripts/publish.sh`, so a plain `./scripts/publish.sh` and a plain workflow run
target the same place.

**Keeping the repo public.** `gitguardian/ggshield-kit` does not exist yet; the
first push creates it, with the privacy the namespace defaults to (for an
organisation, *Organization settings → Default repository privacy*). Set that to
**Public** before the first run, or flip the repo to Public straight after. The
workflow asserts the outcome either way: after pushing it reads the repo back
unauthenticated and fails the job if it is not publicly readable, so a private
artifact can never pass silently.

**Triggers:**

- *Actions → Publish kit → Run workflow* — pushes `:latest`. Inputs let you
  override the tag or the namespace, or turn on signing.
- Pushing a `v*` tag — same, with the default inputs.
- Pull requests touching `spec.yaml`, `scripts/` or `.github/` run the validate
  job only (`sbx kit validate` + `sbx kit inspect`), never a push.

The run's summary page prints the digest and a ready-to-paste `sbx run` line —
copy the digest into the tables here, in `README.md` and in
`docs/dockerhub-overview.md`, since every push mints a new one.

**Why the workflow pins `SBX_VERSION`.** It installs `docker-sbx` from
download.docker.com, which only ever ships release builds — the requirement in
[Publish from a release build](#publish-from-a-release-build). The composite
action `.github/actions/install-sbx` additionally rejects a version string that
looks like a dev build, and `publish.sh` still verifies the pushed layer's media
type. Bump `SBX_VERSION` deliberately and re-publish.

`sbx kit push` authenticates purely through `~/.docker/config.json`, which
`docker/login-action` writes — no `sbx login`, no sandbox daemon, and no
`sbx policy` state is needed just to publish.

**The Docker Hub overview** (the repo's front page) is synced from
`docs/dockerhub-overview.md` by the workflow's last job, using the same token.


## Publish from a release build

`sbx kit push` must be run from a **release** build of `sbx`. A development
build writes the kit layer as `application/vnd.oci.empty.v1+json` (a 2-byte
empty descriptor) where a release build writes
`application/vnd.oci.image.layer.v1.tar+gzip`. Released `sbx` clients match on
that media type strictly, so an artifact pushed from a dev build fails to
resolve for every consumer:

```
ERROR: resolve kits: kit "oci://...": no v2 kit layer found in manifest
       (expected media type application/vnd.oci.image.layer.v1.tar+gzip)
```

The push itself reports success, so the breakage only surfaces on the consumer
side. Check before publishing - a `-<n>-g<sha>` suffix means a dev build:

```console
sbx version
# v0.39.0                        <- release, safe to publish
# v0.39.0-rc1-383-g9a702c7a7     <- dev build, do NOT publish
```

`scripts/publish.sh` verifies the layer media type after pushing and fails if
the artifact came out wrong.

## Currently published

Repo `docker.io/gitguardian/ggshield-kit`, one tag. The hooks are installed
via `ggshield machine setup --agent <each supported assistant> --no-git-hooks
--no-honeytokens`, run as the agent user (uid 1000; no git hooks):

| Tag       | Covers      | Digest to pin |
|-----------|-------------|---------------|
| `:latest` | every agent | _not published yet - run `./scripts/publish.sh` and paste the digest it prints_ |

Nothing has been pushed under `gitguardian/ggshield-kit` yet. Everything
published while the kit lived elsewhere is superseded - earlier artifacts wired
the hook for a single agent, or predate enforcement entirely - and none of it
should be pinned. Treat the first run of the publish workflow as the first
release.

Push from a release `sbx` (v0.39.0 or later) and confirm the artifact carries an
`application/vnd.oci.image.layer.v1.tar+gzip` kit layer - `publish.sh` checks
that for you.

Re-run `./scripts/publish.sh` and update the digest here whenever the spec
changes. Every push rewrites the `org.opencontainers.image.created` annotation,
so the digest changes on each push even when the spec is untouched.

