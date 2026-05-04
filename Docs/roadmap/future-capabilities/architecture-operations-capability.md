# Architecture Operations Capability

**Document ID:** AOC-ROADMAP-2025-001
**Version:** 1.0
**Status:** FUTURE CAPABILITY - Not implementation-ready until anigma-app Debug builds reliably
**Owner:** Architecture

---

## Status

Future capability. Not implementation-ready until `anigma-app` Debug builds reliably.

**Prerequisite Gate:** `bash Scripts/validate_xcodebuild_debug.sh --scheme anigma-app` must pass consistently.

---

## Problem

Agents and developers currently spend too much time reconstructing:
- current task state from scattered JSONL files and markdown proofs
- validator state (tier violations, cycles, exported imports)
- proof freshness and stale artifact detection
- architecture violations across the module graph
- Notion schema drift between local indexes and remote databases
- diagrams and relationship graphs
- build/runtime lane status

This burns external AI quota (Codex, Gemini, ChatGPT) and makes the repository feel noisy and difficult to navigate.

** Core Insight:** Anigma should provide local architecture orchestration out of the box, so developers and agents do not waste quota rediscovering repo state.

---

## Current Prototype Surface

### Inventory of Existing Scripts and Artifacts

#### Validation Scripts

| Item | Current Path | Proves/Produces | Canonical/Derived/Presentation | Future Module Destination |
|---|---|---|---|---|
| xcodebuild Debug validation | `Scripts/validate_xcodebuild_debug.sh` | Product/runtime build lane status | Canonical | ValidationLaneCapability |
| Tier boundary validator | `tools/governance/scripts/validate_tiers.py` | Tier violation detection (ADR-0006) | Canonical | ValidationLaneCapability |
| Dependency cycle detector | `tools/governance/scripts/validate_no_cycles.py` | Cycle detection in dependency graph | Canonical | ValidationLaneCapability |
| Exported import validator | `tools/governance/scripts/validate_exported_imports.py` | @_exported import compliance | Canonical | ValidationLaneCapability |
| Package graph auditor | `Scripts/anigma_package_graph_audit.py` | SwiftPM graph analysis | Canonical | ValidationLaneCapability |

#### Evidence Indexes

| Item | Current Path | Proves/Produces | Canonical/Derived/Presentation | Future Module Destination |
|---|---|---|---|---|
| Task index | `Docs/td/index/tasks.jsonl` | Task state inventory | Canonical | EvidenceIndexCapability |
| Proof index | `Docs/td/index/proofs.jsonl` | Proof artifact inventory | Canonical | EvidenceIndexCapability |
| Report index | `Docs/td/index/reports.jsonl` | Report artifact inventory | Canonical | EvidenceIndexCapability |
| Relationship index | `Docs/td/index/relationships.jsonl` | Module relationship graph | Canonical | EvidenceIndexCapability |
| Diagram index | `Docs/td/index/diagrams.jsonl` | Diagram artifact inventory | Canonical | EvidenceIndexCapability |

#### Artifact Renderers

| Item | Current Path | Proves/Produces | Canonical/Derived/Presentation | Future Module Destination |
|---|---|---|---|---|
| Artifact renderer | `Scripts/anigma_artifact_render.py` | Proof markdown generation | Derived | DocumentationRenderCapability |
| TD bootstrap | `Scripts/td_bootstrap_from_docs.py` | Task/proof discovery from docs | Derived | EvidenceIndexCapability |
| TD context GC | `Scripts/td_context_gc.py` | Task context garbage collection | Derived | EvidenceIndexCapability |

#### Notion Publishing

| Item | Current Path | Proves/Produces | Canonical/Derived/Presentation | Future Module Destination |
|---|---|---|---|---|
| Notion client | `Scripts/notion/client.py` | Notion API primitives | Presentation-only | PublishingCapability (Notion adapter) |
| Notion publisher v2 | `Scripts/anigma_publish_notion_v2.py` | Notion page/database sync | Presentation-only | PublishingCapability (Notion adapter) |
| Publishing doctrine | `Docs/publishing/notion.md` | Notion boundary principles | Canonical | Documentation (contract) |

#### Diagram Generation

| Item | Current Path | Proves/Produces | Canonical/Derived/Presentation | Future Module Destination |
|---|---|---|---|---|
| Module relationships | `Docs/diagrams/generated/module-relationships.mmd` | Mermaid relationship diagram | Derived | DiagramCapability |

#### Proof Artifacts

| Item | Current Path | Proves/Produces | Canonical/Derived/Presentation | Future Module Destination |
|---|---|---|---|---|
| xcodebuild validation proof | `Docs/proofs/td-xcodebuild-debug-validation-lane.md` | Validation lane establishment | Canonical | ValidationLaneCapability (reference) |
| Tier violation resolution | `Docs/proofs/td-8f2e57-decouple-anigmapipeline-mediacore.md` | Architecture fix evidence | Canonical | Evidence (reference) |
| SecurityEventsManager fix | `Docs/proofs/td-securityeventsmanager-databasecore-tier-violation.md` | Tier boundary fix evidence | Canonical | Evidence (reference) |
| Notion sync proof | `Docs/proofs/notion-current-documentation-cockpit-sync.md` | Publishing capability evidence | Presentation-only | PublishingCapability (reference) |

---

## Target Capability Shape

### 1. EvidenceIndexCapability

**Purpose:** Build and maintain indexes of all task, proof, report, relationship, and diagram artifacts.

**Responsibilities:**
- Build task/proof/report/relationship/diagram indexes from file system
- Compute content hashes for stale artifact detection
- Emit receipts for all index mutations
- Detect stale artifacts (content hash mismatch)
- Provide query interface for agents and UI

**Contract:**
- `EvidenceIndexContract`: Protocol for index CRUD operations
- `StaleArtifactFinding`: DTO for stale artifact detection results
- `IndexReceipt`: Proof of index operation

### 2. ValidationLaneCapability

**Purpose:** Run validation lanes and normalize their output.

**Responsibilities:**
- Run xcodebuild Debug product/runtime lane
- Run SwiftPM describe + graph validators (tier, cycle, exported import)
- Normalize pass/fail output into structured results
- Classify failures as: product/runtime, graph, package-tooling, or external
- Emit validation receipts for each run

**Contract:**
- `ValidationLaneContract`: Protocol for lane execution
- `ValidationRunReceipt`: DTO for validation results
- `ValidationFailure`: DTO for classified failures

### 3. DocumentationRenderCapability

**Purpose:** Render JSON evidence to Markdown and other presentation formats.

**Responsibilities:**
- Render JSON evidence to Markdown
- Render proof summaries
- Render public docs pages
- Preserve deterministic output (hash-stable)
- Support templates for different artifact types

**Contract:**
- `DocumentationRenderContract`: Protocol for rendering operations
- `RenderReceipt`: DTO for render operation proof
- `TemplateRegistry`: Contract for template management

### 4. DiagramCapability

**Purpose:** Generate and manage diagram artifacts.

**Responsibilities:**
- Generate Mermaid/DOT/SVG/PNG artifacts
- Own relationship graph data model
- Provide graph snapshots for UI and publishers
- Maintain diagram-to-source traceability

**Contract:**
- `DiagramContract`: Protocol for diagram generation
- `DiagramArtifactRecord`: DTO for diagram metadata
- `GraphSnapshot`: DTO for relationship graph state

### 5. PublishingCapability

**Purpose:** Publish artifacts to external targets.

**Responsibilities:**
- Publish to Notion, Obsidian, static docs, or local filesystem
- Start with internal-token Notion support
- Later support OAuth for multi-workspace/user onboarding
- Treat all targets as presentation mirrors (not canonical)
- Dry-run mode for all publish operations
- Emit publish receipts

**Contract:**
- `PublishingContract`: Protocol for publish operations
- `PublishPlan`: DTO for dry-run publish intentions
- `PublishReceipt`: DTO for publish operation proof
- `PublisherConfig`: DTO for target configuration

### 6. IntegrationAuthCapability

**Purpose:** Manage provider authentication states.

**Responsibilities:**
- Manage provider auth states (connected/disconnected)
- Support internal tokens first (manual env var configuration)
- Support OAuth later (interactive flow)
- Store no secrets in Git
- Use governed local credential storage (macOS Keychain)

**Contract:**
- `IntegrationAuthContract`: Protocol for auth management
- `ProviderAuthState`: DTO for auth status
- `CredentialStorageContract`: Abstract credential storage

### 7. AgentContextCapability

**Purpose:** Emit compact machine-readable project context for local agents.

**Responsibilities:**
- Emit compact machine-readable project context
- Provide "current repo state" summaries
- Prevent Codex/Gemini/local LLM sessions from rediscovering state
- Output prompts, receipts, and task briefs
- Support JSON and structured text formats

**Contract:**
- `AgentContextContract`: Protocol for context generation
- `AgentContextBundle`: DTO for agent context export
- `ProjectStateSummary`: DTO for repo state snapshot

---

## Proposed Swift Module Boundaries

### Contract Modules (Tier 1 - Portable)

| Module | Purpose | Dependencies |
|---|---|---|
| `ArchitectureOperationsContracts` | Root capability contracts and types | None (foundation only) |
| `EvidenceIndexContracts` | Evidence index DTOs, protocols, errors | ArchitectureOperationsContracts |
| `ValidationLaneContracts` | Validation lane DTOs, protocols, errors | ArchitectureOperationsContracts |
| `DocumentationPublishingContracts` | Publishing DTOs, protocols, errors | ArchitectureOperationsContracts |
| `DiagramContracts` | Diagram DTOs, protocols, errors | ArchitectureOperationsContracts |
| `IntegrationAuthContracts` | Auth DTOs, protocols, errors | ArchitectureOperationsContracts |
| `AgentContextContracts` | Agent context DTOs, protocols | ArchitectureOperationsContracts |

### Core Modules (Tier 2 - Platform)

| Module | Purpose | Dependencies |
|---|---|---|
| `ArchitectureOperationsCore` | Core capability orchestration | All Contract modules, Foundation |
| `EvidenceIndexCore` | Index building and stale detection | EvidenceIndexContracts, Foundation |
| `ValidationLaneCore` | Validation orchestration | ValidationLaneContracts, Foundation |
| `DocumentationRenderCore` | Rendering engine | DocumentationPublishingContracts, Foundation |
| `DiagramCore` | Diagram generation | DiagramContracts, Foundation |

### Provider Adapters (Tier 2/3 - Native)

| Module | Purpose | Dependencies |
|---|---|---|
| `NotionPublishingAdapter` | Notion API integration | DocumentationPublishingContracts, IntegrationAuthContracts |
| `ObsidianPublishingAdapter` | Obsidian vault publishing | DocumentationPublishingContracts |
| `StaticSitePublishingAdapter` | Static site generation | DocumentationPublishingContracts |
| `FilesystemPublishingAdapter` | Local filesystem publishing | DocumentationPublishingContracts |
| `AgentContextAdapter` | Agent context export | AgentContextContracts |

### Rules

1. **Contract modules contain only** portable DTOs, protocols, receipts, and errors.
2. **Provider adapters contain** provider-specific API code.
3. **OAuth/provider-specific details do not leak** into portable contracts.
4. **Notion/Obsidian/GitHub/MCP code lives** behind adapters.
5. **The app/daemon composes** capabilities at runtime.
6. **Every mutation produces a receipt.**

---

## Canonical Data Model

### Evidence Index Records

```swift
// Portable DTOs - no platform dependencies

public struct TaskIndexRecord: Codable, Hashable, Sendable {
    public let taskId: String
    public let name: String
    public let status: TaskStatus
    public let priority: TaskPriority
    public let kind: TaskKind
    public let risk: RiskLevel
    public let sourcePath: String
    public let contentHash: String
    public let lastModifiedAt: Date
}

public struct ProofIndexRecord: Codable, Hashable, Sendable {
    public let proofId: String
    public let name: String
    public let taskId: String?
    public let artifactType: String
    public let proofPath: String
    public let sourcePath: String
    public let contentHash: String
    public let lastModifiedAt: Date
}

public struct ReportIndexRecord: Codable, Hashable, Sendable {
    public let reportId: String
    public let name: String
    public let reportType: String
    public let reportPath: String
    public let contentHash: String
    public let lastModifiedAt: Date
}

public struct RelationshipEdgeRecord: Codable, Hashable, Sendable {
    public let edgeId: String
    public let source: String
    public let target: String
    public let relationship: RelationshipType
    public let severity: SeverityLevel
    public let status: EdgeStatus
    public let sourcePath: String
    public let contentHash: String
}

public struct DiagramArtifactRecord: Codable, Hashable, Sendable {
    public let diagramId: String
    public let name: String
    public let diagramType: DiagramType
    public let sourcePath: String
    public let renderedPath: String?
    public let contentHash: String
    public let relatedReport: String?
    public let relatedTask: String?
}
```

### Validation Records

```swift
public struct ValidationRunReceipt: Codable, Hashable, Sendable {
    public let runId: String
    public let laneType: ValidationLaneType
    public let startTime: Date
    public let endTime: Date
    public let exitCode: Int
    public let duration: TimeInterval
    public let pass: Bool
    public let failures: [ValidationFailure]
    public let logPath: String?
}

public struct ValidationFailure: Codable, Hashable, Sendable {
    public let failureId: String
    public let classification: FailureClassification
    public let message: String
    public let location: String?
    public let severity: SeverityLevel
}

public enum ValidationLaneType: String, Codable, Sendable {
    case xcodebuildDebug
    case tierBoundary
    case dependencyCycle
    case exportedImports
    case packageGraph
}

public enum FailureClassification: String, Codable, Sendable {
    case productRuntime
    case graphArchitecture
    case packageTooling
    case external
}
```

### Publishing Records

```swift
public struct PublishPlan: Codable, Hashable, Sendable {
    public let planId: String
    public let publisherType: PublisherType
    public let target: String
    public let artifacts: [PublishArtifact]
    public let mode: PublishMode
}

public struct PublishReceipt: Codable, Hashable, Sendable {
    public let receiptId: String
    public let planId: String
    public let publisherType: PublisherType
    public let startTime: Date
    public let endTime: Date
    public let publishedCount: Int
    public let skippedCount: Int
    public let failedCount: Int
    public let failures: [PublishFailure]
}

public struct PublishArtifact: Codable, Hashable, Sendable {
    public let artifactId: String
    public let artifactType: String
    public let sourcePath: String
    public let targetPath: String
    public let action: PublishAction
}

public enum PublisherType: String, Codable, Sendable {
    case notion
    case obsidian
    case staticSite
    case filesystem
}

public enum PublishMode: String, Codable, Sendable {
    case dryRun
    case live
}

public enum PublishAction: String, Codable, Sendable {
    case create
    case update
    case delete
    case skip
}
```

### Stale Artifact Detection

```swift
public struct StaleArtifactFinding: Codable, Hashable, Sendable {
    public let findingId: String
    public let artifactType: String
    public let artifactId: String
    public let expectedHash: String
    public let actualHash: String?
    public let sourcePath: String
    public let detectedAt: Date
    public let severity: SeverityLevel
}
```

### Auth and Agent Context

```swift
public struct ProviderAuthState: Codable, Hashable, Sendable {
    public let provider: String
    public let accountId: String?
    public let connectionId: String?
    public let status: AuthStatus
    public let lastVerifiedAt: Date?
    public let scopes: [String]
}

public enum AuthStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case error
    case pending
}

public struct AgentContextBundle: Codable, Hashable, Sendable {
    public let bundleId: String
    public let generatedAt: Date
    public let projectName: String
    public let repoRoot: String
    public let currentBranch: String
    public let taskSummary: TaskSummary
    public let proofSummary: ProofSummary
    public let validationStatus: ValidationStatus
    public let diagramSummary: DiagramSummary
    public let staleArtifactCount: Int
}

public struct TaskSummary: Codable, Hashable, Sendable {
    public let total: Int
    public let byStatus: [TaskStatus: Int]
    public let byPriority: [TaskPriority: Int]
}

public struct ProofSummary: Codable, Hashable, Sendable {
    public let total: Int
    public let byArtifactType: [String: Int]
    public let staleCount: Int
}

public struct ValidationStatus: Codable, Hashable, Sendable {
    public let lastRunByLane: [ValidationLaneType: Date?]
    public let lastPassByLane: [ValidationLaneType: Bool?]
    public let currentFailures: Int
}

public struct DiagramSummary: Codable, Hashable, Sendable {
    public let total: Int
    public let byType: [DiagramType: Int]
    public let staleCount: Int
}
```

---

## Capability Flow

### 1. Audit Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AUDIT FLOW                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. ValidationLaneCapability                                        │
│     ├── Run xcodebuild Debug lane                                   │
│     ├── Run tier/cycle/exported import validators                   │
│     └── Emit ValidationRunReceipt for each                         │
│                                                                      │
│  2. EvidenceIndexCapability                                        │
│     ├── Update indexes from file system scan                       │
│     ├── Compute hashes                                              │
│     └── Emit IndexReceipt                                           │
│                                                                      │
│  3. Stale Detection                                                 │
│     ├── Compare current hashes with index                          │
│     ├── Emit StaleArtifactFinding for mismatches                    │
│     └── Update stale artifact count                                │
│                                                                      │
│  4. DocumentationRenderCapability                                  │
│     ├── Render proof markdown from JSONL + receipts                │
│     └── Emit RenderReceipt                                          │
│                                                                      │
│  5. PublishingCapability (optional)                                │
│     ├── Generate PublishPlan (dry-run)                              │
│     └── Update Notion cockpit                                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Trigger:** CLI command, daemon scheduled job, or agent request.
**Output:** Validation receipts, updated indexes, stale findings, rendered proofs.

### 2. Publish Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PUBLISH FLOW                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. EvidenceIndexCapability                                        │
│     └── Provide current indexes (tasks, proofs, reports, etc.)       │
│                                                                      │
│  2. DiagramCapability                                               │
│     └── Provide current diagram artifacts                          │
│                                                                      │
│  3. PublishingCapability                                            │
│     ├── Receive publish request                                    │
│     ├── Build PublishPlan (dry-run mode)                            │
│     ├── Show plan to user (if interactive)                          │
│     ├── Execute plan (live mode)                                   │
│     └── Emit PublishReceipt                                         │
│                                                                      │
│  4. IntegrationAuthCapability                                       │
│     └── Provide credentials for target provider                    │
│                                                                      │
│  5. NotionPublishingAdapter (example)                              │
│     ├── Map artifacts to Notion blocks                             │
│     └── Execute Notion API calls                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Trigger:** CLI publish command, scheduled sync, or manual sync request.
**Output:** Publish receipt, updated Notion/Obsidian/static site pages.

### 3. Agent Context Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      AGENT CONTEXT FLOW                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. AgentContextCapability                                         │
│     ├── Query EvidenceIndexCapability for current state            │
│     ├── Query ValidationLaneCapability for last run status          │
│     ├── Query DiagramCapability for diagram summary                 │
│     ├── Build AgentContextBundle                                    │
│     └── Emit context bundle                                         │
│                                                                      │
│  2. AgentContextAdapter                                             │
│     ├── Format bundle for target agent (Codex, Gemini, local)       │
│     └── Write to file or stdout                                     │
│                                                                      │
│  3. Codex/Gemini/local LLM                                          │
│     └── Consume context bundle instead of rediscovering state      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Trigger:** Agent session start, explicit context export command.
**Output:** AgentContextBundle in JSON or structured text format.

### 4. Docs Site Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DOCS SITE FLOW                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Curated manifest (Docs/README.md or similar)                   │
│     └── Defines which artifacts are public                           │
│                                                                      │
│  2. DocumentationRenderCapability                                  │
│     └── Render public-facing docs from canonical artifacts          │
│                                                                      │
│  3. StaticSitePublishingAdapter                                      │
│     └── Generate static HTML/pages from rendered markdown           │
│                                                                      │
│  4. NotionPublishingAdapter (optional mirror)                      │
│     └── Sync static content to Notion as mirror                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Trigger:** Docs build command, CI/CD pipeline, or manual publish.
**Output:** Static site, Notion mirror, or both.

---

## OAuth Roadmap

### Staged Authentication Approach

**Phase 0: Internal Token / Manual Configuration** (Current state)
- Use `NOTION_TOKEN` environment variable
- Manual Internal Integration setup in Notion workspace
- No credential persistence
- Suitable for single developer workspace

**Phase 1: Local Credential Storage + Connection UI**
- Add macOS Keychain integration for credential storage
- Add "Connect to Notion" UI in app
- Store connection metadata (account ID, token reference)
- Support multiple accounts/workspaces
- No OAuth yet - still uses internal tokens

**Phase 2: Notion OAuth Public Integration**
- Register Anigma as Notion public integration
- Implement OAuth 2.0 authorization code flow
- Add account onboarding UI
- Support token refresh
- Store OAuth tokens in Keychain

**Phase 3: Provider Abstraction**
- Abstract Notion-specific code behind `PublishingContract`
- Add Obsidian vault (local filesystem) support
- Add GitHub repository (for docs) support
- Add Google Drive support
- Each provider has own auth flow

**Phase 4: MCP Server/Client Integration** (Optional)
- Expose Anigma capabilities as MCP server
- Allow external agents to query Anigma state via MCP
- MCP acts as adapter boundary, not core
- Core capability contracts remain stable

### External Context

- **Notion internal connections** use static API tokens. these are suitable for single-workspace development.
- **Notion public connections** use OAuth 2.0 and are required for multi-workspace or user onboarding.
- **MCP authorization** can support OAuth-style protected resource flows, but MCP should be treated as an adapter boundary.
- **OAuth is intentionally deferred** until the local app/runtime lane is stable.

---

## Relationship to MCP

**Core Principle:** MCP is an adapter/interop boundary, not the source of truth.

- Anigma should expose and consume MCP **only after** its native capability contracts are stable.
- MCP tools can be used by external agents to query Anigma state later.
- Do not make MCP required for local validation.
- Anigma owns the evidence system; MCP is just one possible interface to it.

**Future MCP Integration Points:**
- MCP server exposing `ArchitectureOperationsCapability` queries
- MCP tools for:
  - `get_project_state`: Returns AgentContextBundle
  - `list_tasks`: Returns task index
  - `list_proofs`: Returns proof index
  - `run_validation`: Triggers validation lane
  - `get_diagram`: Returns diagram artifact

---

## UI Direction

### Future App Surface (Native SwiftUI)

**Architecture Cockpit Dashboard**
- Overview panel with health metrics
- Quick actions (run validation, publish, export context)
- Liquid Glass aesthetic (existing Anigma UI doctrine)
- Progressive disclosure of details

**Validation Lanes Panel**
- List of validation lanes (xcodebuild Debug, tier, cycle, exported)
- Last run time and status for each
- Run button for each lane
- View receipt button for each run
- Failure classification breakdown

**Stale Proofs Panel**
- List of stale artifacts with severity
- Source path and expected/actual hashes
- Refresh button to recompute hashes
- Navigate to file button

**Relationship Graph Panel**
- Interactive graph visualization
- Filter by module, tier, or relationship type
- Select node to see details
- Export as Mermaid/DOT/SVG
- Snapshot button for sharing

**Publish Plan Review**
- Preview of artifacts to be published
- Dry-run vs live mode toggle
- Diff view (what will change in Notion)
- Publish button with confirmation
- Publish history/receipts

**Provider Connection Status**
- List of connected providers (Notion, Obsidian, etc.)
- Connection status (connected/disconnected/error)
- Connect/Disconnect buttons
- Token refresh status
- Last sync time

**Agent Context Export**
- Export context bundle button
- Format selection (JSON, Markdown, Codex prompt)
- Copy to clipboard or save to file
- Preview of exported context

### UI Doctrine Compliance

- Follow existing **Native SwiftUI Liquid Glass aesthetic**
- **Progressive disclosure**: Start minimal, expand on demand
- **Avoid generic SaaS dashboard clutter**: No unnecessary cards, badges, or chrome
- **Bauhaus informs hierarchy and modularity**: Clear visual hierarchy, modular composition
- **Not flat primary-color cosplay**: No generic Material Design or Bootstrap aesthetics

---

## Migration Plan

### Phase 0: Stabilize Current Scripts

**Goal:** Ensure all existing scripts work reliably before migration.

- [ ] `Scripts/validate_xcodebuild_debug.sh` passes for `anigma-app` scheme
- [ ] All Python validators (`validate_tiers.py`, `validate_no_cycles.py`, `validate_exported_imports.py`) pass
- [ ] Notion schema bootstrap is stable and idempotent
- [ ] Publisher produces consistent results on double-run
- [ ] All JSONL indexes are valid and up-to-date

**Exit Criteria:** All scripts in current state produce consistent, reliable output.

### Phase 1: Define Contracts

**Goal:** Establish portable contracts for all capability boundaries.

- [ ] `ArchitectureOperationsContracts` module with shared types
- [ ] `EvidenceIndexContracts` module
- [ ] `ValidationLaneContracts` module
- [ ] `DocumentationPublishingContracts` module
- [ ] `DiagramContracts` module
- [ ] `IntegrationAuthContracts` module
- [ ] `AgentContextContracts` module

**Exit Criteria:** All contracts compile, have clear documentation, and cover all data models.

### Phase 2: Port Deterministic Index/Render Logic

**Goal:** Migrate deterministic, non-side-effecting logic first.

- [ ] JSONL indexer (move `td_bootstrap_from_docs.py` logic)
- [ ] Hash/stale detection logic
- [ ] Mermaid/DOT generation from graph data
- [ ] Evidence to Markdown rendering
- [ ] Unit tests for all ported logic

**Exit Criteria:** Index building, stale detection, and rendering work without shelling to scripts.

### Phase 3: Port Validation Orchestration

**Goal:** Migrate validation orchestration to native code.

- [ ] xcodebuild wrapper (ShellOut or Process-based)
- [ ] SwiftPM describe + graph validator wrapper
- [ ] Normalized validation receipt generation
- [ ] Failure classification logic
- [ ] Integration tests with real builds

**Exit Criteria:** Validation lanes run natively and produce receipts.

### Phase 4: Add Notion Adapter

**Goal:** Implement Notion publishing as governed capability.

- [ ] Notion API client behind `DocumentationPublishingContracts`
- [ ] Internal token support (existing flow)
- [ ] Schema discovery and bootstrap
- [ ] Property type mapping (markdown → Notion blocks)
- [ ] Idempotent upsert operations
- [ ] Dry-run mode with publish plan
- [ ] Live mode with receipt emission

**Exit Criteria:** Notion publishing works in dry-run and live modes with receipts.

### Phase 5: App UI

**Goal:** Add Cockpit UI to anigma-app.

- [ ] Architecture Cockpit dashboard
- [ ] Validation lanes panel
- [ ] Stale proofs panel
- [ ] Relationship graph panel
- [ ] Publish plan review UI
- [ ] Provider connection status display
- [ ] Agent context export UI

**Exit Criteria:** All cockpit panels functional and integrated with capability modules.

### Phase 6: OAuth and External Developer Onboarding

**Goal:** Add OAuth and external provider support.

- [ ] Notion OAuth 2.0 integration
- [ ] macOS Keychain credential storage
- [ ] Provider abstraction layer
- [ ] Multi-account/workspace support
- [ ] Connection UI in app
- [ ] MCP server integration (optional)

**Exit Criteria:** OAuth works, multiple accounts supported, MCP integration complete.

---

## Non-Goals

**Explicitly Out of Scope:**

1. **Do not migrate scripts into runtime before anigma-app builds.** The prerequisite gate is absolute.
2. **Do not make Notion canonical.** Notion is a presentation mirror; Git is source of truth.
3. **Do not require external AI agents for local validation.** All validation must work offline.
4. **Do not require MCP for local operation.** MCP is an optional adapter.
5. **Do not implement OAuth before local token mode is stable.** Phase 0-4 must complete first.
6. **Do not expose raw private cockpit data as public docs.** Public docs are curated, not raw.
7. **Do not replace Git as source of truth.** All canonical evidence stays in Git.

---

## Acceptance Criteria for Future Implementation

The `ArchitectureOperationsCapability` is considered **real and implemented** only when ALL of the following are true:

1. **anigma-app Debug builds** reliably using `Scripts/validate_xcodebuild_debug.sh --scheme anigma-app`.
2. **Anigma can generate indexes** without shelling out to ad hoc scripts (or has governed wrappers).
3. **Anigma can run validation lanes** (xcodebuild, tier, cycle, exported imports) and emit receipts.
4. **Anigma can detect stale proofs** by comparing content hashes.
5. **Anigma can produce a publish plan** for Notion or other targets.
6. **Anigma can publish to Notion** in both dry-run and live modes.
7. **Every mutation has a receipt** with timestamps, inputs, and outcomes.
8. **Local agent context export works** without paid cloud-agent reasoning.
9. **All contracts are stable** and documented.
10. **The app/daemon composes** capabilities at runtime from contract boundaries.

---

## Open Questions

1. **Runtime Location:** Should the first implementation live in daemon, app, or shared capability core?
   - Daemon: Better for scheduled jobs, background tasks
   - App: Better for UI integration, interactive flows
   - Shared core: Better for reuse, but needs clear boundaries

2. **Credential Storage:** What credential storage mechanism should be used on macOS?
   - Keychain Access (native macOS)
   - Custom encrypted file storage
   - Integration with macOS authentication framework

3. **Diagram Rendering:** Which diagrams deserve native rendering vs Mermaid/Graphviz artifacts?
   - Native: High-value, frequently accessed diagrams
   - Mermaid/Graphviz: Less critical, generated on demand

4. **Script Backing:** How much of the publisher should remain script-backed initially?
   - Full migration: Clean, but high effort
   - Hybrid: Scripts for now, migrate incrementally

5. **Public Docs Safety:** What public docs are safe to publish?
   - Only curated, non sensitive artifacts
   - Need clear classification scheme

6. **Local Model:** What minimum local model is sufficient for summarizing receipts?
   - No external calls required for local operation
   - Optional summarization for agent context

---

## References

### Source Artifacts
- `Docs/proofs/td-xcodebuild-debug-validation-lane.md` - Validation lane establishment
- `Docs/proofs/td-8f2e57-decouple-anigmapipeline-mediacore.md` - Tier violation example
- `Docs/proofs/td-securityeventsmanager-databasecore-tier-violation.md` - Tier fix example
- `Docs/proofs/notion-current-documentation-cockpit-sync.md` - Publishing evidence
- `Docs/publishing/notion.md` - Publishing doctrine
- `Scripts/validate_xcodebuild_debug.sh` - xcodebuild wrapper
- `Scripts/anigma_artifact_render.py` - Proof renderer
- `Scripts/anigma_publish_notion_v2.py` - Notion publisher
- `Scripts/notion/client.py` - Notion API client
- `Scripts/anigma_package_graph_audit.py` - Graph auditor
- `tools/governance/scripts/validate_tiers.py` - Tier validator
- `tools/governance/scripts/validate_no_cycles.py` - Cycle detector
- `tools/governance/scripts/validate_exported_imports.py` - Exported import validator
- `Docs/td/index/*.jsonl` - Evidence indexes
- `Docs/diagrams/generated/*.mmd` - Generated diagrams

### Doctrine References
- Portable by contract, native by executor
- Harness proves. Renderer explains. Publisher mirrors.
- Notion displays the graph. Anigma owns the graph.
- Agents should consume Anigma's cockpit, not reconstruct it.

---

## Document History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | Anigma Architecture | Initial roadmap creation |
