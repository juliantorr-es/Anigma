# ECS, Data-Oriented Design, and Zero-Copy

## Official Sources
- **Unity Entities / DOTS**: [docs.unity3d.com](https://docs.unity3d.com/Packages/com.unity.entities@1.0/manual/index.html)
- **Unity ECS Chunk Storage**: [docs.unity3d.com](https://docs.unity3d.com/Packages/com.unity.entities@0.1/manual/ecs_components.html)
- **Unity Archetype Chunks**: [docs.unity3d.com](https://docs.unity3d.com/Packages/com.unity.entities@1.0/manual/concepts-archetypes.html)

## Findings
Unity's Data-Oriented Technology Stack (DOTS) heavily utilizes the Entity Component System (ECS) architecture to improve performance through data locality. 

### Core Concepts
1. **Entities**: Identifiers (IDs) rather than objects.
2. **Components**: Pure data structs grouped by archetype.
3. **Systems**: Logic that operates on specific queries of components.
4. **Archetypes**: A unique combination of component types.
5. **Chunks**: 16 KiB uniform memory blocks where components of the same archetype are stored.

### Data Locality & Structure of Arrays (SoA)
Storing same-archetype component data together in contiguous chunks drastically improves cache utilization. When a system queries for a specific set of components, it iterates over chunks in a linear, predictable memory pattern. This is a classic Structure of Arrays (SoA) optimization.

## Anigma Application
Anigma should adopt an "ECS-inspired data-oriented runtime". 
- **Chunked Storage**: Anigma can use chunk-based storage for hot vectors/tensors, aligning with cache lines and GPU memory boundaries.
- **Copy-Minimized vs. Zero-Copy**: Passing a chunk reference to an executor is "copy-minimized". It is only "zero-copy proven" if instrumentation explicitly guarantees no new materialization occurred across the boundary.
- **Component Contracts**: Must remain portable and contain no native executor handles (e.g., no `MTLBuffer` pointers in portable components).