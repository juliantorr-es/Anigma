# SwiftPM Package Graph

**Source Repository:** `swiftlang/swift-package-manager`
**Commit:** `770f14b0a593399b78787ecd728f35e870c4cf6e`
**Key File:** `Sources/PackageModel/Product.swift`
**Key Symbols:** `public enum ProductType` (L89), `public class Product` (L16)

## 1. Graph Representation
SwiftPM explicitly distinguishes between modules (targets) and products. In `Sources/PackageModel/Product.swift` (L16), the `Product` class is defined with a `type` (`ProductType`) and a list of `modules`. This confirms that a product is a higher-level output grouping built from lower-level targets.

## 2. Target and Product Distinction
The source explicitly enumerates `ProductType` at L89, supporting `.library`, `.executable`, `.snippet`, `.plugin`, `.test`, and `.macro`. This model demonstrates that regexing `Package.swift` strings is lossy because it misses the resolved logic binding these entities together.

## 3. Context7 API Documentation Insights
Querying the Context7 API for `swiftlang/swift-package-manager` confirms the source-grounded findings:
- The Swift Package configuration explicitly separates `targets` from `products`, defining products as collections of targets (`.library(name: "MyLibrary", targets: ["MyLibrary"])`).
- Target dependencies are highly structured (`Target.Dependency`), allowing references like `.target(name:condition:)` or `.product(name:package:condition:)`. 
- Context7 emphasizes that "each product is made up of one or more Targets, the basic building block of a Swift package," reinforcing the Anigma doctrine rule against conflating targets and products.

## Anigma Doctrine Takeaways
- **Hygiene Rule:** Do not conflate targets and products in documentation or tooling.
- **Dependency Paths:** Anigma's tier validators should analyze the resolved package graph (via SwiftPM manifest/package description outputs, package graph source research, or a dedicated Anigma graph extractor) rather than relying solely on regex over `Package.swift`.
