# SwiftPM Package Graph

**Source Repository:** `swiftlang/swift-package-manager`
**Commit:** `770f14b0a593399b78787ecd728f35e870c4cf6e`
**Key File:** `Sources/PackageModel/Product.swift`
**Key Symbols:** `public enum ProductType` (L89), `public class Product` (L16)

## 1. Graph Representation
SwiftPM explicitly distinguishes between modules (targets) and products. In `Sources/PackageModel/Product.swift` (L16), the `Product` class is defined with a `type` (`ProductType`) and a list of `modules`. This confirms that a product is a higher-level output grouping built from lower-level targets.

## 2. Target and Product Distinction
The source explicitly enumerates `ProductType` at L89, supporting `.library`, `.executable`, `.snippet`, `.plugin`, `.test`, and `.macro`. This model demonstrates that regexing `Package.swift` strings is lossy because it misses the resolved logic binding these entities together.

## Anigma Doctrine Takeaways
- **Hygiene Rule:** Do not conflate targets and products in documentation or tooling.
- **Dependency Paths:** Anigma's tier validators should analyze the resolved package graph (via SwiftPM manifest/package description outputs, package graph source research, or a dedicated Anigma graph extractor) rather than relying solely on regex over `Package.swift`.
