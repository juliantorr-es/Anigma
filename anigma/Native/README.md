Native C/C++ capsule implementations and shims.
Invariants: keep ABI stable, deterministic where specified, no hidden IO or non-governed side effects.

Entry points:
- `Native/` and `Packages/*/Sources/*Native`

Public surface:
- C ABI headers and native capsule code.

Build/test:
- Built via `swift build` native targets.

Related docs:
- `../llmdocs/08-capsules.md`
- `../llmdocs/07-render-pipeline.md`
