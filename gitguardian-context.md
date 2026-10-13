## GitGuardian secret scanning (ggshield)

`ggshield` is installed and authenticated against `api.gitguardian.com`
through the sandbox proxy - `GITGUARDIAN_API_KEY` is a proxy-managed
placeholder inside the container, never the real key.

### Automatic enforcement (AI hook)

`ggshield` is installed as an AI hook for every coding assistant it
supports - whichever one you are, your hook file is already configured
(`~/.claude/settings.json`, `~/.codex/hooks.json`,
`~/.copilot/hooks/hooks.json`, `~/.cursor/hooks.json`, ...). Your own
actions are therefore scanned for secrets automatically; you do not need to
remember to scan manually. If the hook BLOCKS an action, a real secret was
detected. Do NOT retry or try to bypass it. Instead: locate the flagged
secret, remove it from the code, and tell the user it must be rotated. Only
proceed once the secret is gone.

Run `ggshield machine doctor` to see which assistants the hook is installed
for.

### Manual scans

Use these to catch hardcoded secrets on demand:

- `ggshield secret scan path -r .` - recursively scan the workspace files.
- `ggshield secret scan repo .` - scan full git history + working tree
  (catches secrets that were committed and later removed).
- `ggshield api-status` / `ggshield quota` - verify auth and remaining quota.

Run a scan after generating or editing code that might contain credentials,
and before any `git commit`. If a real secret is found, remove it and rotate
it - do not commit it. For the EU workspace or a self-hosted instance, the
operator must set `GITGUARDIAN_INSTANCE` and add that host to the kit's
network allowlist and credential inject block.
