# Third Party Notices

This document contains open source and third-party software notices for components used in the Anigma project.

## Bundled Swift Packages
The following libraries are distributed alongside the Anigma project and are covered under their respective licenses:

- **swift-argument-parser** (v1.3.0) - Licensed under Apache 2.0 (Apple)
- **swift-syntax** (v510.0.0) - Licensed under Apache 2.0 (Apple)
- **mlx-swift** (v0.29.1) - Licensed under MIT (ML-Explore)
- **mlx-swift-lm** (v2.29.2) - Licensed under MIT (ML-Explore)
- **swift-numerics** (v1.0.2) - Licensed under Apache 2.0 (Apple)
- **swift-toml** (v1.0.0) - Licensed under MIT (jdfergason)
- **swift-crypto** (v3.0.0) - Licensed under Apache 2.0 (Apple)
- **swift-cmark** (v0.5.0) - Licensed under MIT/BSD (Apple)
- **hummingbird** (v2.0.0) - Licensed under Apache 2.0 (Hummingbird Project)
- **async-http-client** (v1.19.0) - Licensed under Apache 2.0 (Swift Server)
- **swift-sdk (MCP)** (v0.4.1) - Licensed under MIT (ModelContextProtocol)
- **postgres-nio** (v1.29.0) - Licensed under Apache 2.0 (Vapor)

*Note: Libraries without a specified version or pending review are tracked in `Docs/legal/THIRD_PARTY_INVENTORY.yaml` but are not yet formally listed here.*

## Bundled C/C++ Libraries (Sidecars)
The following libraries may be distributed as part of Anigma sidecars:

- **PDFium** - Licensed under Apache 2.0 and BSD 3-Clause (Google/PDFium Authors). 
  *Note: PDFium is explicitly EXCLUDED from the App Store alpha profile. PDFKit is the App Store default. Full transitive dependency notices for PDFium are pending review for optional/non-App-Store sidecar use.*

## Python Requirements (Development)
The Notion publisher scripts utilize standard Python libraries that may be subject to their respective permissive licenses (e.g., PSF License). Additional tools like `requests` and `pyyaml` operate under Apache 2.0 and MIT licenses, respectively.

## JavaScript / Frontend Requirements (Development)
The documentation generation tools utilize JavaScript packages such as `mermaid` and `vitepress`, which operate under the MIT license.
