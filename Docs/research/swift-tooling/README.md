# Swift Tooling Research

**Goal:** Study upstream Swift tooling repositories and convert source-backed findings into Anigma doctrine updates for package graph hygiene, plugin policy, test behavior, build evidence, compiler-driver evidence, and SwiftSyntax-based validators.

This directory contains research notes derived directly from the source code of Swift's official tooling components.

## Repositories Studied
- [swift-package-manager](./swiftpm-package-graph.md) (commit: 770f14b0a593399b78787ecd728f35e870c4cf6e)
- [swift-llbuild](./llbuild-engine.md) (commit: fd2284d2affcb33ed0ac88c1db861f73bc56a031)
- [swift-driver](./swift-driver.md) (commit: 302fc811f4557302aa7be961321a4ae6053be0d1)
- [swift-syntax](./swiftsyntax-validator-design.md) (commit: 51c8c237beea1baa9cac64ef83cec68c6790506c)
- swift-build (commit: b2b2327d9b5c9023780e2bd4b2512225066ef202)

## Outputs
- `swiftpm-package-graph.md`
- `swiftpm-plugins.md`
- `swiftpm-test-behavior.md`
- `llbuild-engine.md`
- `swift-driver.md`
- `swiftsyntax-validator-design.md`
- `swift-build.md`

All findings here inform updates to Anigma's `BUILD_TOOLING_DOCTRINE.md`, `CODE_DOCTRINE.md`, and `TESTING_DOCTRINE.md`.
