# Publishing the gitguardian kit

This kit is a `schemaVersion: "3"` `kind: mixin`. "Publishing" means building
and pushing **one OCI image** with `docker buildx`: the `docker/sandbox-kit:3`
frontend named on the first line of `gitguardian.yaml` builds the ggshield
overlay from `gitguardian.dockerfile` and attaches the descriptor as annotations.

## Prerequisites

- `docker buildx`, with QEMU binfmt for the foreign arch
  (`docker run --privileged --rm tonistiigi/binfmt --install arm64`).
- `docker login` completed for the target registry.

## One repo, one tag

There is a single kit published as `ggshield-kit:latest` (plus a
`:<ggshield version>` tag). `:latest` is what we advertise: it always points at
the latest kit we deployed for sbx, not necessarily the latest ggshield release.

The install hook passes `--agent` explicitly for each assistant rather than
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

`publish.sh` builds both platforms, pushes `:latest` and `:<version>`, checks
the pushed manifest is a v3 kit, and prints the digest.

To validate without pushing (the frontend rejects a bad descriptor in a
second, then builds the recipe):

```console
docker buildx build . -f gitguardian.yaml --output type=cacheonly
```

The `-kit` suffix in the repo name follows the Docker Sandboxes convention:
`docker.io/<ns>/<kit>-kit`.

## Publish from GitHub Actions

`.github/workflows/publish-kit.yml` runs the same `scripts/publish.sh` on a
runner, so CI and a laptop publish identical artifacts.

**One-time setup** in the GitHub repo, all of it on a **`release` environment**
(*Settings → Environments → release*), as secrets:

| Name                  | Value                                              |
|-----------------------|----------------------------------------------------|
| `DOCKERHUB_USERNAME`  | The Docker Hub account used to log in (the login, not the email). It needs push rights in the `gitguardian` org — an org owner, or a member of a team granted *Read & Write* on `gitguardian/ggshield-kit`. |
| `DOCKERHUB_TOKEN`     | That account's **access token**, *Read & Write* scope |
| `DOCKERHUB_NAMESPACE` | Optional — overrides the default `gitguardian` namespace (e.g. to publish from a fork) |

The `publish` and `description` jobs both declare `environment: release`, which
is what makes those secrets resolve — an environment secret is invisible to a
job that is not bound to the environment. Any protection rule you put on the
environment (required reviewers, a wait timer, a branch restriction) therefore
gates the artifact push: the run pauses before `publish` starts. `validate`
needs no credentials and stays unbound, so pull requests are unaffected.

`DOCKERHUB_NAMESPACE` is read as `secrets.DOCKERHUB_NAMESPACE`, not `vars.`.
Keeping it a secret costs one thing: Actions masks a secret's value wherever it
appears in a log, so the namespace renders as `***` in the "Publishing to…"
line and in the `sbx run … --kit oci://docker.io/***/ggshield-kit:latest`
command in the job summary. Moving it to an
Actions *variable* (and reading it with `vars.`) is what buys back readable
logs, at the cost of it no longer living with the credentials.

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
  override the tag or the namespace.
- Pushing a `v*` tag — same, with the default inputs.
- Pull requests touching the kit files, `scripts/` or `.github/` run the
  validate job only (a two-platform build and an ownership audit), never a push.

The run's summary page prints the digest of what `:latest` now points at.

**The Docker Hub overview** (the repo's front page) is synced from
`docs/dockerhub-overview.md` by the workflow's last job, using the same token.


## Currently published

Repo `docker.io/gitguardian/ggshield-kit`, tag `:latest`. The hooks are
installed via `ggshield machine setup --agent <each supported assistant>
--no-git-hooks --no-honeytokens`, run as the agent user (uid 1000; no git hooks).
