# Capability Modules: Feature-Rich Ecosystem

Capability Modules provide domain-specific functionality that plugs into the Core Governance Layer through well-defined contracts, enabling rich features without compromising security posture.

## Overview

Capability Modules are the **feature-rich ecosystem** of Anigma that contains domain-specific functionality. They must reuse existing Core abstractions and follow strict architectural patterns to maintain consistency and security.

## Module Directory

### HarmoniaModule: Governed Inference
- **Purpose**: Dev-intelligence, governed inference, reasoning safety
- **Features**: Themis orchestrator, Bonkers++ reasoning safety, CI/CD gates
- **Artifacts**: Transparency bundles, behavior governance, institutional learning
- **Integration**: Core governance hooks, evidence generation

### DiaplasionModule: Alt-Media Transformation
- **Purpose**: OCR, chunking, EPUB/Braille/audio preparation
- **Features**: Vision OCR integration, text normalization, accessible output formats
- **Workflows**: Document processing pipelines with quality assurance
- **Outputs**: Searchable PDFs, structured text, accessibility metadata

### AccessumModule: Client Workflows
- **Purpose**: Apertum Accessum client slice with end-to-end workflows
- **Features**: Import → OCR → TTS → sync pipelines
- **Integration**: Telemetry hooks, governance boundaries, client state management
- **Automation**: Deterministic runs with provenance tracking

### OutlineumModule: Creative Production
- **Purpose**: Outline and zine generation with visual processing
- **Features**: CoreImage integration, layout engines, export systems
- **Workflows**: Content creation, quality assurance, multi-format output
- **Assets**: Template management, version control, collaborative editing

### PragmaModule: Work Management
- **Purpose**: Tasks, projects, workflows, and automation
- **Features**: Jira/Asana replacement with governance hooks
- **Workflows**: Task lifecycle, project management, permission systems
- **Integration**: Cross-module dependencies, resource allocation

### ConexusModule: CRM Operations
- **Purpose**: Contacts, organizations, relationships, and pipelines
- **Features**: Relationship graphs, pipeline management, case tracking
- **Data Models**: Entity relationships, interaction history, analytics
- **Integration**: Communication workflows, document linking

### CodexModule: Knowledge Management
- **Purpose**: Spaces, pages, templates, versions, and comments
- **Features**: Institutional documentation with version control
- **Workflows**: Content creation, review cycles, publication
- **Search**: Semantic search, content indexing, knowledge graphs

### TranscriptumModule: Academic Records
- **Purpose**: Programs, courses, enrollments, grades, and transcripts
- **Features**: SIS overlay with system-of-record capabilities
- **Compliance**: Academic standards, privacy requirements, audit trails
- **Integration**: Learning management systems, student information systems

### ObservatoriumModule: Telemetry and Observability
- **Purpose**: Metrics, alerts, error aggregation, and feedback
- **Features**: Ops + SRE dashboards with real-time monitoring
- **Integration**: Cross-module telemetry, alert routing, incident response
- **Analytics**: Performance metrics, usage patterns, capacity planning

### PolytroposModule: Live Event Video
- **Purpose**: Video capture, processing, and clip generation
- **Features**: Native renderer with MLT/FFmpeg fallback
- **Workflows**: Event recording, real-time processing, highlight generation
- **Outputs**: Multiple format support, streaming capabilities

## Architectural Requirements

### Mandatory Reuse Patterns

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

### Core Abstraction Map

| Domain | Use This | Don't Create |
|--------|----------|--------------|
| ECS | `World`, `EntityId`, `Component`, `System` | Custom ECS frameworks |
| Memory | `TriMemoryArchitecture`, `HarmoniaMemory`, SQLite stores | New persistence layers |
| Tools | `ToolDescriptor`, `ToolRegistry`, `*ToolRuntime`, `ToolOrchestrator` | Parallel runtimes/registries |
| Governance | Themis/policy engine/CI gates | Bypass mechanisms |

## Development Patterns

### Component Development
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

### System Development
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

### Workflow Development
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

## Integration with Core Layer

### Governance Hooks
All modules must integrate with Core governance:

```swift
// ✅ CORRECT: Use governance hooks
import HarmoniaSpine

let governance = GovernanceController(auditLog: auditLog)

// Log all operations
await governance.logOperation(
    operation: "ocr.process",
    entityId: entityId,
    metadata: ["confidence": confidence, "textLength": text.count]
)

// Check permissions
let canProcess = await governance.checkPermission(
    action: "ocr.process",
    resource: fileComponent.path
)
```

### Evidence Generation
Modules must generate evidence for significant operations:

```swift
// ✅ CORRECT: Generate evidence
import AnigmaCore

let evidence = EvidenceBuilder()
    .setOperation("ocr.process")
    .setEntityId(entityId)
    .addArtifact("text", textHash)
    .addArtifact("metadata", metadataHash)
    .setTimestamp(Date())
    .sign(with: privateKey)

await evidence.store()
```

### Telemetry Integration
Modules must provide telemetry data:

```swift
// ✅ CORRECT: Emit telemetry
import ObservatoriumModule

let telemetry = TelemetryService()

await telemetry.emitMetric(
    name: "ocr.processing.duration",
    value: processingDuration,
    tags: ["module": "diaplasion", "confidence": confidence]
)

await telemetry.emitEvent(
    name: "ocr.completed",
    data: ["entityId": entityId, "confidence": confidence]
)
```

## Testing Requirements

### Unit Testing
- **Component tests**: Test component serialization/deserialization
- **System tests**: Test system logic with mock World state
- **Workflow tests**: Test workflow execution with fixture data

### Integration Testing
- **Core Layer contracts**: Test integration with AnigmaCore abstractions
- **Governance integration**: Test governance hooks and evidence generation
- **Cross-module tests**: Test interactions with other modules

### Performance Testing
- **Load testing**: Test performance under realistic workloads
- **Memory testing**: Test memory usage and cleanup
- **Concurrency testing**: Test thread safety and actor boundaries

## Documentation Requirements

### API Documentation
- **Public APIs**: Complete doc comments with examples
- **Component documentation**: Purpose, usage patterns, examples
- **Workflow documentation**: Input/output specifications, error handling

### Architecture Documentation
- **Module purpose**: Clear description of module responsibilities
- **Integration patterns**: How the module integrates with Core and other modules
- **Design decisions**: Rationale for architectural choices

### User Documentation
- **Getting started**: Setup and basic usage examples
- **Advanced usage**: Complex scenarios and best practices
- **Troubleshooting**: Common issues and solutions

## Module Lifecycle

### Development Phase
1. **Architecture phase**: Design module using existing patterns
2. **Implementation phase**: Code following architectural requirements
3. **Testing phase**: Comprehensive testing including integration tests
4. **Documentation phase**: Complete API and user documentation

### Release Phase
1. **Code review**: Ensure compliance with architectural patterns
2. **Integration testing**: Test with full Anigma stack
3. **Performance validation**: Ensure performance requirements are met
4. **Security review**: Validate security and governance integration

### Maintenance Phase
1. **Bug fixes**: Address issues while maintaining architectural compliance
2. **Feature updates**: Add features following established patterns
3. **Performance optimization**: Improve performance without breaking contracts
4. **Security updates**: Address security vulnerabilities promptly

Capability Modules enable Anigma to provide rich functionality while maintaining the security and auditability guarantees of the Core Governance Layer. By following these architectural patterns, modules can evolve rapidly without compromising the overall system integrity.