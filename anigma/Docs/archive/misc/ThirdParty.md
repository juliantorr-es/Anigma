# Third-Party Dependencies

This repository enforces strict boundaries for third-party code. All external dependencies must be listed here.

## Policy
-   **No Copy-Paste**: Do not copy source files directly into the product source tree.
-   **Vendoring**: Use `ThirdParty/` for vendored code (submodules or pinned checkouts).
-   **SwiftPM**: Prefer SwiftPM dependencies in `Packages/Package.swift`.
-   **Tests**: Do not compile third-party test suites into the product.

## Inventory

### SwiftPM Dependencies
Managed via `Package.swift`.

- **swift-argument-parser**: Command-line argument parsing. (Apple)
- **swift-syntax**: Swift syntax parsing and manipulation. (Apple)
- **mlx-swift-lm**: Machine learning models on Apple Silicon. (MLX)
- **GRDB.swift**: SQLite wrapper. (Groue)
- **blake3-swift**: BLAKE3 hashing. (Nixberg)
- **grpc-swift**: gRPC support. (gRPC)
- **swift-numerics**: Numerical computing. (Apple)
- **swift-toml**: TOML parsing. (JDFergason)
- **swift-crypto**: Crypto primitives. (Apple)
- **swift-tree-sitter**: Syntax highlighting. (Tree-sitter)
- **swift-cmark**: Markdown parsing. (Apple)

### Vendored Code
Located in `ThirdParty/`.

- **swift-syntax**: Local checkout used for build stability.
