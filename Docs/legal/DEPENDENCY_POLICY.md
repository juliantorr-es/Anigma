# Dependency & Licensing Policy

To maintain the commercial viability, App Store readiness, and open-source dual-licensing strategy of the Anigma project, all dependencies are strictly governed.

## Dependency Classification
Dependencies must be classified by their use case:
* `dev_tool`: Used only during development (e.g., linters, formatters).
* `build_tool`: Used to compile the application but not bundled.
* `test_tool`: Used in test harnesses.
* `bundled_library`: Compiled directly into the application binary.
* `bundled_sidecar`: Distributed as a separate binary alongside the application.
* `optional_external_tool`: Expected to be present on the user's system but not distributed by us.
* `runtime_service`: An external service communicated with over the network.

## License Risk Management
* **Low Risk**: Permissive licenses (MIT, BSD, ISC, zlib, Apache 2.0). Generally acceptable for all use cases, provided notice requirements are met.
* **Medium Risk**: Weak copyleft (LGPL, MPL). Requires explicit legal review to ensure dynamic linking boundaries or file-level boundaries are respected, especially for App Store distribution.
* **High Risk / Blocked**: Strong copyleft (GPL, AGPL) in third-party runtime binaries. **Must not be bundled** into a proprietary or App Store build unless a separate commercial license is obtained from the copyright holder, or explicit architectural isolation prevents viral contamination of the main binary.
* *Note*: Dev-only and build-only tools are treated differently from bundled runtime components and carry significantly lower licensing risk.

## Relicensing Rights
Anigma's own AGPL source can be dual-licensed because Anigma maintains copyright ownership or uses explicit inbound licensing terms from contributors.
**Crucially**, third-party copyleft code cannot be relicensed merely because it is used by Anigma. Any third-party dependency must be compatible with both the AGPL release and the Commercial release.
