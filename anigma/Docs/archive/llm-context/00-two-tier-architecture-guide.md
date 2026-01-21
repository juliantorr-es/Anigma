# Anigma Two-Tier Architecture: Agent Operating Guide

This document provides comprehensive guidance for AI agents working with Anigma's new two-tier architecture: **Core Governance Layer** + **Capability Modules**.

## Executive Summary

Anigma follows a **layered governance model** with strict separation between:

1. **Core Governance Layer** - Production-hardened, court-safe substrate with minimal dependencies
2. **Capability Modules** - Feature-rich ecosystem modules that plug into Core via contracts

This architecture ensures security, auditability, and extensibility while maintaining clear boundaries that agents must respect.

---

## 1. Core Governance Layer: The Immutable Foundation

### 1.1 What Belongs in Core

**Core Governance Layer contains ONLY:**
- `AnigmaCore`: ECS primitives (`World`, `EntityId`, `Component`, `System`)
- `DatabaseCore`: Secure SQLite access with `DatabaseActor`
- `HarmoniaSpine`: Governance state, trust boundaries, security events
- Production-grade court-safe ML worker integration
- Hardware-backed signing and timestamping infrastructure
- Emergency security procedures (key revocation, evidence bundles)

### 1.2 Core Layer Rules (NON-NEGOTIABLE)

#### Harmonia is the ONLY Governance Surface
```bash
# ✅ CORRECT: Use the deterministic wrapper
Anigma/Scripts/harmonia.sh <subcommand> [args...]

# ❌ FORBIDDEN: Never run these directly
swift build
swift test  
swift run
xcodebuild
./.build/.../harmonia
.tools/bin/harmonia
```

#### Automation Interface Requirements
- **Output**: Single JSON envelope on stdout only
- **Diagnostics**: All diagnostic messages on stderr
- **Format**: Always `--format json` unless `HARMONIA_FORMAT=text` is set
- **State**: All governance state queries go through Harmonia

#### Court-Safe ML Integration Requirements
- **Hardware-backed signing**: All evidence heads signed with Secure Enclave/TPM
- **Trusted timestamping**: External RFC3161 TSA verification
- **Canonical serialization**: Cross-platform deterministic byte signing
- **Offline verification**: Evidence bundles verifiable without trusting infrastructure
- **Accessum integration**: All ML operations follow runId/ml/stepId/ structure

### 1.3 Evidence Generation and Verification

**"Why Did You Say That?" Receipt Generation**:
```bash
# Generate legal-grade receipt for any query
anigma-receipt explain --agent-id "agent-123" --legal-grade --format pdf

# Create court-ready evidence bundle
anigma-receipt bundle --type legal_discovery --sign --timestamp

# Air-gapped verification by hostile auditors
anigma-verify ./evidence-bundle-20241213/ \
    --strict \
    --trust-anchors ./auditor-certs/ \
    --revocation-list ./revoked-keys.txt \
    --format html \
    --output verification-report.html
```

### 1.4 Core Integration Patterns

When working with Core Layer:

```swift
// ✅ CORRECT: Use AnigmaCore ECS primitives
import AnigmaCore

let world = World()
let entityId = await world.createEntity()
await world.addComponent(entityId, FileComponent(path: "/path/to/file"))

// ✅ CORRECT: Use DatabaseCore for data access
import DatabaseCore

let database = DatabaseActor(path: "/path/to/database.sqlite")
let results = await database.query("SELECT * FROM documents WHERE processed = ?", [false])

// ❌ FORBIDDEN: Direct SQLite C API usage
// ❌ FORBIDDEN: Custom ECS implementations
// ❌ FORBIDDEN: Bypassing Harmonia for governance state
```

---

## 2. Capability Modules: Feature-Rich Ecosystem

### 2.1 What Belongs in Capability Modules

**Capability Modules contain domain-specific functionality:**
- `HarmoniaModule`: Governed inference, reasoning safety (Bonkers++), CI/CD gates
- `DiaplasionModule`: Alt-media transformation (OCR, chunking, EPUB/Braille/audio)
- `AccessumModule`: Apertum Accessum client pipelines (import → OCR → TTS → sync)
- `OutlineumModule`: Outline/zine creation with CoreImage processing
- `PragmaModule`: Work management (tasks/projects, workflows, permissions)
- `ConexusModule`: CRM (contacts, orgs, pipelines, cases, relationships)
- `CodexModule`: Knowledge management (spaces, pages, templates, versions)
- `TranscriptumModule`: Academic records (programs, courses, enrollments, grades)
- `ObservatoriumModule`: Observability (metrics, alerts, error aggregation)
- `PolytroposModule`: Live-event video processing

### 2.2 Architectural Reuse Requirements

**MANDATORY: Search Before Create**

Before adding any new module, type, or subsystem:

1. **Search existing abstractions**:
   ```bash
   # Find similar components/systems
   rg -t swift "Component|System" Sources/*/Components/
   rg -t swift "struct.*:.*Component" Sources/
   rg -t swift "class.*:.*System" Sources/
   ```

2. **Prefer existing patterns**:
   - **ECS logic**: Use `Component`, `System`, `World`, `Scheduler` from `AnigmaCore`
   - **Memory**: Use `TriMemory`, `HarmoniaMemory`, SQLite stores
   - **Tools**: Extend `ToolDescriptor`, `ToolRegistry`, `FileToolRuntime`, `GitToolRuntime`, `ShellToolRuntime`, `ToolOrchestrator`
   - **CLI**: Extend existing Harmonia CLI commands

3. **Document decisions**: If you must create something new, document which existing options were evaluated and rejected in PR/commit message.

### 2.3 Core Abstraction Map

| Domain | Use This | Don't Create |
|--------|----------|--------------|
| ECS | `World`, `EntityId`, `Component`, `System` | Custom ECS frameworks |
| Memory | `TriMemoryArchitecture`, `HarmoniaMemory`, SQLite stores | New persistence layers |
| Tools | `ToolDescriptor`, `ToolRegistry`, `*ToolRuntime`, `ToolOrchestrator` | Parallel runtimes/registries |
| Governance | Themis/policy engine/CI gates | Bypass mechanisms |

### 2.4 Module Development Patterns

#### Component Development
```swift
// ✅ CORRECT: Domain component in module
// In DiaplasionModule/Components/
import AnigmaCore

public struct OcrComponent: Component, Codable {
    public let confidence: Double
    public let text: String
    public let boundingBox: CGRect
    
    public init(confidence: Double, text: String, boundingBox: CGRect) {
        self.confidence = confidence
        self.text = text
        self.boundingBox = boundingBox
    }
}
```

#### System Development
```swift
// ✅ CORRECT: Domain system in module
// In DiaplasionModule/Systems/
import AnigmaCore

public struct OcrProcessingSystem: System {
    public var name: String { "OcrProcessing" }
    
    public init() {}
    
    public func update(world: World) async {
        // Query entities with required components
        let documents = await world.query(FileComponent.self, OcrRequestComponent.self)
        
        for (entity, fileComponent, ocrRequest) in documents {
            // Process OCR
            await processOcr(for: entity, file: fileComponent, request: ocrRequest, world: world)
        }
    }
}
```

#### Workflow Development
```swift
// ✅ CORRECT: Job type and workflow
public struct OcrJobType: JobType {
    public static let identifier = "diaplasion.ocr"
    public static let displayName = "OCR Processing"
}

public struct OcrWorkflow: Workflow {
    public var name: String { "OCR Processing" }
    public var jobTypeId: String { OcrJobType.identifier }
    public var systemNames: [String] { ["FileLoad", "OCR", "QACheck", "Persist"] }
    
    public init() {}
}
```

---

## 3. Agent Workflows: Proper Operating Procedures

### 3.1 Multi-Agent Pipeline Order

All multi-agent flows MUST follow this sequence:

1. **Architect**: Plan and produce structured stub specs; no file writes
2. **Builder**: Implement stubs using existing abstractions and tools; run tests
3. **Validator**: Compare implementation vs. spec; check risks and tests
4. **Scribe**: Update `AGENTS.md`, docs, and `Docs/TechDebt.md` to reflect changes
5. **Tech-Debt Scout**: Periodically scan for duplication, drift, consolidation work

### 3.2 Agent Decision Tree

```
┌─────────────────┐
│  Start Task     │
└─────────┬───────┘
          │
    ┌─────▼─────┐
    │Is this    │
    │Core Layer?│
    └─────┬─────┘
          │ Yes         No
    ┌─────▼─────┐ ┌─────▼─────┐
    │Use ONLY   │ │Search     │
    │Harmonia   │ │Existing   │
    │wrapper    │ │Abstractions│
    └─────┬─────┘ └─────┬─────┘
          │              │
    ┌─────▼─────┐ ┌─────▼─────┐
    │Generate   │ │Reuse/Extend│
    │Evidence   │ │Existing    │
    │if needed  │ │Patterns    │
    └─────┬─────┘ └─────┬─────┘
          │              │
          └─────┬────────┘
                │
        ┌───────▼───────┐
        │Document       │
        │Decision       │
        └───────┬───────┘
                │
        ┌───────▼───────┐
        │Update         │
        │TechDebt.md    │
        └───────────────┘
```

### 3.3 Examples of Proper Agent Behavior

#### Example 1: Adding New OCR Feature
```bash
# 1. Architect: Search existing patterns
rg -t swift "OCR|ocr" Sources/DiaplasionModule/
rg -t swift "Component.*:.*Component" Sources/DiaplasionModule/Components/

# 2. Builder: Implement using existing abstractions
# Create OcrResultComponent in DiaplasionModule/Components/
# Create OcrProcessingSystem in DiaplasionModule/Systems/
# Register with existing workflow patterns

# 3. Validator: Test implementation
swift test --filter DiaplasionModuleTests

# 4. Scribe: Update documentation
echo "- Added OcrResultComponent for structured OCR results" >> Docs/TechDebt.md

# 5. Tech-Debt Scout: Check for duplication
rg -r "OcrResult|OCRResult" Sources/
```

#### Example 2: Querying Governance State
```bash
# ✅ CORRECT: Use Harmonia wrapper
Anigma/Scripts/harmonia.sh trust bounds
Anigma/Scripts/harmonia.sh security status

# ❌ FORBIDDEN: Direct database access
# sqlite3 harmonia_harness.sqlite "SELECT * FROM trust_boundaries"
```

---

## 4. Security and Governance Requirements

### 4.1 Core Layer Security Boundaries

**Hardware-Backed Security**:
- All evidence heads signed with Secure Enclave/TPM keys
- Private keys hardware-protected with rotation/revocation
- Cryptographic provenance with SHA256 verification
- Process isolation with resource limits and sandboxing

**Emergency Procedures**:
```bash
# Emergency key revocation
anigma-key revoke --fingerprint "compromised-key-hash" \
    --reason "security_incident" \
    --authorized-by "security_admin" \
    --incident-id "INC-2024-001"

# Generate verification bundle for compromised period
anigma-verify --create-bundle \
    --start-date "2024-12-01" \
    --end-date "2024-12-13" \
    --include-revoked-keys
```

### 4.2 Capability Module Security

**Data Governance**:
- All PII processing must use Harmonia governance hooks
- Content sanitization with privilege logging
- Access control through existing RBAC/ABAC patterns
- Audit trails for all data transformations

**ML Operations**:
- Use existing Accessum integration for all ML operations
- Follow runId/ml/stepId/ structure automatically
- Test with `ML_WORKER_MOCK_MODE=true` for development
- Document backend configuration (models, binaries)

---

## 5. Build, Test, and Deployment Guidelines

### 5.1 Core Layer Build Rules

```bash
# ✅ CORRECT: Use Harmonia wrapper for all operations
Anigma/Scripts/harmonia.sh build
Anigma/Scripts/harmonia.sh test
Anigma/Scripts/harmonia.sh serve

# ❌ FORBIDDEN: Direct Swift commands
swift build
swift test
swift run
```

### 5.2 Capability Module Development

**Required Commands**:
```bash
# Build and test modules
swift build
swift test --filter ModuleNameTests

# Verify integration
Anigma/Scripts/harmonia.sh trust bounds
Anigma/Scripts/harmonia.sh security status

# Lint and format
swift format .
swiftlint lint
```

**Documentation Requirements**:
- Add doc comments to all public APIs
- Note ported code with `// Ported from: X.py`
- Add `#warning("STUB: ...")` and `// STUB_TRACK:` comments
- Update `Docs/TechDebt.md` for all stubs

### 5.3 Testing Strategy

**Core Layer Testing**:
- Focus on security boundaries and cryptographic operations
- Test evidence generation and verification
- Validate hardware key operations (mocked in CI)
- Test Harmonia wrapper determinism

**Capability Module Testing**:
- Test components in isolation
- Test systems with mock World state
- Test workflows with fixture data
- Integration tests with Core Layer contracts

---

## 6. Common Pitfalls and How to Avoid Them

### 6.1 Core Layer Violations

**❌ Common Mistakes**:
- Running `swift build` directly instead of using Harmonia wrapper
- Creating custom ECS implementations
- Bypassing governance for "performance"
- Direct database access instead of using DatabaseCore

**✅ Correct Approaches**:
- Always use `Anigma/Scripts/harmonia.sh` for Core operations
- Extend existing AnigmaCore abstractions
- Work within governance boundaries
- Use DatabaseCore for all data access

### 6.2 Capability Module Violations

**❌ Common Mistakes**:
- Creating new persistence layers instead of using existing stores
- Implementing custom tool runtimes instead of extending existing ones
- Adding new modules without searching existing abstractions
- Creating circular dependencies between modules

**✅ Correct Approaches**:
- Use TriMemory/HarmoniaMemory/SQLite stores
- Extend ToolDescriptor/ToolRegistry patterns
- Search before creating new abstractions
- Maintain clean module boundaries

### 6.3 Agent Workflow Violations

**❌ Common Mistakes**:
- Implementing without searching existing patterns
- Skipping documentation updates
- Not testing integration with Core Layer
- Ignoring TechDebt tracking

**✅ Correct Approaches**:
- Always search before creating
- Update documentation as part of workflow
- Test Core Layer integration
- Track all technical debt

---

## 7. Quick Reference Matrix

| Task | Core Layer | Capability Module | Agent Action |
|------|------------|-------------------|--------------|
| Query governance state | `Anigma/Scripts/harmonia.sh` | N/A | Use wrapper only |
| Add domain component | N/A | Extend existing patterns | Search → Create → Test |
| Implement workflow | N/A | Use Job/Workflow model | Follow existing patterns |
| Process ML request | Use Accessum integration | Use existing ML patterns | Document backend |
| Handle security incident | Use emergency procedures | Report through Harmonia | Follow security protocol |
| Add new module | Requires ADR | Search existing first | Document decisions |

---

## 8. Decision Checklist for Agents

Before taking any action, ask yourself:

### Core Layer Questions
- [ ] Am I using the Harmonia wrapper?
- [ ] Is this a Core Layer responsibility?
- [ ] Do I need to generate evidence?
- [ ] Am I following security procedures?

### Capability Module Questions
- [ ] Have I searched existing abstractions?
- [ ] Can I extend rather than create new?
- [ ] Am I following ECS patterns?
- [ ] Will this create circular dependencies?

### Agent Workflow Questions
- [ ] Have I followed the Architect→Builder→Validator→Scribe→Scout sequence?
- [ ] Have I updated documentation?
- [ ] Have I run tests?
- [ ] Have I updated TechDebt.md?

---

## 9. Emergency Contact and Escalation

**Security Incidents**: Follow emergency procedures immediately
**Architecture Questions**: Reference ADRs and existing patterns
**Build Issues**: Use Harmonia wrapper, not direct Swift commands
**Module Conflicts**: Search existing abstractions before creating new

Remember: The two-tier architecture exists to maintain security while enabling extensibility. Respect the boundaries, reuse existing patterns, and always document your decisions.