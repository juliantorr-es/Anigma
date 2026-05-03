# Swift Tooling Research and Doctrine Update Proof

**Date:** 2026-05-03  
**Task:** `td-swift-tooling-research`  
**Status:** COMPLETE  

## Repositories Cloned and Studied
- `swiftlang/swift-package-manager` (commit: 770f14b0a593399b78787ecd728f35e870c4cf6e)
- `swiftlang/swift-llbuild` (commit: fd2284d2affcb33ed0ac88c1db861f73bc56a031)
- `swiftlang/swift-driver` (commit: 302fc811f4557302aa7be961321a4ae6053be0d1)
- `swiftlang/swift-syntax` (commit: 51c8c237beea1baa9cac64ef83cec68c6790506c)
- `swiftlang/swift-build` (commit: b2b2327d9b5c9023780e2bd4b2512225066ef202)

## Resources Consulted
- All findings are sourced **exclusively** from local upstream checkouts placed in `ExternalResearch/swift-tooling/`.
- No external AI documentation lookup tools (like Context7) were used. No official web documentation was used. All doctrine updates are fully source-grounded.

## Key Files and Symbols Inspected
- **SwiftPM:** `ProductType` (L89) and `Product` (L16) in `Sources/PackageModel/Product.swift`. `PluginAction` (L26) in `Sources/SPMBuildCore/Plugins/PluginInvocation.swift`. `getSwiftTestingSuites` (L196) in `Sources/Commands/Utilities/TestingSupport.swift`.
- **LLBuild:** `BuildEngineImpl` (L65) in `lib/Core/BuildEngine.cpp`.
- **Swift Driver:** `Job` (L21) in `Sources/SwiftDriver/Jobs/Job.swift`.
- **SwiftSyntax:** `ImportDeclSyntax` (L2939) and `ActorDeclSyntax` (L1416) in AST generation nodes.
- **Swift Build:** `SWBBuildServiceBundle` integrations across `SWBCore`.

## Doctrine Files Created/Updated
1. `Docs/governance/BUILD_TOOLING_DOCTRINE.md` (Updated)
   - Tightened package graph hygiene rule: explicitly require manifest/package description outputs or a dedicated extractor over regex parsing.
   - Added plugin usage and sandboxing rules tied to `PluginAction`.
   - Tightened compiler-driver doctrine: prefer machine-readable/structured outputs where available, otherwise explicitly preserve raw logs with stated parser limitations.
2. `Docs/governance/CODE_DOCTRINE.md` (Updated)
   - Sourced SwiftSyntax validator strategy directly to AST nodes.
3. `Docs/governance/TESTING_DOCTRINE.md` (Updated)
   - Clarified that while SwiftPM supports `swift-testing` natively, it does not support Anigma's custom JSON artifact schemas, requiring the custom `TestReceiptWriter` to remain.

## Validation Performed
- Validated no production code changes were made to Anigma Swift packages.
- Ran YAML parsing validation on all task definition files.
- Purged all `__MACOSX` and `.DS_Store` files and verified `.gitignore` hygiene.
- Verified no placeholder text exists in generated documentation.
