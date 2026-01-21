# Polytropos Productionization Plan

This document outlines the engineering specification for evolving Polytropos from a capable engine into a mature, reliable, and ecosystem-friendly product. It is based on a detailed analysis comparing Polytropos to established open-source video editing frameworks like MLT, Kdenlive, and Shotcut.

The core strategy is to maintain our high-performance native Swift engine as the "Pro Path" while integrating MLT/FFmpeg as an optional, abstracted backend to serve as a "shock absorber and compatibility layer."

## 1. Interchange Workflow Tests

### What this means & why it matters
We must prove that Polytropos can reliably exchange projects with other open-source editors. This demonstrates that Polytropos is not a closed silo, which is critical for user trust and adoption in production environments where editors often move between tools.

### How to build those tests
*   **Test Matrix Definition:** Define and automate a test matrix covering `Source Tool × Export Format × Target Tool × Expected Fidelity`. This will include round-trips starting from Kdenlive, Shotcut, and Polytropos, using formats like MLT XML, EDL, FCPXML, and OTIO.
*   **Automated Testing:** Create integration tests that load a project, validate its structure, perform a small edit (e.g., add a clip, trim, add a transition), export to an interchange format, re-import, and then compare the resulting timeline against a baseline for structural integrity and metadata fidelity.
*   **Edge Cases:** Tests must cover media relinking, proxy workflows, non-standard frame rates, nested sequences, effect stacks, and other real-world complexities.
*   **Round-trip Fidelity Checks:** For simple sequences, a full export/import/re-export cycle should result in an identical timeline hash. For complex sequences, tolerances will be defined for acceptable variations.

## 2. Backend Fallback & Validation Layer

### What this means & why it matters
A robust fallback path from the native renderer to the MLT/FFmpeg backend ensures users are never stuck on a failed render due to an unsupported codec or a GPU-specific bug. A "backend-diff" mode is also needed for developers to diagnose discrepancies.

### How to implement it
*   **Fallback Logic:** In the `RendererBackendRegistry`, implement a try/catch mechanism. Attempt to render with the preferred native backend first. On failure, log the error and automatically re-attempt the export with the fallback backend (MLT/FFmpeg), notifying the user of the successful fallback.
*   **User Control:** Add a "Force legacy backend" flag in the export UI to allow users to bypass the native renderer when maximum compatibility is the priority.
*   **Validation/Diff Mode:** Implement a developer feature that renders a timeline with *both* backends and then performs a comparison pass. The diff tool will compare frame counts, resolutions, checksums/perceptual hashes of frames, and audio loudness levels, generating a report of any significant deviations. This will be integrated into CI/CD to catch regressions.

## 3. User Interface for Backend Selection

### What this means & why it matters
Exposing backend choices in a clear, user-friendly way provides transparency and gives advanced users control, while protecting novices with sane defaults.

### How to build it
*   **Settings Panel:** Add a "Renderer Backend" dropdown in the application's preferences with clear options: "Native (Fastest)", "Legacy/Compatible (MLT)", and "Auto (Native with Fallback)".
*   **Capability Summary:** Display a summary of the selected backend's capabilities (e.g., supported codecs, max resolution, hardware acceleration) directly in the settings panel.
*   **Export Override:** Allow users to override the default backend choice in the export dialog for one-off exports.

## 4. Package & Distribution Strategy

### What this means & why it matters
The fallback backends (MLT, FFmpeg) are external dependencies. We need a clear strategy for how they are packaged and distributed with Polytropos to ensure a seamless "out-of-the-box" experience.

### What to decide / implement
*   **Bundling vs. External Install:** Decide whether to bundle the MLT/FFmpeg libraries inside the app bundle (more convenient, larger size) or provide instructions/scripts for users to install them via a package manager like Homebrew (smaller app, more user friction).
*   **Versioning:** Pin specific, tested versions of MLT and FFmpeg for each Polytropos release and implement runtime checks to warn users of version mismatches.
*   **Installer/Bootstrap Script:** Provide a script to download and install the correct, verified versions of the external dependencies.
*   **Licensing Compliance:** Given the LGPL/GPL nature of these dependencies, all packaging and distribution must strictly adhere to their licensing terms.

## 5. Documentation & Licensing Transparency

### What this means & why it matters
Clarity around licensing is critical for institutional and professional adoption. Users must understand what license covers which part of the application and their obligations.

### What to implement
*   **"About / Credits" Screen:** An in-app screen that lists all third-party libraries, their versions, and links to their licenses and source code.
*   **Public Documentation:** The documentation site will include:
    *   A **Licensing Overview** page explaining the AGPL for Polytropos and the LGPL/GPL for its dependencies.
    *   A **Build & Packaging Guide** for developers who need to build from source.
    *   An **Interchange Format Guide** detailing the supported formats and any limitations.

## 6. Plugin-backend Documentation & SDK

### What this means & why it matters
Formalizing the `RendererBackend` protocol into a public, stable SDK will allow third-party developers to contribute new renderers (e.g., a Vulkan renderer, a cloud render farm client), future-proofing the architecture and fostering a community ecosystem.

### What to build / document
*   **Stable SDK Definition:** Refine and version the `RendererBackend` Swift protocol, clearly documenting all required methods, data types, error semantics, and capability reporting mechanisms.
*   **Template Plugin Project:** Create a "hello world" renderer plugin project with boilerplate code and build scripts to lower the barrier for new contributors.
*   **Plugin Lifecycle Documentation:** Detail how a plugin registers with the `RendererBackendRegistry`, advertises its capabilities, and is selected by the fallback logic.
*   **Testing Harness:** Provide a suite of tests that plugin developers can run to ensure their backend is compliant with the Polytropos core.
