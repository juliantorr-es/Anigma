# Mapping Docling Document Processing to Anigma ECS Runtime

**Status:** Research / Mapping
**Focus:** Translating Docling's high-fidelity document parsing and MCP-based orchestration into Anigma's ECS-based runtime.

## 1. Architectural Alignment

Docling is a heavy-duty document parsing engine. Anigma's ECS (`World`, `System`) can leverage Docling’s MCP server to offload high-fidelity PDF/media extraction without vendoring the entire Docling Python/Rust stack into Anigma's native runtime.

### Concept Mapping Table

| Docling Concept | Anigma ECS Mapping | Rationale |
| :--- | :--- | :--- |
| `DoclingDocument` | `DocumentEntity` (with `DocumentComponent`) | The primary data model to store parsed structures. |
| `Docling Pipeline` | `IngestionSystem` | Systems drive the asynchronous transformation. |
| `Docling MCP Server` | `GovernedExecutor` (Sidecar) | Docling runs as a sidecar process; Anigma interacts via MCP. |
| `Table/Text/Chunk` | `Entity` (Componentized) | Decompose complex docs into ECS entities for retrieval. |

## 2. Patterns for Anigma ECS Integration

### A. MCP Sidecar Orchestration
Docling provides an `mcp-server` that Anigma can invoke as a governed executor.
- **Mechanism:** The `IngestionAuthority` manages a `DoclingSidecarExecutable`.
- **Anigma Integration:** Anigma ECS entities represent the "Job" (Docling parsing task). When an entity enters the `.pendingParsing` state, a `SidecarDispatcherSystem` invokes the Docling MCP server, captures the output, and hydrates the entity with parsed JSON/Markdown components.

### B. Reactive Document Hydration
Instead of a single large `DocumentComponent`, decompose document sections.
- **ECS Pattern:**
    1. **Initial Hydration:** `RootComponent` stores source URI and basic metadata.
    2. **Sectioning System:** A `DoclingParserSystem` reads the file, parses content, and spawns child entities for every detected `Table`, `Image`, or `TextBlock`.
    3. **Relationship Mapping:** Parent `EntityId` links to children via a `CompositionComponent` (DAG structure).

### C. Deterministic Chunking & Evidence
Docling supports high-fidelity chunking.
- **ECS Pattern:** Each chunk entity receives a `ContentHashComponent`. 
- **Integrity:** This hash is recorded in a `DocumentReceipt` when the chunk is materialized into the `VectorumModule`, fulfilling Anigma's requirement that every AI-ingested chunk has a verifiable lineage.

## 3. Implementation Strategy: The "Document ECS Mirror"

Anigma should maintain a mirror of the Docling data structure within ECS:

```swift
/// Anigma ECS representation of a parsed document element
public struct DocumentElementComponent: Component, Codable {
    public let elementId: UUID
    public let type: DoclingElementType // e.g., Table, Text, Image
    public let contentHash: String
    public var metadata: [String: String]
}
```

This component allows Anigma's existing `SearchSystem` and `ValidationSystem` to query document structures directly from the `World` without re-parsing source documents.

## 4. Next Steps for Research

1.  **MCP Integration Proof**: Verify `uvx docling-mcp-server` communication from a Swift CLI test harness.
2.  **Schema Normalization**: Map Docling's JSON `DoclingDocument` output to Anigma's `Receipt` schema.
3.  **Performance Baseline**: Determine the overhead of "ECS-Hydrating" a large technical paper (e.g., 50+ pages) into individual entities.
