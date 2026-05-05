# Rig Swift Diagnostics

Rig parses Swift compiler, test, and xcodebuild output into deterministic diagnostics.

## Commands

- `python3 scripts/rig.py swift build --target AnigmaDaemonCore`
- `python3 scripts/rig.py swift test --filter SomeTest`
- `python3 scripts/rig.py swift diagnose-log --log .build/logs/swift-build.log`
- `python3 scripts/rig.py swift warnings --target AnigmaDaemonCore`
- `python3 scripts/rig.py swift xcodebuild --scheme AnigmaDaemonCore`

## Output

Diagnostics are written to:

- `.build/rig/swift-diagnostics/latest.json`
- `.build/rig/swift-diagnostics/latest.md`
- `.build/rig/swift-diagnostics/latest.stdout.log`
- `.build/rig/swift-diagnostics/latest.stderr.log`

`swift diagnose-log` also records:

- `.build/rig/swift-diagnostics/latest.input.log`

## Classification

Supported categories:

- `ambiguous_init`
- `missing_type`
- `missing_import`
- `access_control`
- `concurrency_sendable`
- `actor_isolation`
- `mainactor_misuse`
- `deprecated_api`
- `unused_import`
- `unused_variable`
- `type_mismatch`
- `package_manifest`
- `module_cycle`
- `linker_error`
- `native_dependency_missing`
- `test_failure`
- `unknown`

## Optional Tool Policy

Rig may use `xcodebuild` when available, but it should degrade gracefully when optional tooling is missing.

If a tool is missing, Rig should emit:

- `tool_missing`
- `step_skipped`
- `recommendation`

and avoid crashing.

## Doctrine

Rig reports deterministic review guidance. It does not auto-fix compiler issues or silence warnings.
