# Bonkers++ Inference Infrastructure

## Overview

The Bonkers++ Inference Infrastructure is Anigma's "institution-grade" AI inference system. It goes far beyond simple model routing to provide:

- **Institutional Model Charters** - Machine-readable contracts that govern what AI can and cannot do
- **Tri-Memory Architecture** - Titans-inspired short-term/long-term/persistent memory separation
- **Self-Tuning Selection Policies** - Learned model routing that improves over time
- **Behavior Governance** - Prevention of analysis paralysis, rogue actions, and premature disengagement
- **Gremlin Integration** - Adversarial testing of every component

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BonkersInferenceInfrastructure                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────┐    ┌──────────────────┐    ┌────────────────┐ │
│  │  Institutional   │    │   Tri-Memory     │    │  Self-Tuning   │ │
│  │  Model Service   │    │    Service       │    │   Selection    │ │
│  │                  │    │                  │    │                │ │
│  │  • Charters      │    │  • Short-term    │    │  • Policies    │ │
│  │  • Bundles       │    │  • Long-term     │    │  • Learning    │ │
│  │  • Provenance    │    │  • Persistent    │    │  • Routing     │ │
│  └──────────────────┘    └──────────────────┘    └────────────────┘ │
│                                                                      │
│  ┌──────────────────┐    ┌──────────────────┐    ┌────────────────┐ │
│  │    Behavior      │    │    Learning      │    │     UPFT       │ │
│  │    Governor      │    │    Impact        │    │   Extractor    │ │
│  │                  │    │   Measurer       │    │                │ │
│  │  • Paralysis     │    │  • Traces        │    │  • Prefixes    │ │
│  │  • Rogue Actions │    │  • Impact        │    │  • Consensus   │ │
│  │  • Disengagement │    │  • Curation      │    │  • Anonymize   │ │
│  └──────────────────┘    └──────────────────┘    └────────────────┘ │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Architecture Registry                      │   │
│  │  GQA | MLA | Differential | Diffusion | Standard | MoE        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Institutional Model Charters

Every tenant gets a machine-readable charter that defines:

```swift
InstitutionalCharter(
    tenantId: "ccsf",
    name: "CCSF DSPS Institutional Charter",
    
    // Domains this model can touch
    allowedDomains: [.dspsForms, .dspsAccommodations, .dspsAltMedia],
    
    // Domains explicitly forbidden
    forbiddenDomains: [.medicalDocumentation, .legalAdvice],
    
    // Authoritative sources (ADA, Section 504, etc.)
    authoritativeSources: [...],
    
    // Things the model must NEVER optimize for
    prohibitedOptimizations: [
        .reducedBenefits,
        .fewerAccommodations,
        .shorterAppeals,
        .fasterDenials
    ],
    
    // Required approvers for changes
    requiredApprovers: [.dspsLead, .accessibilityOfficer],
    
    // Ethical guardrails
    ethicalGuardrails: EthicalGuardrails(
        neverDiscourageAppeals: true,
        alwaysOfferAlternatives: true,
        protectVulnerablePopulations: true
    )
)
```

Both training and inference validate against this charter. Violations are refused and logged.

### 2. Tri-Memory Architecture

Based on Google's Titans research, memory is separated into three types:

| Memory Type | Scope | Lifetime | Governance |
|-------------|-------|----------|------------|
| **Short-term** | Session | Auto-expires | Minimal |
| **Long-term** | Tenant | Years | Legal holds, retention policies |
| **Persistent** | Global | Release-gated | Code review, approval |

```swift
// Short-term: conversation history, drafts, scratchpad
ShortTermMemory(
    sessionId: "session-123",
    contentType: .interactionHistory,
    ttlSeconds: 3600  // Auto-expires
)

// Long-term: policies, case histories, learned patterns
LongTermMemory(
    tenantId: "ccsf",
    contentType: .policyDocument,
    retentionPolicy: .years(7, reason: .ferpaCompliance),
    legalHolds: ["litigation-2024"]  // Blocks deletion
)

// Persistent: control catalogs, schemas, rules
PersistentMemory(
    contentType: .controlCatalog,
    version: "1.0.0",
    releaseId: "release-42"  // Only changed via releases
)
```

### 3. Self-Tuning Selection Policies

Model selection learns from experience:

```swift
ArchitectureSelectionPolicy(
    tenantId: "ccsf",
    domain: .dsps,
    
    // Learned weights (updated from observations)
    featureWeights: [
        .kvCompression: 0.3,        // Prefer MLA-style
        .longContextFriendly: 0.4,  // Need long context
        .quantizationStable: 0.2    // Must run on M-series
    ],
    
    // Task-specific routes
    taskRoutes: [
        TaskRoutingRule(
            taskPattern: TaskPattern(kinds: [.codeGeneration]),
            preferredModelFamily: "mercury",  // Diffusion for code
            bonus: 0.3
        )
    ],
    
    // Hard constraints (never overridden by learning)
    hardConstraints: [
        RoutingConstraint(
            name: "local-only",
            type: .requireLocalOnly,
            value: "true"  // DSPS data never leaves tenant
        )
    ]
)
```

The system records observations and updates weights:

```swift
// Record what happened
SelectionObservation(
    tenantId: "ccsf",
    domain: .dsps,
    taskKind: .chat,
    selectedModelId: "deepseek-v3",
    activeFeatures: [.kvCompression, .longContextFriendly],
    wasSuccessful: true,
    latencyMs: 450
)

// Periodically: update policy weights based on success patterns
await selectionPolicyService.triggerLearning()
```

### 4. Behavior Governance

Prevents three failure modes identified in LLM research:

**Analysis Paralysis** - Endless thinking without action:
```swift
// If agent generates 2000+ tokens without any tool call
BehaviorViolation(
    failure: .analysisParalysis,
    severity: .moderate,
    suggestedAction: .forceEnvironmentCheck
)
```

**Rogue Action Sequences** - Tool spam without checking results:
```swift
// If agent makes 5+ tool calls without waiting for results
BehaviorViolation(
    failure: .rogueActionSequence,
    severity: .severe,
    suggestedAction: .pauseAndReview
)
```

**Premature Disengagement** - Giving up instead of checking:
```swift
// If agent produces confident answer without any environment check
BehaviorViolation(
    failure: .ungroundedConfidence,
    severity: .warning,
    suggestedAction: .warn
)
```

### 5. Learning Impact Measurement

Based on "less is more" research showing 117 examples can beat 100k:

```swift
// Record reasoning traces
ReasoningTrace(
    domain: .dsps,
    taskType: "accommodation_check",
    input: "Student needs extended time",
    reasoning: "Checking eligibility...",
    output: "Approved",
    quality: TraceQuality(
        overallScore: 0.9,
        structureScore: 0.85,
        followsDomainPatterns: true
    )
)

// Score learning impact
let impact = await measurer.scoreImpact(
    traceId: trace.id,
    benchmarkResults: LearningBenchmarkResults(
        improvementOverBaseline: 0.15,
        noveltyScore: 0.7,
        diversityContribution: 0.5
    )
)

// Select only high-impact traces for training
let trainingSet = await measurer.selectHighImpactTraces(
    domain: .dsps,
    count: 117,  // "117 examples beat 100k"
    minImpact: 0.3
)
```

### 6. UPFT Prefix Extraction

Extracts "thinking patterns" from reasoning traces for unsupervised fine-tuning:

```swift
// Given multiple traces for similar tasks, extract common prefix
let prefix = await upftExtractor.extractConsensusPrefix(from: traces)

// Prefix contains anonymized reasoning structure:
// "Given: [PROBLEM_TYPE] with [CONSTRAINTS]
//  Constraints: 1) [C1] 2) [C2]
//  I will: 1) Check [X] 2) Verify [Y]"

// Train on prefixes only (no labels needed)
```

## Usage

### Basic Usage

```swift
// Create infrastructure
let infra = await HarmoniaModule.createBonkersInference()

// Start a session
let session = await infra.startSession(
    tenantId: "ccsf",
    principalId: "user-123",
    domain: .dsps
)

// Run inference (goes through full governance pipeline)
let result = try await infra.runInference(
    task: InferenceTask(
        kind: .chat,
        input: .text("Help student with accommodation request"),
        context: InferenceContext(tenantId: "ccsf"),
        constraints: InferenceConstraints(localOnly: true)
    ),
    session: session
)

// Result includes:
// - Content (the actual response)
// - Model used
// - Latency
// - Selection score (why this model was chosen)
// - Charter validation (proof it's allowed)
// - Behavior summary (any violations?)
// - Memory layers used
// - Provenance (for audit trail)

// End session (clears short-term memory)
await infra.endSession(session.sessionId)
```

### CCSF DSPS Factory

```swift
// Pre-configured for CCSF DSPS with appropriate charter
let infra = await HarmoniaModule.createCCSFDSPSInference()

// Charter already set:
// - Allowed: DSPS forms, accommodations, alt-media
// - Forbidden: Medical documentation, legal advice
// - Prohibited optimizations: Reduced benefits, fewer accommodations
// - Ethical: Never discourage appeals
```

### Adversarial Testing

```swift
// Run gremlins against the infrastructure
let report = await infra.runAdversarialAnalysis()

// Report includes:
// - Issues found
// - Components tested
// - Overall health

if !report.issues.isEmpty {
    // Handle issues
}
```

## Integration with Anigma

The Bonkers++ infrastructure integrates with:

- **Governance** - All inference goes through WriteGate and governance checks
- **Compliance** - Charter validation maps to NIST controls
- **Observatorium** - Metrics and telemetry for all inference
- **ReasoningKernel** - Gremlins test selection policies and charters
- **AuditLog** - Full provenance trail for every inference

## Why "Bonkers++"?

Because normal inference systems:
- Pick models based on vibes
- Don't track why they picked a model
- Let AI do whatever
- Hope learning doesn't go wrong
- Trust users won't abuse things

This system:
- Has machine-readable charters
- Tracks every decision with provenance
- Prevents three categories of failure modes
- Curates training data with impact measurement
- Tests itself with adversarial gremlins
- Separates memory into constitutional categories

It's "bonkers" in the sense that no sane person would build this for a side project. But for an institution handling disabled students' rights and academic records? It's exactly the right level of paranoia.
