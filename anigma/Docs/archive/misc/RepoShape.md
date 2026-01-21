# Repository Shape and Contract

## Product Identity
This repository ships **Anigma**, a macOS application designed for high-assurance data work, governance, and agentic workflows.

## Artifacts
The build process produces the following artifacts:
1.  **Anigma.app**: The main macOS application bundle (SwiftUI/AppKit).
2.  **Anigma.pkg**: An installer package for distribution.

## Architecture
The repository is structured to separate product code, owned libraries, and third-party dependencies.

-   **App/**: Contains the main application targets (MacApp).
-   **Packages/**: Contains modular SwiftPM libraries owned by this project (Client, HostApp, SharedUI, etc.).
-   **Native/**: Contains native code (C/C++) owned by this project.
-   **ThirdParty/**: Contains external dependencies (vendored or submodules).
-   **Tests/**: Contains tests for owned modules, separated from product code.
-   **Scripts/**: Contains build, test, and maintenance scripts.

## Build Contract
-   The repository must build on a fresh machine using `Scripts/build.sh`.
-   Tests must pass using `Scripts/test.sh`.
-   No third-party test files are compiled into product targets.
