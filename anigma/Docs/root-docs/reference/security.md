# Signal 4 Vulnerability Matrix

Status: dated risk snapshot. TD remains the source of truth for task status and execution order.

Last reviewed: 2026-04-10

Baseline: `COMPILATION_SURFACE_AUDIT.md`

## Purpose

This matrix ranks current and planned modules by their vulnerability to Signal 4 / SIGILL / illegal-instruction compilation failures caused by excessive exposed Swift compilation surface.

This is not proof that a module will trigger Signal 4. It is a triage model for where agents should first apply the surface-reduction rule when compiler instability appears.

## Scoring Model

| Tier | Meaning | Default Response |
| --- | --- | --- |
| V0 | Active bottleneck: meaningful fan-in and fan-out at the same time | Refactor before expanding; split contracts from implementation |
| V1 | Severe vulnerability: high fan-out aggregator or high fan-in foundation | Freeze public API or enforce composition-root boundary |
| V2 | Elevated vulnerability: high fan-in, high fan-out, or broad executable/runtime module | Add budgets and avoid new public surface |
| V3 | Watchlist: moderate fan-in/fan-out or capsule/feature cluster risk | Keep scoped; validate before broadening |
| V4 | Low current vulnerability | No special action beyond normal module discipline |

Heuristic used for this snapshot:

- `V0`: audit category is bottleneck.
- `V1`: fan-out >= 25, or fan-out >= 17 with fan-in >= 1, or fan-in >= 30.
- `V2`: fan-out >= 10, or fan-in >= 10, or fan-out >= 8 with fan-in >= 4.
- `V3`: fan-out >= 6 or fan-in >= 6.
- `V4`: all other current modules.

## Current Module Summary

| Tier | Count | Meaning |
| --- | ---: | --- |
| V0 | 1 | Immediate bottleneck |
| V1 | 12 | Severe surface risk |
| V2 | 14 | Elevated surface risk |
| V3 | 36 | Watchlist |
| V4 | 128 | Low current risk |

All current modules not listed in V0-V3 are V4 by this snapshot and remain covered by the full matrix in `COMPILATION_SURFACE_AUDIT.md`.

## V0 Current Modules

| Module | Fan-In | Fan-Out | Audit Category | Signal 4 Vulnerability | Primary Mitigation |
| --- | ---: | ---: | --- | --- | --- |
| HarmoniaV2Surface | 13 | 9 | Bottleneck | V0 | Split DTO/protocol contracts from LocalAppClient/database/governance/runtime implementation |

## V1 Current Modules

| Module | Fan-In | Fan-Out | Audit Category | Signal 4 Vulnerability | Primary Mitigation |
| --- | ---: | ---: | --- | --- | --- |
| AnigmaCore | 39 | 4 | Foundation | V1 | Freeze API; add review gate for public actor/ECS/job changes |
| AnigmaDaemonCore | 4 | 41 | Feature/Aggregator | V1 | Treat as composition root; move feature wiring behind contracts/adapters |
| AnigmaMCPModule | 2 | 18 | Feature/Aggregator | V1 | Keep protocol surface narrow; isolate server/tool implementations |
| AnigmaNativeShims | 66 | 1 | Foundation | V1 | Freeze C/C++ shim surface; avoid broad header exposure |
| AnigmaPrimitives | 70 | 3 | Foundation | V1 | Freeze base types; no feature-specific concepts |
| CapsuleCore | 42 | 2 | Foundation | V1 | Freeze capsule protocol/error surface; avoid implementation imports |
| ContextumModule | 6 | 17 | Feature/Aggregator | V1 | Split ingestion/search/memory contracts from implementation lanes |
| ContractsCore | 34 | 3 | Foundation | V1 | Keep contracts stable and domain-neutral; no implementation dependencies |
| HarmoniaCLI | 0 | 27 | Feature/Aggregator | V1 | Treat as executable composition root; move shared CLI contracts out |
| HarmoniaModule | 2 | 34 | Feature/Aggregator | V1 | Continue surface shrink; prevent legacy tree from becoming reusable API |
| RLMModule | 1 | 20 | Feature/Aggregator | V1 | Split runtime model contracts from heavy retrieval/memory implementations |
| TelemetryCore | 31 | 1 | Foundation | V1 | Freeze logging/metric contracts; avoid backend-specific APIs |

## V2 Current Modules

| Module | Fan-In | Fan-Out | Audit Category | Signal 4 Vulnerability | Primary Mitigation |
| --- | ---: | ---: | --- | --- | --- |
| AnigmaCLICore | 12 | 2 | Foundation | V2 | Freeze shared CLI contracts |
| AnigmaCLIExecutable | 0 | 22 | Feature/Aggregator | V2 | Keep executable-only; no reusable API |
| AnigmaCLILocalInference | 1 | 11 | Feature/Aggregator | V2 | Split model/runtime DTOs from backend wiring |
| AnigmaEvents | 10 | 1 | Standard | V2 | Keep event schemas stable and minimal |
| AnigmaHostMac | 1 | 10 | Standard | V2 | Keep app-host wiring as composition root |
| AnigmaSystemSpine | 10 | 0 | Standard | V2 | Freeze spine contracts |
| DataCore | 11 | 1 | Foundation | V2 | Keep data primitives small |
| DatabaseCore | 21 | 2 | Foundation | V2 | Freeze migration/actor contracts; avoid feature imports |
| DevelopumModule | 0 | 10 | Standard | V2 | Prevent feature implementation from becoming shared surface |
| HarmoniaV2CLI | 0 | 12 | Feature/Aggregator | V2 | Keep executable-only |
| LayoutEngineCapsule | 10 | 6 | Standard | V2 | Avoid broad native/layout API exposure |
| MLWorkerCommon | 6 | 8 | Standard | V2 | Split model specs/contracts from MLX/runtime implementation |
| MLWorkerExecutable | 0 | 10 | Standard | V2 | Keep executable-only |
| PDFExporterKit | 3 | 10 | Standard | V2 | Split export contracts from heavy document pipeline dependencies |

## V3 Current Modules

| Module | Fan-In | Fan-Out | Audit Category | Signal 4 Vulnerability | Primary Mitigation |
| --- | ---: | ---: | --- | --- | --- |
| ANEServicesCore | 6 | 0 | Standard | V3 | Freeze service contract |
| AnigmaAgents | 2 | 9 | Standard | V3 | Keep agent orchestration behind narrow protocols |
| AnigmaCLIDatabase | 4 | 6 | Standard | V3 | Keep DB CLI adapters out of core contracts |
| AnigmaCLIEventing | 6 | 1 | Standard | V3 | Freeze event CLI surface |
| AnigmaCLIML | 2 | 6 | Standard | V3 | Keep ML CLI backend-specific code isolated |
| AnigmaCLIOnboarding | 1 | 6 | Standard | V3 | Keep onboarding as feature surface |
| AnigmaCLIProviders | 8 | 3 | Standard | V3 | Stabilize provider contracts |
| AnigmaCLITUI | 1 | 7 | Standard | V3 | Keep TUI as executable/UI composition |
| AnigmaCoreRuntime | 6 | 2 | Standard | V3 | Avoid feature-specific runtime APIs |
| AnigmaCoreSecurityRuntime | 3 | 8 | Standard | V3 | Split security contracts from runtime implementation |
| AnigmaDaemon | 0 | 8 | Standard | V3 | Keep executable composition-only |
| AnigmaHostKit | 1 | 6 | Standard | V3 | Keep host wiring narrow |
| AnigmaSidecar | 9 | 3 | Standard | V3 | Stabilize sidecar client surface |
| AnigmaWork | 0 | 7 | Standard | V3 | Avoid becoming shared workflow framework |
| BenchmarkHarness | 7 | 3 | Standard | V3 | Keep benchmark API stable |
| BookAssemblerCapsule | 1 | 6 | Standard | V3 | Keep capsule implementation scoped |
| BookExportCapsule | 0 | 7 | Standard | V3 | Keep executable/feature scoped |
| ChunkNormalizerCapsule | 2 | 6 | Standard | V3 | Avoid broad document pipeline surface |
| CitationExtractionCapsule | 2 | 6 | Standard | V3 | Keep extraction contracts minimal |
| DiffCapsule | 1 | 6 | Standard | V3 | Keep capsule implementation scoped |
| DocumentRenderKit | 0 | 6 | Standard | V3 | Keep rendering implementation scoped |
| GoldenKit | 2 | 6 | Standard | V3 | Keep test/golden APIs narrow |
| GovernanceCore | 9 | 5 | Standard | V3 | Freeze governance policy contracts |
| HarmoniaV2CLIKernel | 1 | 9 | Standard | V3 | Keep CLI kernel out of shared surface |
| HarmoniaV2Core | 7 | 0 | Standard | V3 | Freeze core Harmonia contracts |
| InferenceCore | 6 | 1 | Standard | V3 | Keep inference contracts backend-neutral |
| MathOCRCapsule | 1 | 6 | Standard | V3 | Keep capsule implementation scoped |
| MediaFingerprintCapsule | 3 | 7 | Standard | V3 | Split fingerprint DTOs from implementation if fan-in grows |
| PolytroposModule | 2 | 6 | Standard | V3 | Keep media workflow implementation scoped |
| ReferenceResolutionCapsule | 1 | 7 | Standard | V3 | Keep reference resolution implementation scoped |
| RenderBackendCapsule | 0 | 8 | Standard | V3 | Keep backend renderer implementation scoped |
| TableExtractionCapsule | 1 | 6 | Standard | V3 | Keep extraction implementation scoped |
| TextChunkingCapsule | 9 | 5 | Standard | V3 | Stabilize chunking API; avoid pipeline coupling |
| TextPipelineCapsule | 2 | 7 | Standard | V3 | Avoid becoming document-processing aggregator |
| VectorOpsKit | 2 | 6 | Standard | V3 | Keep vector operations contracts narrow |
| anigma-capsule-bench | 0 | 6 | Standard | V3 | Keep benchmark executable-only |

## Future Planned Module Matrix

Future modules should be assigned a planned tier before they are added to `Package.swift`. The target is the desired maximum risk tier, not a prediction of current fan-in/fan-out.

| Planned Module / Track | Planned Role | Target Tier | Why | Boundary Rule |
| --- | --- | --- | --- | --- |
| HarmoniaV2Contracts | DTO/protocol contracts for Harmonia app/client surface | V2 initially, then V1 if widely adopted | High fan-in is acceptable only if fan-out stays near zero | No database, governance runtime, inference, memory, or orchestration imports |
| HarmoniaV2LocalClient | Local implementation of Harmonia app client | V3 | Can depend on DB/governance/runtime but should have low fan-in | Only composition roots import it |
| DaemonKernel / DaemonContracts | Daemon request/job/operator contracts | V2 initially | Likely high fan-in once adopted | Contracts only; no feature module imports |
| DaemonFeatureWiring targets | Per-feature daemon registration modules | V3 | Broad fan-out is acceptable if fan-in stays low | Composition-only; never imported by domain modules |
| MemoryContracts | Personal/business memory DTOs and protocols | V2 | May become widely imported | No Contextum/RLM/database implementation imports |
| MemoryRuntime / MemoryImplementation | Memory consolidation, recall, compaction implementation | V3 | Heavy implementation surface | Imported by composition roots only |
| BusinessCore / BusinessContracts | Shared small-business entities and evidence contracts | V2 | Likely reused by CRM, sales, invoices, accounting, reporting | Keep domain-neutral; avoid connector/database implementations |
| CRMModule / Conexus expansion | Contact/customer/relationship memory | V3 | Feature module with moderate dependencies | Depend on BusinessContracts, not accounting/invoice implementations |
| SalesModule | Quotes, opportunities, sales-stage workflows | V3 | Feature module with business dependencies | Use contracts for customers/invoices; avoid direct CRM implementation imports |
| InvoicingModule | Invoice drafting/status/follow-up | V3 | Feature module with finance/document dependencies | Keep accounting integration through contracts/events |
| AccountingModule | Classification, ledger/audit packets | V3/V2 if shared contracts split | Finance logic can become central quickly | Split AccountingContracts from implementation before broad adoption |
| BankReconciliationModule | Transaction matching and approval queue | V3 | Heavy matching logic and database use | Import AccountingContracts, not AccountingModule implementation |
| InventoryAssetsModule | Optional inventory/asset records | V4/V3 | Optional by business type | Keep isolated; no foundation dependency expansion |
| ProjectsJobsModule | Commitments, blockers, customer-facing work state | V3 | Integrates CRM/invoicing/documents | Use BusinessContracts and events; avoid direct cross-feature imports |
| ReportingModule | Owner briefs and business reports | V3 | Aggregates many domains | Composition/query layer only; no reusable contracts here |
| Connector modules: QuickBooks/Xero/Stripe/Square/Bank feeds | External adapters | V3/V4 | Adapter complexity, low desired fan-in | Depend on connector contracts and BusinessContracts only |
| ObservabilityOperatorSurface | Health/metrics/debug DTOs and APIs | V2 | May become widely imported by app/CLI/daemon | Split operator contracts from collection implementations |
| EvalHarness / BusinessEvalFixtures | Evaluation fixtures for assistant/business workflows | V3 | Test harness fan-out can grow | Keep out of production targets |

## Operational Rules

1. Address V0 first. `HarmoniaV2Surface` is the first concrete refactor target and should be split before broadening any dependent feature work.
2. Address V1 modules immediately after V0 through two lanes: foundation freeze/governance and aggregator/composition-root shrink.
3. Treat `DatabaseCore` with the foundation lane even though it scores V2, because persistence churn is operationally severe.
4. Any V0/V1 module that triggers Signal 4 must stop feature work and reduce exposed compilation surface first.
5. Any new planned module expected to be imported by more than five targets needs a contracts/implementation split before broad adoption.
6. Aggregators are allowed high fan-out only when they have low fan-in and are composition roots.
7. Foundation modules are allowed high fan-in only when fan-out remains low and public API changes are reviewed.
8. A module that has both high fan-in and high fan-out should be treated as a future V0 even before Signal 4 appears.

## Execution Order

1. `td-f846b9`: split `HarmoniaV2Surface` contracts from implementation.
2. `td-34082e`: freeze/govern severe foundation surfaces: `AnigmaPrimitives`, `AnigmaNativeShims`, `CapsuleCore`, `AnigmaCore`, `ContractsCore`, `TelemetryCore`, and operationally severe `DatabaseCore`.
3. `td-93f670`: shrink/budget severe aggregators: `AnigmaDaemonCore`, `HarmoniaModule`, `HarmoniaCLI`, `RLMModule`, `AnigmaMCPModule`, and `ContextumModule`.
4. `td-8ff6b8` and `td-7ce728`: keep the audit and matrix repeatable so the risk model stays current.

## TD Links

- Epic: `td-f9576a` Compilation surface reduction and module boundary hardening
- Signal 4 rule: `td-cf4ee8`
- HarmoniaV2Surface split: `td-f846b9`
- Foundation API governance: `td-34082e`
- Aggregator fan-out budgets: `td-93f670`
- Matrix automation: `td-8ff6b8`
