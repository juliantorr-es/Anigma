CLI entry points and terminal tooling.
Invariants: keep commands governed, avoid untracked IO, emit receipts for mutations.

Entry points:
- `CLI/` scripts and CLIs (see `Package.swift` targets).

Public surface:
- CLI executables and helper tools.

Build/test:
- `swift build --target anigma-cli`

Related docs:
- `../llmdocs/05-cli.md`
- `../llmdocs/11-jobs-and-workflows.md`
- `../llmdocs/18-build-and-release.md`
