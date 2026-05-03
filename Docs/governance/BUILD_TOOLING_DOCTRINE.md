# Anigma Build Tooling Doctrine

**Document ID:** BUILD-TOOLING-DOCTRINE-2026-001  
**Version:** 1.0  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-03

---

## Purpose

This file is the canonical landing zone for build-tooling doctrine updates. It establishes guidelines based on direct research into SwiftPM, llbuild, Swift driver, and SwiftSyntax.

## Core Mandate

**No Vendoring Policy:** Production Anigma code must not depend on upstream internals unless explicitly justified by documented evidence. Do not fork SwiftPM, llbuild, swift-driver, or SwiftSyntax. Consume their outputs as evidence surfaces instead.

## 1. Package Graph Hygiene

- **Rule:** Do not conflate targets and products. 
- **Rationale:** SwiftPM resolves dependencies into `ResolvedPackage` and `ResolvedModule` instances. `Product` instances (defined in `Sources/PackageModel/Product.swift`) group modules and specify output shapes (`.library`, `.executable`, `.plugin`, `.test`).
- **Validation:** Tier boundary validators must consume resolved package graphs (via SwiftPM manifest/package description outputs, package graph source research, or a dedicated Anigma graph extractor. Do not rely solely on regex over Package.swift).

## 2. Plugin Usage and Sandboxing

- **Rule:** Plugins must strictly declare sandbox boundaries and network intents.
- **Rationale:** `PluginInvocation.swift` enforces specific `workingDirectory`, `writableDirectories`, and `allowNetworkConnections` constraints. Build tool plugins must not perform network operations.
- **Outputs:** Plugins generating source code must output to the designated `pluginGeneratedSources` directory as defined by `PluginAction.createBuildToolCommands`.

## 3. Build Evidence and Compiler-Driver Handling

- **Rule:** Handle compile diagnostics via proper evidence surfaces.
- **Rationale:** The Swift Driver (`Sources/SwiftDriver/Jobs/Job.swift`) tracks input and output states via a structured `BuildPlan`. LLBuild (`lib/Core/BuildEngine.cpp`) determines rebuild necessity using file signatures in `.build/build.db`.
- **Validation:** Anigma should prefer machine-readable or structured diagnostic outputs where available, and otherwise preserve raw logs as evidence with explicit parser limitations.
