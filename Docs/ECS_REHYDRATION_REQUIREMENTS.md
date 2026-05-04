# Anigma Codebase Rehydration: AST-to-ECS Requirements

## Core Concept
Entities represent AST nodes. Components represent semantic, syntactic, or analysis data (e.g., SymbolTable, TypeInfo, RewritePipelineState).

## 1. Incremental Parsing and Memory Efficiency
- **Stateful Incrementalism:** Re-use previously generated component states if a node's source range (or its children's) is unchanged.
- **Node Identity:** SwiftSyntax nodes are immutable. Rehydration must compute stable identity (e.g., node path or hash of subtree) to maintain component references across incremental parsing updates.
- **Memory Management:** Use arena-based or pool-based storage for ECS component data to reduce heap fragmentation during heavy AST processing.

## 2. AST-to-ECS Mapping
- **Entity Identity:** Map `SyntaxNode` references to integer-based ECS entity IDs.
- **Structural Mirroring:** ECS queries should reflect AST structure (e.g., `parent`, `child` components).
- **Façade Pattern:** Continue isolating raw SwiftSyntax nodes within specialized 'SyntaxSource' components; other systems operate only on component data.

## 3. Rehydration Workflow
- **Invalidation Trigger:** Detect changes via LSP or file watches.
- **Differential Update:**
    - Parse changed regions.
    - Match new AST nodes against existing entity components.
    - Update/Invalidate components for modified subtrees.
- **System Synchronization:** Re-run analysis systems (type checking, rule application) only on entities invalidated by AST changes.
