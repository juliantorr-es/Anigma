# Anigma

**A governed, local-first Swift stack for institutional AI.**

Anigma is a comprehensive platform designed for building and managing AI-powered applications with a strong emphasis on security, governance, and deterministic execution. It provides a robust core infrastructure and a rich ecosystem of capability modules that enable developers to create powerful and reliable AI solutions.

## Key Features

- **Governed AI:** Anigma enforces strict governance policies to ensure that all AI operations are secure, transparent, and compliant.
- **Local-First:** Anigma is designed to run locally, giving you full control over your data and models.
- **Swift-Powered:** Anigma is built on Swift, providing high performance, safety, and a modern development experience.
- **Modular Architecture:** Anigma's modular architecture allows you to easily extend and customize the platform to meet your specific needs.
- **Deterministic Execution:** Anigma ensures that all operations are deterministic, making it easy to reproduce and debug results.

## Architecture

Anigma follows a two-tier architecture:

- **Core Governance Layer:** This layer provides the fundamental building blocks of the platform, including the ECS, the job/workflow model, and the governance and security frameworks.
- **Capability Modules:** These modules provide high-level features and functionality, such as data processing, model inference, and user interface components.

For a more detailed overview of the architecture and governance rules, please refer to [AGENTS.md](AGENTS.md) and the governance documentation in `Docs/governance/`.

## Getting Started

To get started with Anigma, you will need to have Swift and the other required dependencies installed on your system. For a complete guide on how to set up your development environment, please refer to the [Development Guide](Docs/DEVELOPMENT_GUIDE.md).

Once you have your environment set up, you can build and validate the project using the Harmonia governance wrapper:

```bash
# Build with Swift 6 strict concurrency checks
Scripts/harmonia.sh swift6

# Run security validation
Scripts/harmonia.sh security

# Run trust/evidence validation
Scripts/harmonia.sh trust
```

For detailed development workflows, see the [Getting Started Guide](Docs/guide/getting-started.md).

## Documentation

Anigma's documentation is built with [VitePress](https://vitepress.dev/) and is located in the `Docs` directory. To view the documentation in your browser, you can run the following commands:

```bash
cd Docs
npm install
npm run dev
```

This will start a local development server and open the documentation in your browser.

## Deployment

### Apple Integration (macOS)
To deploy the Deep Apple Integration features (Widgets, Share Extension, File Provider), you can use the provided setup script to generate the necessary configuration files and get instructions:

```bash
./setup_xcode_integrations.sh
```

This script will:
*   Generate `Info.plist` files for each extension.
*   Provide step-by-step instructions for adding Extension Targets in Xcode.
*   Guide you through App Group configuration (`group.com.anigma.app`).

For manual setup details, please follow the [Apple Integration Deployment Guide](Docs/APPLE_INTEGRATION_DEPLOYMENT.md).

### Corporate Integration
To deploy the Corporate Integration features (OIDC, SCIM, Tenant Governance), please follow the [Corporate Integration Deployment Guide](Docs/CORPORATE_INTEGRATION_DEPLOYMENT.md).

This guide covers:
*   OIDC Configuration (Okta, Azure AD)
*   SCIM Provisioning Endpoints
*   Tenant Governance Policies
*   Microsoft 365 Connector (Graph API)
*   Google Workspace Connector (Directory, Drive, Calendar)
*   Slack Connector (Channels, History, Posting)
*   Jira Connector (Issues, Projects, Transitions)
*   ServiceNow Connector (Incidents, Requests, Table API)
*   DocuSign Connector (Envelopes, Status, Voiding)
*   Salesforce Connector (Accounts, Opportunities, SOQL)
*   Confluence Connector (Pages, Search, CQL)
*   Governance Engine (Policy, Audit, Rate Limiting)

### UI Polish (Phase 2)
- **Global Job Center**: Real-time job stream with status, progress, and receipts. Accessible from the governance strip.
- **Sources Center**: Centralized management for ingestion scopes, sources, and policies.
- **Context Awareness**: Unified context selection across Compass and Ask views.
- **Honest State**: UI reflects actual system state (running jobs, indexing status) via `AppState`.

## Repository Restructuring
For details on the repository structure and third-party dependency policy, see:
- [Repository Shape](Docs/RepoShape.md)
- [Third-Party Dependencies](Docs/ThirdParty.md)

## Contributing

We welcome contributions to Anigma! If you would like to contribute, please refer to our [Contributing Guide](CONTRIBUTING.md) for more information.

## Data Spine
- **DataCore**: Defines canonical IR (Tabular, Schema, Graph, Timeline) and Artifacts (Profile, ViewSpec, Change).
- **DataEngine**: Implements the compute pipeline (Ingestion, Profiling, Transforms, Query) as governed jobs.
- **RendererKit**: Defines the `Renderer` protocol and implements core renderers (`DataGridRenderer`, `ProfilerRenderer`).
- **DataUI**: Provides the Data Workspace UI with Grid and Profile views, powered by `RendererKit`.

## Data Spine Roadmap

### Phase 0-4: Foundation (Completed)
- [x] `DataCore` module with IR and Artifacts.
- [x] `DataEngine` module with storage and job definitions.
- [x] `DataUI` module with basic workspace structure.

### Phase 5: Core Renderers (Completed)
- [x] `RendererKit` module created.
- [x] `DataGridRenderer` implemented.
- [x] `ProfilerRenderer` implemented.
- [x] `TransformPreviewRenderer` implemented (via `TransformPreviewView`).

### Phase 6: Guided Workflows (Completed)
- [x] `Workflows` module created.
- [x] `WorkflowDefinition` and `WorkflowEngine` implemented.
- [x] Standard workflows (Messy CSV, Bank Export, Database Health) defined.

### Phase 7: Governance (Completed)
- [x] `RetentionPolicy` and `DataGovernancePolicy` defined in `DataCore`.
- [x] Governance checks integrated into `DataEngine`.

### Phase 8: Performance (Completed)
- [x] `IngestionOptions` for chunking defined.
- [x] `CacheManager` implemented in `DataEngine`.

### Phase 9: Testing (Completed)
- [x] `DataEngineTests` created.
- [x] Unit tests verified.

### Phase 10: Delivery (Completed)
- [x] V1 feature set (Grid, Profile, Transform Preview, Workflows) implemented in backend and UI.
- [x] Integrated `DataWorkspaceView` into `AnigmaAppMac` as a top-level Surface.
- [x] Added `Data` mode to Sidebar and App State.

## Work Lens (Workbench)
- **Unified Workbench**: A single project container for documents, data, and presentations.
- **Document Editor**: Block-based editor with structured IR, supporting rich text, tables, and images.
- **Sheet Editor**: Typed column-based spreadsheet with formula support and data provenance.
- **Deck Editor**: Slide builder with layout templates and live data embeds.
- **Agent Integration**: Agents propose changes as reviewable patches (diffs) against the document IR.
- **Universal Export**: Compile projects into PDF, DOCX, HTML, etc., with manifests and receipts.

## Deep Integration Roadmap

### Phase 0: Data Model Hardening (Completed)
- [x] Defined canonical integration objects in `AnigmaSystemSpine`:
  - `IntegrationAccount`: Represents a connected identity with health status.
  - `SyncTrack`: Tracks sync state per mode (capture, browse, correctness, write-back).
  - `ConflictRecord`: Tracks data divergence and resolution status.
  - `RepairAction`: Represents a recoverable failure with a recipe.
- [x] Ensured `Receipt` is attached to all integration actions.

### Phase 1: Unified Job Engine (Completed)
- [x] Implement shared local job queue in `AnigmaSystemSpine`.
- [x] Ensure jobs are idempotent and budget-aware.
- **Shared Job Queue**: Implemented `JobQueue` in `AnigmaSystemSpine` using App Group container for cross-process job submission.
- **Shared Job Model**: Defined `SharedJob` with idempotency, priority, and deadlines.
- **Job Types**: Defined core job types (`intake`, `refresh`, `resolveDeepLink`, `materializeFile`, `writeBack`, `rosterSync`, `repair`).

### Phase 2: Split "sync" into four explicit modes and wire them to UX (Completed)
- **Sync Manager**: Implemented `SyncManager` actor in `AnigmaSystemSpine` to track sync state per account and track type.
- **Sync Tracks**: Defined `SyncTrackState` with watermarks and verification timestamps.
- **Sync Status**: Defined explicit statuses (`idle`, `syncing`, `pendingVerification`, `queued`, `blocked`, `failed`).

### Phase 3: Build the Health and Repair UX as a core navigation surface (Completed)
- **Health Manager**: Implemented `HealthManager` in `AnigmaSystemSpine` to aggregate health snapshots.
- **Repair Recipes**: Defined `RepairRecipe` for actionable recovery steps.
- **Health Snapshots**: Created `HealthSnapshot` to provide a unified view of account health, sync states, and available repairs.

### Phase 4: Engineer consent fatigue as a lifecycle, not a one-time event (Completed)
- **Permission Lifecycle**: Implemented `PermissionLifecycleManager` to track scope grants and token expiry.
- **Scope Grants**: Defined `ScopeGrant` to track individual permission scopes and their expiration.
- **Health Integration**: Wired permission state to health checks (stubbed).

### Phase 5: Make conflicts a first-class, humane workflow (Completed)
- **Conflict Manager**: Implemented `ConflictManager` in `AnigmaSystemSpine` to track and resolve data divergence.
- **Conflict Model**: Defined `Conflict` struct with source system tracking and resolution status.
- **Resolution Logic**: Stubbed auto-resolution and manual resolution paths.

### Phase 6: Make data minimization the default product posture (Completed)
- **Coverage Manager**: Implemented `CoverageManager` in `AnigmaSystemSpine` to track and enforce data access boundaries.
- **Coverage Model**: Defined `CoverageScope` and `CoverageMap` to explicitly list allowed sites, drives, and folders.
- **Enforcement**: Stubbed logic to check if an external ID is covered before access.

### Phase 7: Treat every executable target as a constrained client of truth (Completed)
- **Surface Runtime**: Implemented `SurfaceRuntime` in `AnigmaSystemSpine` to provide a safe, thin wrapper for extensions.
- **Job Submission**: Exposed `enqueueJob` and `submitIntent` for extensions to request work without direct database mutation.
- **Read-Only Mirror**: Stubbed `readLocalMirror` for fast, safe data access.

### Phase 8: Build admin-grade controls without turning admins into content gods (Completed)
- **Admin Policy Manager**: Implemented `AdminPolicyManager` in `AnigmaSystemSpine` to enforce tenant-level policies.
- **Role Separation**: Defined `UserRole` (user, auditor, admin, itAdmin) to separate configuration from content access.
- **Policy Packs**: Defined `PolicyPack` to control connector availability, scope limits, and retention.

### Phase 9: Role-aware onboarding that doesn’t insult anyone’s intelligence (Completed)
- **Onboarding Manager**: Implemented `OnboardingManager` in `AnigmaSystemSpine` to manage role-specific flows.
- **Role Branching**: Defined distinct step sequences for User, Auditor, Admin, and IT Admin roles.
- **Flow State**: Tracked current step and completion status per user.

### Phase 10: Enforce UI consistency with a schema-driven connector UI (Completed)
- **Connector Manifest**: Implemented `ConnectorManifest` in `AnigmaSystemSpine` to describe connector capabilities and scopes.
- **Schema-Driven UI**: Defined `ConnectorScopeDefinition` and `ConnectorCapability` to allow dynamic UI generation.
- **Registry**: Implemented `ConnectorRegistry` to manage available connectors.

### Phase 11: Trust UX, not just "auditability" (Completed)
- **Trust UX Manager**: Implemented `TrustUXManager` in `AnigmaSystemSpine` to manage action previews and results.
- **Action Previews**: Defined `ActionPreview` to show users what will happen before execution.
- **Action Results**: Defined `ActionResult` to link outcomes to receipts and undo actions.

## Work Lens (Workbench)
- **AnigmaWork Module**: Implements the "Workbench" for document, spreadsheet, and presentation assembly.
- **Canvas IR**: A unified structured representation for all document types, enabling drag-and-drop and agentic manipulation.
- **Block System**: Reusable content blocks (Text, Table, Chart, Figure, Evidence) that maintain provenance.
- **Agent Lane**: A dedicated side panel for agents to propose changes (patches) to the Canvas IR, rather than direct edits.
- **Integration**: Fully integrated into the "Projects" view in Work mode.

## Data Spine
- **DataCore**: Defines canonical IR (Tabular, Schema, Graph, Timeline) and Artifacts (Profile, ViewSpec, Change).
- **DataEngine**: Implements the compute pipeline (Ingestion, Profiling, Transforms, Query) as governed jobs.
- **RendererKit**: Defines the `Renderer` protocol and implements core renderers (`DataGridRenderer`, `ProfilerRenderer`).
- **DataUI**: Provides the Data Workspace UI with Grid and Profile views, powered by `RendererKit`.
- **Workflows**: Defines standard data processing paths (e.g., "Messy CSV", "Bank Export") as declarative job graphs.

## Education Integrations
- **AnigmaEducation Module**: Canonical education models (Course, Assignment, Submission, Roster).
- **LTI 1.3 Connector**: Support for LTI Advantage (NRPS, AGS, Deep Linking).
- **OneRoster Connector**: Support for roster sync via OneRoster API.
- **Multi-Space Partitioning**: Hard separation between Personal and School spaces.

## Corporate Integrations
- [x] **Phase 1: Connector Framework & Trust Boundary**
  - [x] Unified Connector Protocol (Identity, Scope, Posture, Inventory)
  - [x] Tenant Boundary & Admin Console
  - [x] OIDC & SCIM Adapters
- [x] **Phase 2: Admin Control Surfaces**
  - [x] Sources Center
  - [x] Global Job Center
  - [x] Trust/Boundary Panel
- [x] **Phase 3: Identity & Device Management**
  - [x] SSO (OIDC/SAML)
  - [x] Managed App Config
- [x] **Phase 4: Core Connectors**
  - [x] Microsoft 365 (Graph)
  - [x] Google Workspace
  - [x] File Stores (Box, Dropbox)
- [x] **Phase 5: Communication & Workflow**
  - [x] Slack
  - [x] Jira
  - [x] ServiceNow
  - [x] DocuSign
  - [x] Salesforce
  - [x] Confluence
- [x] **Phase 6: Vertical Anchors**
  - [x] Legal (Clio)
  - [x] Accounting (QuickBooks)
  - [x] Nonprofit (Blackbaud)
- [x] **Phase 7: Hardening**
  - [x] Admin Console Exports
  - [x] Connector Policy Packs

- [x] **Phase 11: Export Tool**
  - [x] Define Core Export Models (`ExportRequest`, `ExportProfile`, `ExportPlan`) in `ExportCore`.
  - [x] Create `ExportCore` and `ExportUI` modules.
  - [x] Implement `UniversalExportView` with Input/Profile/Target selection.
  - [x] Implement `ProfileStudioView` with Intent/Layout/Pipeline editing.
  - [x] Integrate into `AnigmaAppMac` via `AppStore` and `MacShell`.
  - [x] Implement `ExportEngine` logic (stubbed in `ExportCore`).
  - [x] Implement `PreviewView` (stubbed in `ExportUI`).
  - [x] Implement `AgentLaneView` (stubbed in `ExportUI`).

## Release Candidate

The latest build is available in `release-candidate/`.

- **App Bundle**: `release-candidate/Anigma.app`
- **Installer**: `release-candidate/Anigma.pkg`

### Recent Updates
- **UI Polish**: Added close buttons to all pop-up panels (Job Center, Trust Boundary, Export, AI Console).
- **Wiring Fixes**: Connected Export Engine and AI Console Client to the central Job Engine for consistent tracking.
- **Governance**: Fixed duplicate sheet presentation in Governance Strip.
- **Build**: Verified clean build and packaging.

To install:
```bash
open release-candidate/Anigma.pkg
```

## Agentic Capabilities
- **AnigmaAgents Module**: Defines the `Agent` protocol and `AgentOrchestrator`.
- **Job-Backed Execution**: Agents run as governed jobs via `JobEngine`.
- **Data & Tool Access**: Agents access data and connectors through a governed `ToolBridge`.
- **ChangeSet Model**: Agents propose changes via `ChangeSet` artifacts, never direct mutation.


### Placeholder Implementation Status
- **DataEngine**: Implemented Ingestion (CSV), Profiling (Stats), and Transforms (Filter/Rename).
- **AnigmaAgents**: Implemented ToolBridge integration with DataEngine.
- **JobEngine**: Implemented file-based job queue.

## AI Console
- **AnigmaAIConsole Module**: A dedicated module for managing AI runtime components.
- **Unified Management**: Centralized control for Models, Providers, Tools, and Benchmarks.
- **Job-Backed Operations**: All actions (install, verify, benchmark) are governed jobs with receipts.
- **Dual Lens**: Accessible via "Platform > AI Console" in Build mode (Runtime view) and via "Brain" chip in Develop mode (Profile view).
- **Governance**: Enforces policy on external tools and remote providers.

## Export Tool
- **Unified Export Engine**: A single governed engine for all export tasks, replacing bespoke "Alt-Media" logic.
- **Profile-Based**: Exports are defined by profiles (e.g., "Binder", "Zip", "Accessible Package") rather than hardcoded features.
- **Manifest & Receipts**: Every export produces a `manifest.json` and a receipt, ensuring provenance and auditability.
- **Governance**: Export jobs are tracked in the global Job Center and respect data boundaries.
- **UI**: A consistent, professional export sheet available via `File > Export...` or `Cmd+E`.

## Placeholder Elimination & Final Polish
- **Status**: ✅ Complete
- **Actions**:
  - **AI Registry**: Implemented persistent `AIRegistry` in `AnigmaAgents` to replace in-memory mocks for AI models, providers, and tools.
  - **Real Job Integration**: Wired `AIConsoleClient` to the system `JobEngine`, ensuring all AI operations are tracked and governed.
  - **Agent Orchestration**: Updated `AgentOrchestrator` to use the registry for resolving agent configurations.
  - **Build Verification**: Verified full build of `AnigmaAppMac` with all new modules (`AnigmaAIConsole`, `AnigmaAgents`, `ExportCore`, `ExportUI`, `DataEngine`).
