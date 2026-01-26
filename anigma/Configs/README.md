Configuration defaults and environment presets.
Invariants: keep configs deterministic, avoid secrets in repo, align with governance defaults.

Entry points:
- Config files under `Configs/`.

Public surface:
- Default configurations consumed by runtime and daemon.

Build/test:
- No build targets; validate by running daemon/app configs.

Related docs:
- `../llmdocs/09-governance.md`
- `../llmdocs/04-daemon.md`
