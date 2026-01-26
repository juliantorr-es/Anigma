Vendor dependencies and binary assets.
Invariants: do not modify vendor sources without upstream tracking.

Entry points:
- Vendor subdirectories under `Vendor/`.

Public surface:
- External dependencies used by native capsules.

Build/test:
- Built via SwiftPM native targets.

Related docs:
- `../llmdocs/08-capsules.md`
