Third-party sources vendored into the repo.
Invariants: keep vendor code unmodified unless tracked, preserve licenses.

Entry points:
- Vendor subdirectories under `ThirdParty/`.

Public surface:
- External libraries used by native capsules.

Build/test:
- Built via native targets in SwiftPM.

Related docs:
- `../llmdocs/08-capsules.md`
