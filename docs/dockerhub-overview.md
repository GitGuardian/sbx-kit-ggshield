# ggshield-kit — GitGuardian (ggshield) for Docker Sandboxes

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) **mixin** that adds
[GitGuardian](https://www.gitguardian.com/)'s
[`ggshield`](https://github.com/GitGuardian/ggshield) secret scanner to an AI
coding-agent sandbox, and wires it in as the agent's own **AI hook** so the
agent's actions are scanned for hardcoded secrets automatically.

> **Source, issues, and full docs:**
> https://github.com/GitGuardian/sbx-kits-gitguardian

## Key isolation property

`ggshield` inside the microVM only ever holds a placeholder value for
`GITGUARDIAN_API_KEY`. When it calls the GitGuardian API, the sbx proxy rewrites
the `Authorization: Token …` header with the real key (sourced from the host) on
the wire. **The real key never enters the sandbox** — not in the environment,
shell history, or `ps` output.

Egress is proxy-mediated too, but the kit's four allowed hosts are *added to*
the host's `sbx policy` — they do not narrow it. Use
`sbx policy init deny-all` if you want the kit's entries to be the entire
allowlist.

## One repo, one tag

`ggshield`'s AI hook is agent-specific (each assistant reads a different hook
file), but this repo ships **one artifact under `:latest` that covers them all**:
the kit configures the hook for every assistant `ggshield` supports, and each
assistant reads only its own file, so the rest are inert. Consumers **pin by
digest** (sbx rejects OCI tags at consume time) — the tag is just a label
pointing at the digest to copy.

| Agent   | Hook file the kit writes      |
|---------|-------------------------------|
| claude  | `~/.claude/settings.json`     |
| codex   | `~/.codex/hooks.json`         |
| copilot | `~/.copilot/hooks/hooks.json` |
| cursor  | `~/.cursor/hooks.json`        |

The pinned `ggshield` (1.54.0) supports AI hooks for `claude-code`, `codex`,
`copilot`, `cursor`, `vscode` and `vibe`. Other sbx agents (`gemini`,
`droid`, `kiro`, `opencode`) have no ggshield AI hook — layer the kit onto them
for the `ggshield` CLI + manual scanning, but there is no automatic enforcement
hook.

## Usage

Pin by digest (get the current digest from the
[repo Tags](https://hub.docker.com/r/gitguardian/ggshield-kit/tags) or the
[GitHub README](https://github.com/GitGuardian/sbx-kits-gitguardian#usage)) — the
same digest works for every agent:

```console
sbx run claude --kit "oci://docker.io/gitguardian/ggshield-kit@sha256:<digest>" .
sbx run codex  --kit "oci://docker.io/gitguardian/ggshield-kit@sha256:<digest>" .
```

Requires a GitGuardian API key (Personal or Service Account, `scan` scope) bound
on the host as the `gitguardian` credential; the sandbox only ever sees a
proxy-managed placeholder.

## What it installs

- `ggshield` from a pinned, digest-verified GitHub release.
- The AI hook for every supported assistant via `ggshield machine setup
  --agent <each one> --no-git-hooks --no-honeytokens`, run as the agent user,
  registering `PreToolUse` / `PostToolUse` / `UserPromptSubmit` handlers that
  run `ggshield secret scan ai-hook` inside the agent's own tool loop.

A blocked action means a real secret was detected — remove and rotate it, don't
retry or bypass. Manual scans (`ggshield secret scan path -r .`,
`ggshield secret scan repo .`) remain available as an escape hatch.

---

Licensed under the terms in the
[GitHub repository](https://github.com/GitGuardian/sbx-kits-gitguardian).
