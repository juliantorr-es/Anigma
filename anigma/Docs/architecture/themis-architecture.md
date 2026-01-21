# Themis Architecture

> **Named for the Greek Titan of divine law and order.**

The Themis architecture is Anigma's unified framework for governed institutional AI. It provides a single canonical entry point for all inference operations, wiring together governance, memory, routing, behavior control, transparency, and learning into a coherent system.

## Overview

Themis coordinates six architectural layers, each named after Greek mythology:

```
┌─────────────────────────────────────────────────────────────────┐
│                     ThemisOrchestrator                          │
│         (The unified entry point for all inference)            │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│    Themis     │    │   Mnemosyne   │    │    Moirae     │
│   (Charter)   │    │   (Memory)    │    │   (Routing)   │
│               │    │               │    │               │
│ • Validation  │    │ • Short-term  │    │ • Selection   │
│ • Guardrails  │    │ • Long-term   │    │ • Scheduling  │
│ • Prohibitions│    │ • Persistent  │    │ • Constraints │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│    Eunomia    │    │   Aletheia    │    │     Arete     │
│  (Behavior)   │    │(Transparency) │    │  (Learning)   │
│               │    │               │    │               │
│ • Governance  │    │ • Receipts    │    │ • Traces      │
│ • Violations  │    │ • Data flow   │    │ • Impact      │
│ • Budgets     │    │ • Audit       │    │ • UPFT        │
└───────────────┘    └───────────────┘    └───────────────┘
                              │
                              ▼
                    ┌───────────────┐
                    │     Eris      │
                    │  (Adversarial)│
                    │               │
                    │ • Attack tests│
                    │ • Scenarios   │
                    │ • Red-teaming │
                    └───────────────┘
```

## Layer Reference

### Themis (Divine Law)
**Purpose:** Institutional charter enforcement

The Themis layer validates every action against the tenant's institutional charter before execution. It enforces:

- **Allowed Domains:** Which areas the AI can operate in (DSPS, academic records, etc.)
- **Forbidden Domains:** Explicitly prohibited areas (medical documentation, legal advice)
- **Prohibited Optimizations:** Things the AI must never optimize for (reducing benefits, faster denials)
- **Ethical Guardrails:** Core ethical constraints (never discourage appeals, protect vulnerable populations)

```swift
// Charter validation
let charter = ThemisCharter(
    tenantId: "ccsf",
    allowedDomains: [.dspsAccommodations, .dspsForms],
    forbiddenDomains: [.medicalDocumentation],
    prohibitedOptimizations: [.reducedBenefits, .fasterDenials]
)

let result = charter.validate(action: CharterAction(
    domain: .dspsAccommodations,
    actionType: "recommend"
))
// result.isPermitted == true
```

### Mnemosyne (Memory)
**Purpose:** Tri-tier memory architecture

Named for the goddess of memory, this layer manages three distinct memory tiers:

| Tier | Name | Scope | Retention | Example |
|------|------|-------|-----------|---------|
| Short-term | Lethe Buffer | Session | Auto-expiring | Conversation history |
| Long-term | Mnemosyne Archive | Tenant | Governed | Case histories, policies |
| Persistent | Archeion Store | Release | Versioned | Control catalogs, rules |

```swift
// Short-term: auto-expires with session
let letheMemory = LetheBuffer(
    sessionId: "session-123",
    content: interactionData,
    ttlSeconds: 3600
)

// Long-term: requires governance approval
let archiveMemory = MnemosyneArchive(
    tenantId: "ccsf",
    content: policyDocument,
    legalHolds: ["litigation-2024"]  // Prevents deletion
)

// Persistent: requires release approval
let persistentMemory = ArcheionStore(
    version: "2.1.0",
    releaseId: "release-42"
)
```

### Moirae (Fate/Routing)
**Purpose:** Self-tuning model selection

Named for the three Fates, this layer decides which model handles each request:

- **Policy Learning:** Observes outcomes and adjusts feature weights
- **Hard Constraints:** Enforces requirements like local-only routing
- **Feature Weighting:** Prioritizes models with beneficial architecture features

```swift
let policy = MoiraeRoutingPolicy(
    tenantId: "ccsf",
    domain: .dsps,
    hardConstraints: [
        AnankeConstraint(type: .requireLocalOnly)  // DSPS data never leaves local
    ],
    featureWeights: [
        .kvCompression: 0.3,
        .longContextFriendly: 0.4
    ]
)
```

### Eunomia (Good Order)
**Purpose:** Agent behavior governance

Named for the goddess of lawful conduct, this layer watches agent behavior and enforces constraints:

| Failure Mode | Description | Detection |
|--------------|-------------|-----------|
| Analysis Paralysis | Too much thinking, no action | Token limit without tool calls |
| Rogue Actions | Action spam without verification | Consecutive tool calls without waiting |
| Premature Disengagement | Giving up too early | Termination without checking evidence |
| Ungrounded Confidence | High confidence without verification | Claims without tool verification |
| Repetitive Reasoning | Stuck in loops | Similar token patterns |
| Unchecked High-Impact | Dangerous actions not verified | High-risk ops without step-up |

```swift
let governor = EunomiaGovernor()
await governor.setConstraints(
    EunomiaConstraints(
        maxReasoningWithoutAction: 200,
        maxConsecutiveToolCalls: 3,
        maxUnverifiedConfidence: 0.5
    ),
    for: "ccsf"
)
```

### Aletheia (Truth)
**Purpose:** Transparency and provenance

Named for the personification of truth, this layer ensures complete transparency:

- **Processing Receipts:** Every inference produces a human-readable receipt
- **Data Flow Graphs:** Visual representation of how data moved through the system
- **Audit Trail:** Complete provenance for every decision

```swift
// Every task produces a receipt
let receipt = result.receipt
print(ReceiptRenderer.renderText(receipt))

// And a data flow graph
let graph = result.dataFlow
print(DataFlowRenderer.renderMermaid(graph))
```

### Arete (Excellence)
**Purpose:** Learning impact measurement

Named for the concept of excellence, this layer ensures only high-quality traces improve institutional models:

- **Quality Scoring:** Assesses trace structure, clarity, and domain fit
- **Impact Measurement:** Tracks actual improvement on held-out tasks
- **UPFT Extraction:** Extracts reasoning prefixes for unsupervised fine-tuning
- **Consent Management:** Respects user choices about learning

```swift
let measurer = AreteImpactMeasurer()
let trace = await measurer.record(reasoningTrace)
let impact = await measurer.scoreImpact(traceId: trace.id, benchmarkResults: results)

// Only high-impact traces become training data
let curatedSet = await measurer.selectHighImpactTraces(domain: .dsps, count: 100)
```

### Eris (Strife/Adversarial)
**Purpose:** Adversarial testing

Named for the goddess of discord, this layer constantly attacks the system to find weaknesses:

- **Charter Bypass Attempts:** Tests if charter can be circumvented
- **Memory Isolation Probes:** Tests cross-tenant memory access
- **Behavior Violation Scenarios:** Tests if governance can be fooled
- **Routing Abuse Tests:** Tests if routing can be manipulated

```swift
let report = await orchestrator.runAdversarialAnalysis()
// report.issues contains any discovered vulnerabilities
// report.overallHealth indicates system integrity
```

## Usage

### Basic Usage

```swift
// Create orchestrator with preset
let themis = await ThemisOrchestrator.create(preset: .ccsfDSPS)

// Start session
let session = themis.startSession(
    tenantId: "ccsf",
    principalId: "staff-123",
    domain: .dsps
)

// Run task
let task = InferenceTask(
    kind: .summarize,
    input: .text("Student accommodation request..."),
    context: InferenceContext(tenantId: "ccsf", ...)
)

let result = try await themis.runTask(task, session: session)

// Get transparency report
print(result.renderReport())

// End session
await themis.endSession(session.sessionId)
```

### Available Presets

| Preset | Description | Key Features |
|--------|-------------|--------------|
| `.ccsfDSPS` | CCSF DSPS operations | Local-only, strict ethics, learning enabled |
| `.academicRecords` | Transcript operations | Local-only, no learning, strict audit |

## Type Aliases

For code clarity, Greek-named type aliases are provided:

```swift
// Charter Layer
public typealias ThemisCharter = InstitutionalCharter
public typealias NemesisConstraint = ProhibitedOptimization
public typealias EunomiaGuardrails = EthicalGuardrails

// Memory Layer
public typealias MnemosyneArchitecture = TriMemoryArchitecture
public typealias LetheBuffer = ShortTermMemory
public typealias MnemosyneArchive = LongTermMemory
public typealias ArcheionStore = PersistentMemory

// Routing Layer
public typealias MoiraeRoutingPolicy = ArchitectureSelectionPolicy
public typealias MoiraRoutingRule = TaskRoutingRule
public typealias AnankeConstraint = RoutingConstraint

// Behavior Layer
public typealias EunomiaGovernor = AgentBehaviorGovernor
public typealias EunomiaConstraints = AgentBehaviorConstraints

// Transparency Layer
public typealias AletheiaManifest = EnhancedTelemetryManifest
public typealias AletheiaReceipt = ProcessingReceipt

// Learning Layer
public typealias AreteImpactMeasurer = LearningImpactMeasurer

// Testing Layer
public typealias ErisTrialBuilder = InferencePlanePuzzleBuilder
public typealias AgonScenario = AdversarialScenario
```

## Migration from Bonkers++ Names

The previous "bonkers++" naming has been deprecated. Migration aliases are provided:

```swift
@available(*, deprecated, renamed: "ThemisOrchestrator")
public typealias BonkersInferenceInfrastructure = ThemisOrchestrator

@available(*, deprecated, renamed: "ThemisResult")
public typealias BonkersInferenceResult = ThemisResult

@available(*, deprecated, renamed: "ThemisConfig")
public typealias BonkersInferenceConfig = ThemisConfig
```

## The Complete Pipeline

Every inference through Themis follows this exact sequence:

1. **Charter Pre-Validation** (Themis) - Is this action permitted?
2. **Behavior Turn Start** (Eunomia) - Begin monitoring agent behavior
3. **Memory Context Building** (Mnemosyne) - Assemble relevant context
4. **Model Selection** (Moirae) - Choose the best model via learned policy
5. **Transparency Tracking Start** (Aletheia) - Begin recording data flow
6. **Governed Inference Execution** - Run with behavior monitoring
7. **Behavior Turn End** (Eunomia) - Check for violations
8. **Transparency Artifacts** (Aletheia) - Generate receipt and data flow
9. **Learning Eligibility** (Arete) - Assess if trace can improve models
10. **Memory Update** (Mnemosyne) - Store interaction in short-term memory
11. **Learning Observation** (Moirae) - Record selection outcome for policy learning
12. **Result Bundling** - Package everything for the caller

## Design Philosophy

The Themis architecture embodies several key principles:

1. **Single Entry Point:** All inference goes through `ThemisOrchestrator.runTask()`
2. **Explicit Governance:** Every layer has clear, testable rules
3. **Radical Legibility:** Every action produces human-readable artifacts
4. **Institutional Memory:** The system learns from high-quality interactions
5. **Adversarial Hardening:** The system constantly attacks itself
6. **Mythological Clarity:** Names encode purpose and relationship

> "Themis governs, Mnemosyne remembers, Moirae routes, Eunomia enforces, Aletheia tells the truth, Arete tests it, Eris attacks it."
