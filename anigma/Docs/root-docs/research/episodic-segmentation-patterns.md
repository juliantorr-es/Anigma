> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


---
title: Episodic Segmentation and Context Reconstruction Patterns
category: research
owner: Engineering Team
status: research
created: 2026-04-16
phase: research
epic: harmonia-v3
---

# Research: Episodic Segmentation and Context Reconstruction Patterns

## Executive Summary

This document evaluates patterns for episodic event segmentation and context reconstruction in multi-turn conversation systems. Key topics include:

1. **Episode Definition** - What constitutes a meaningful episode in long interactions
2. **Segmentation Strategies** - Algorithms for automatically breaking interactions into episodes
3. **Context Reconstruction** - Rebuilding necessary context from historical episodes
4. **Working Memory Organization** - Structuring context for efficient retrieval

**Core Challenge**: In long-running sessions (100+ turns), maintaining coherent context becomes expensive. Episodes provide a way to organize history into digestible chunks.

**Key Finding**: Successful systems use hybrid approaches combining:
- Turn-level boundaries (heuristic segmentation)
- Semantic boundaries (topic/intent changes)
- Temporal boundaries (idle periods)
- User-directed boundaries (explicit episode markers)

---

## Part 1: Episode Concepts

### What is an Episode?

An **episode** is a logically coherent segment of interaction history:

**Characteristics**:
- Covers a specific goal or topic
- Contains 5-20 turns (typical)
- Has clear entry/exit points
- Preserves context for reconstruction
- Semantically self-contained

**Examples**:
1. User asks question → Agent researches → User refines → Agent answers (4 turns)
2. Multi-step task: specification → implementation → review → iteration (8 turns)
3. Extended dialogue: problem → exploration → solution → validation (12 turns)

### Episode Components

```
Episode {
  id: string                    // Unique episode ID
  sessionId: string            // Session it belongs to
  tenantId: string             // Tenant scope
  startTurn: number            // First turn in episode
  endTurn: number              // Last turn in episode
  goal: string                 // Primary goal/topic
  summary: string              // Brief recap
  keyDecisions: [Decision]     // Important choices made
  context: ContextSnapshot     // State at episode end
  artifacts: [Artifact]        // Generated during episode
  metadata: {
    tags: [string]             // Categorization
    sentiment: string          // Overall tone
    success: boolean           // Reached goal?
    effort: number             // Approximate tokens/compute
  }
}
```

### Episode Lifecycle

```
Episode Lifecycle:
├─ Creation
│  ├─ Detect: Segmentation algorithm identifies boundary
│  ├─ Snapshot: Capture context state
│  └─ Index: Add to episode repository
├─ Active
│  ├─ Accumulate: Add turns as interaction continues
│  ├─ Monitor: Watch for completion/boundary signals
│  └─ Optimize: Periodically compress/summarize
└─ Closed
   ├─ Archive: Store in long-term episode memory
   ├─ Compress: Create summary for retrieval
   └─ Expunge: Clean up if exceeds retention
```

---

## Part 2: Segmentation Strategies

### Strategy 1: Heuristic Rule-Based (Simple)

**Algorithm**: Define explicit boundary conditions

```
Boundary Triggers:
- 20 consecutive turns without new goal
- Topic change detected (keyword shift)
- 5+ minute idle period
- Explicit user marker ("start new task")
- Error condition requiring reset
- Goal completion signal
```

**Pros**:
- Simple to implement
- Predictable segmentation
- Easy to debug
- Low computational cost

**Cons**:
- Requires careful tuning
- Misses semantic boundaries
- False positives/negatives
- Not adaptive

**Implementation Effort**: 1-2 days

### Strategy 2: Semantic Boundary Detection (ML-based)

**Algorithm**: Use embedding distance to detect topic changes

```
Procedure:
1. For each turn, generate embedding
2. Compare to previous turn embedding
3. If distance > threshold, potential boundary
4. Confirm with other signals
5. Mark as episode boundary

Distance Thresholds:
- Small delta (< 0.2): Continuation
- Medium delta (0.2-0.5): Refinement/digression
- Large delta (0.5-0.8): Topic shift
- Extreme delta (> 0.8): New domain
```

**Pros**:
- Detects semantic changes
- Adapts to content
- Less prone to false positives
- Works across domains

**Cons**:
- Requires embedding model
- Latency overhead
- Harder to debug/explain
- Threshold tuning needed

**Implementation Effort**: 1-2 weeks

### Strategy 3: Intent-Based Segmentation (NLU-based)

**Algorithm**: Track user intent; segment on intent change

```
Procedure:
1. Classify each turn's intent
2. Track intent history: [intent1, intent1, intent2, ...]
3. Detect intent shifts (intent1 → intent2)
4. Evaluate continuation score
5. Mark boundaries at significant shifts

Intent Examples:
- Ask/Clarify/Explore
- Specify/Review/Approve
- Implement/Test/Validate
- Pivot/Restart/Abandon
```

**Pros**:
- Semantically meaningful boundaries
- Aligns with user goals
- Natural for goal-oriented tasks
- Explainable segmentation

**Cons**:
- Requires intent classifier
- Domain-specific training
- Higher latency
- Complexity in multi-goal tasks

**Implementation Effort**: 2-3 weeks

### Strategy 4: Hybrid Approach (Recommended)

**Algorithm**: Combine multiple signals with weighted scoring

```
Procedure:
1. Generate heuristic boundary candidates
2. For each candidate, compute score:
   score = (
     0.3 * heuristic_signal +
     0.4 * semantic_distance +
     0.2 * intent_change +
     0.1 * temporal_signal
   )
3. Apply threshold (e.g., > 0.6)
4. Mark high-confidence boundaries
5. Validate with human annotation for learning
```

**Pros**:
- Combines strengths of all approaches
- Robust to individual signal failures
- Adaptive through learning
- High quality segmentation

**Cons**:
- Higher complexity
- More computational overhead
- Requires more tuning
- Harder to debug

**Implementation Effort**: 3-4 weeks

---

## Part 3: Context Reconstruction

### Reconstruction Problem

When resuming from an episode, the agent must answer:
1. **What was the goal?** (Episode objective)
2. **Where were we?** (Progress/state)
3. **What was decided?** (Key conclusions)
4. **What's the context?** (Relevant facts)
5. **What failed/what worked?** (Patterns)

### Reconstruction Approaches

#### Approach 1: Full Turn Replay

**Method**: Include all turns from episode in context

```
Pros:
- Complete information
- No information loss
- Easy to implement

Cons:
- Token expensive (400+ tokens per episode)
- Hard to parse for long episodes
- Redundant information
```

**Use Case**: Short episodes (< 10 turns)

#### Approach 2: Episode Summary

**Method**: Use generated summary of episode

```
Summary Template:
Goal: [What was being accomplished]
Participants: [Who was involved]
Key Points: [Bullet-point recap]
Decisions: [What was decided]
Artifacts: [What was created]
Outcome: [Success/failure/pending]
```

**Pros**:
- Compact (50-150 tokens)
- Human-readable
- Lossy but preserves essence

**Cons**:
- Summary quality varies
- May miss important details
- Requires generation overhead

**Use Case**: Medium episodes (10-30 turns)

#### Approach 3: Structured Context Snapshot

**Method**: Extract key information into structured format

```
ContextSnapshot {
  activeGoals: [Goal]         // Current objectives
  resolvedFacts: Map          // Questions answered
  openQuestions: [Question]   // Unresolved issues
  userPreferences: {key: val} // Stated preferences
  constraints: [Constraint]   // Limitations discovered
  artifacts: [Artifact]       // Generated outputs
  decisions: [Decision]       // Made choices
}
```

**Pros**:
- Highly structured
- Easy to query
- Selective inclusion
- Efficient representation

**Cons**:
- Requires structured extraction
- Doesn't capture nuance
- Machine-interpretable only

**Use Case**: Complex episodes with many decisions

#### Approach 4: Hierarchical Reconstruction

**Method**: Build multi-level context summary

```
Level 1: Episode List (5 tokens each)
  [ep1: "Asked questions", ep2: "Got clarifications", ep3: "Implemented solution"]

Level 2: Current Episode Summary (50 tokens)
  [Full summary of most recent episode]

Level 3: Recent Artifacts (variable)
  [List/links to recent outputs]

Level 4: On-Demand Detail (full turns if needed)
  [Only if relevant to current query]
```

**Pros**:
- Efficient token usage
- Scales to long sessions
- Preserves detail when needed
- Progressive disclosure

**Cons**:
- More complex implementation
- Requires relevance judgment
- May miss context on cold starts

**Use Case**: Long sessions (100+ turns)

---

## Part 4: Working Memory Organization

### Conceptual Model

```
Working Memory = {
  activeEpisode: Episode,           // Current episode
  episodeHistory: [Episode],        // Previous episodes
  persistentContext: Context,       // Cross-episode facts
  transientState: Map,              // Current turn state
  retrievalIndex: SearchIndex,      // Fast lookup
}
```

### Memory Organization Strategies

#### Strategy A: Episode Stack

```
Structure:
┌─────────────────────────────────┐
│ activeEpisode (in context)      │  ← Used in every prompt
├─────────────────────────────────┤
│ recent episodes (compact)       │  ← 1-2 most recent
├─────────────────────────────────┤
│ persistent facts/context        │  ← Cross-cutting
├─────────────────────────────────┤
│ all episodes (archived)         │  ← On-disk/LLM recall
└─────────────────────────────────┘
```

**Pros**: Clear hierarchy, efficient retrieval  
**Cons**: Fixed structure, may not fit all workloads  
**Use Case**: Goal-oriented sequential tasks

#### Strategy B: Episode Graph

```
Structure:
Episodes organized as DAG:
  ┌─ ep1 (clarify)
  │   ├─→ ep2 (research)
  │   └─→ ep3 (specify)
  ├─ ep2 (research)
  │   └─→ ep4 (implement)
  └─ ep5 (validate) ←─ ep4 (implement)

Queries traverse graph to find relevant episodes
```

**Pros**: Captures dependencies, flexible  
**Cons**: Complex to implement, overhead  
**Use Case**: Complex multi-branching conversations

#### Strategy C: Semantic Clustering

```
Structure:
Episodes clustered by semantic similarity:
  Cluster A (Topic: Architecture):
    - ep1: Initial design
    - ep7: Architecture review
    - ep12: Refactoring plan
  
  Cluster B (Topic: Implementation):
    - ep3: Code review
    - ep5: Testing strategy
    - ep9: Debugging session
```

**Pros**: Groups related episodes, efficient search  
**Cons**: Cluster membership ambiguous, overhead  
**Use Case**: Long, multi-topic sessions

---

## Part 5: Implementation Recommendations

### Phase 1: Simple Heuristic Segmentation (Weeks 1-2)

**Goals**:
- Get episodic segmentation working end-to-end
- Establish episode data structure
- Implement simple summary generation

**Tasks**:
1. Define Episode type in HarmoniaMemory
2. Implement heuristic boundary detection
3. Create episode storage in memory backend
4. Generate simple text summaries
5. Test with sample conversations

**Acceptance Criteria**:
- Episodes created after 20 turns or explicit marker
- Summaries generated automatically
- Can retrieve episode context
- Tested with 50+ synthetic conversations

### Phase 2: Semantic Segmentation (Weeks 3-4)

**Goals**:
- Add embedding-based boundary detection
- Improve segmentation accuracy
- Reduce heuristic false positives

**Tasks**:
1. Integrate embedding model
2. Implement semantic distance calculation
3. Tune distance thresholds
4. Hybrid heuristic + semantic detection
5. Performance testing

**Acceptance Criteria**:
- Semantic boundaries detected
- Recall > 900n test set
- Latency < 100ms per turn
- Production validation

### Phase 3: Context Reconstruction (Weeks 5-6)

**Goals**:
- Implement multi-level context reconstruction
- Minimize token overhead
- Preserve information for agents

**Tasks**:
1. Implement episode summaries
2. Extract structured context snapshots
3. Build hierarchical reconstruction
4. Test with actual agent interactions
5. Measure prompt token reduction

**Acceptance Criteria**:
- 40-600ken reduction vs full history
- Reconstruction quality validated
- Agent performance unchanged
- Works at scale (100+ turn sessions)

### Phase 4: Optimization & Learning (Weeks 7-8)

**Goals**:
- Learn from segmentation quality
- Adapt thresholds based on outcomes
- Production monitoring

**Tasks**:
1. Collect segmentation feedback
2. Implement threshold adaptation
3. Add production metrics
4. Create runbooks for issues
5. Performance tuning

---

## Part 6: Integration with Harmonia V3

### Memory Backend Integration

```swift
// In HarmoniaMemory
extension MemoryManager {
    // Store new episode
    func createEpisode(_ episode: Episode) async throws -> String
    
    // Retrieve episode by ID
    func retrieveEpisode(id: String) async throws -> Episode?
    
    // List episodes in session
    func listEpisodes(sessionId: String, limit: Int) async throws -> [Episode]
    
    // Reconstruct context from episode
    func reconstructContext(episodeId: String) async throws -> String
    
    // Detect episode boundary
    func evaluateBoundary(latestTurns: [Turn]) async throws -> BoundaryScore
}
```

### Session Context Flow

```
Turn-by-Turn Flow:
1. User input
2. Retrieve active episode
3. Build context (episodic + transient)
4. Agent reasoning
5. Generate response
6. Add to active episode
7. Evaluate boundary → create new episode if triggered
8. Store updated context
```

### Token Budget Example

```
For 100-turn session with 5 episodes:

Without Episodes:
  100 turns * 30 tokens/turn = 3,000 tokens (400f prompt)

With Episodes (Hierarchical):
  Active episode (15 turns) = 450 tokens
  Recent summaries (3 episodes) = 150 tokens
  Persistent context = 100 tokens
  Total = 700 tokens (90f prompt)
  
Savings: 750ken reduction
```

---

## Part 7: Risks and Mitigations

### Risk 1: Segmentation Accuracy
**Issue**: Wrong boundaries lose context or create confusion  
**Mitigation**: Start with conservative heuristics, add semantic gradually  
**Fallback**: Always include last 3-5 turns explicitly

### Risk 2: Context Loss
**Issue**: Episode summaries miss important details  
**Mitigation**: Start with full turn inclusion, compress gradually  
**Fallback**: Retrieval-augmented generation to find relevant turns

### Risk 3: Performance Overhead
**Issue**: Computing embeddings/classifiers adds latency  
**Mitigation**: Async computation, caching, batching  
**Fallback**: Graceful degradation to heuristic-only

### Risk 4: Episode Boundary Instability
**Issue**: Thresholds cause inconsistent segmentation  
**Mitigation**: Conservative thresholds, A/B testing, feedback loop  
**Fallback**: Manual episode markers from users

---

## Part 8: Competitive Analysis

### Existing Approaches

**OpenAI Conversations API**: 
- Uses fixed turn window (4K token rolling)
- No explicit episode boundaries
- Simple and effective for typical use cases

**Anthropic Claude**: 
- Full history within context window
- No active episodic memory
- Relies on user to manage context

**LangChain**: 
- Token counting and summarization
- No semantic episode detection
- Manual or rule-based only

**Enterprise Systems (Salesforce, Microsoft)**:
- Commercial solutions with domain-specific segmentation
- Intent-based episode tracking
- Closed systems, limited details

**Academic Research**:
- Episodic memory in cognitive science models
- Graph-based event representation
- Temporal context models

**Recommendation**: Hybrid heuristic + semantic approach represents state-of-the-art for general-purpose systems.

---

## Design Phase Considerations (Post-Research Cross-Reference)

Based on a cross-reference with Governance, Telemetry, Database, and Memory research, the following gaps must be addressed in the design:

1.  **Identity Hierarchy**: Align nomenclature. Standardize on **`ProjectID`** as the top-level tenant, mapping the hierarchy: `Project` > `Session` > `Run` > `Episode`. 1:1 mapping between `Episode` and `RunID` should be evaluated.
2.  **Persistent Segment Storage**: Move episode metadata and summaries from in-memory tracking to the PostgreSQL **`JobStore`** (identified in Database/Governance research). This ensures episodes survive restarts and are cross-referenced with Audit Receipts.
3.  **Governance of Context Summaries**: Episode summaries are high-sensitivity "Derived Knowledge." Their generation must be governed (proposed and decisioned) and recorded via `EvidenceAuthority`.
4.  **Implicit Context Flow**: Use the `CorrelationIDContext` (@TaskLocal) proposed in Telemetry research to automatically associate turn-level events with their parent Episode and Trace.

## Conclusion

Episodic segmentation addresses the core challenge of managing long interaction histories efficiently:

✅ **Short-term**: Heuristic rules (simple, immediate value)  
✅ **Medium-term**: Semantic boundaries (improved accuracy)  
✅ **Long-term**: Adaptive learning (self-improving system)  

**Next Step**: Begin with Phase 1 implementation (heuristic segmentation) while designing Phase 2 (semantic enhancement).

---

## References

### Related Research Topics
- Token budget management
- Conversation summarization
- Context compression
- Long-context LLMs

### Implementation Resources
- Episode data structure design
- Embedding models for boundaries
- Intent classification frameworks
- Context reconstruction algorithms