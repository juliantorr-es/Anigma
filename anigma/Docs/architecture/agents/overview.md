# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift` is the SwiftPM entry point.
- `Sources/` and `Packages/` contain Swift modules (for example, `Sources/HarmoniaModule`, `Packages/AnigmaCore`).
- `App/` holds macOS app targets and extensions (`App/MacApp`, `App/SafariExtension`).
- `Tests/` hosts XCTest targets named `Tests/<ModuleName>Tests`.
- `Scripts/` has build/packaging/CI helpers; `Docs/` contains VitePress docs; `Native/` and `ThirdParty/` hold native and vendored deps.

## Build, Test, and Development Commands
- `swift build` builds all SwiftPM products.
- `swift build --product anigma-app` builds the macOS app binary.
- `Scripts/build_mac_app.sh` creates a release app bundle under `.build/release/Anigma.app`.
- `swift test` runs all tests; `swift test --filter <ModuleName>Tests` runs a focused target.
- `cd Docs && npm install && npm run dev` runs the documentation site on `http://localhost:5173`.
- `Scripts/harmonia.sh <gate>` runs governance checks (for example, `swift6`, `security`, `trust`).

## Coding Style & Naming Conventions
- Format Swift with `swift-format --configuration .swift-format.json` (4-space indent, Allman braces, 120 columns, alphabetical imports).
- Lint with `./Scripts/ci/run-swiftlint.sh` or `swiftlint lint --config .swiftlint.yml`.
- Naming: modules end with `Module` (for example, `DiaplasionModule`); tests use `*Tests`; types use UpperCamelCase and filenames match the primary type when possible.

## Testing Guidelines
- XCTest via SwiftPM; tests live in `Tests/<ModuleName>Tests`.
- Run module-focused filters when changing a single area and ensure `swift test` is clean before PRs.
- No explicit coverage target is documented; add regression tests for new behavior.

## Commit & Pull Request Guidelines
- Commit messages commonly use conventional prefixes (`feat:`, `fix:`, `build:`), sometimes with scopes (`feat(mcp):`), or sentence-case imperatives.
- Prefer branch names like `feature/<name>` or `bugfix/<name>` per `Docs/community/contributing.md`.
- PRs should describe changes, reference issues, and pass checks; follow the governed tool-based workflow in `CONTRIBUTING.md` when required.

## Security & Configuration Tips
- macOS 14+, Xcode 15+, Swift 5.9+ are expected; Node 18+ is required for docs.
- Third-party code is vendored or managed via SwiftPM (`ThirdParty/`, `Packages/`).
