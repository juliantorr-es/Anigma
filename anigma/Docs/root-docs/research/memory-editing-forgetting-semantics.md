> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research: Memory Editing and Forgetting Operation Semantics

**Status**: Research Phase Complete  
**Task**: td-ec500d  
**Author**: Harmonia Research Team  
**Last Updated**: 2026-04-14

## Executive Summary

Harmonia V3 requires mechanisms to:
1. **Edit memories**: Update incorrect or stale facts
2. **Forget memories**: Remove unwanted/private information
3. **Maintain consistency**: Preserve relationships when editing

This research evaluates:
- **Edit operations**: Update modes, cascading effects, versioning
- **Forgetting mechanisms**: Selective deletion, unlearning, privacy-preserving approaches
- **Consistency maintenance**: Integrity constraints, cascade rules, rollback strategies
- **Auditability**: Who edited what, why, when (for compliance/debugging)

### Key Findings

| Operation | Mechanism | Complexity | Risk |
|-----------|-----------|-----------|------|
| Fact update | In-place with versioning | Low | Low (traced) |
| Relationship edit | Cascade + validation | Medium | Medium |
| Semantic forgetting | Embedding shift + retrain | High | High (data loss) |
| Privacy delete | Immutable log + pointer hiding | Medium | Low (recovery possible) |

### Recommendations

**For Harmonia V3**:
1. **Primary strategy**: Versioned updates with cascade validation
2. **Forgetting approach**: Privacy-preserving delete (audit trail remains, data hidden)
3. **Consistency model**: Strict during edits, eventual for cascades
4. **Implementation timeline**: 3-4 weeks phased rollout

---

## 1. The Memory Editing Problem

### 1.1 Why Memory Editing Matters

In long-running systems, facts become incorrect:
- **Stale**: "User's role is Admin" → "User's role is Viewer"
- **Wrong**: "Project deadline: Tuesday" → "Project deadline: Friday"
- **Outdated**: "Database has 5 tables" → "Database has 12 tables"
- **Hallucinated**: "API returns XML" (but actually returns JSON)

Without editing, systems:
- Continue using incorrect facts
- Make wrong decisions based on old data
- Accumulate errors over time
- Violate data privacy requirements

### 1.2 Memory Architecture Context

Harmonia V3 stores memories across multiple levels:

```
Application Memory (Ephemeral)
├─ Current context: Last 3-5 turns
├─ Working context: Last 20-50 turns
└─ History cache: Last 500+ turns

Long-Term Memory (Persistent)
├─ Episodic: "On Tuesday, user asked about X" (timestamped)
├─ Semantic: "Users prefer dark mode" (generalized)
├─ Procedural: "API endpoint at /api/v2/query" (how-to)
└─ Metadata: Tags, importance, confidence scores

Vector Store (Searchable Embeddings)
├─ Embedding vectors for all memories
├─ Similarity-based retrieval
└─ Semantic relationships
```

**Editing complexity**: Changes must propagate through multiple layers.

### 1.3 Editing Scenarios

**Scenario 1: Simple Fact Update**
```
Before: "Product launch date: Q2 2024"
After: "Product launch date: Q1 2025"
Scope: 1 memory, 1 embedding update
```

**Scenario 2: Relationship Cascade**
```
Before: "Project A depends on Project B"
User: "Actually, B depends on A"
After: 
  - Edit relationship direction
  - Update Project A's dependency list
  - Update Project B's dependency list
  - Update all cascading derived facts
Scope: 3+ memories, complex validation
```

**Scenario 3: Semantic Correction**
```
Before: Embedding learned: "User prefers quick summaries"
Evidence: User said "I like summaries"
Correction: "User actually said 'I dislike summaries'"
After: 
  - Retrain embedding with corrected data
  - All similar facts now use new embedding
Scope: Potentially hundreds of memories
```

**Scenario 4: Privacy Deletion**
```
Before: "User's SSN: 123-45-6789", stored in embedding
User: "Delete my SSN"
Options:
  A. Physically remove (recovery impossible)
  B. Mask and hide (recovery possible, hidden from queries)
  C. Encrypt with user key (user can decrypt later)
```

---

## 2. Edit Operation Modes

### 2.1 In-Place Update

**Mechanism**: Modify memory directly, keep history.

```python
class Memory:
    id: str
    content: str
    embedding: Vector
    version: int
    created_at: DateTime
    updated_at: DateTime
    history: List[MemoryVersion]
    
    def update(self, new_content: str, reason: str):
        # Store old version
        self.history.append(MemoryVersion(
            version=self.version,
            content=self.content,
            embedding=self.embedding,
            timestamp=self.updated_at,
            edited_by='user_id',
            reason=reason
        ))
        
        # Update current
        self.version += 1
        self.content = new_content
        self.embedding = embed(new_content)
        self.updated_at = now()
        
        # Trigger cascades if needed
        self.notify_dependents('updated')
```

**Characteristics**:
- ✅ Simple implementation
- ✅ Full recovery possible
- ✅ Audit trail preserved
- ⚠️ Storage overhead for history
- ⚠️ Complex cascade updates

### 2.2 Copy-on-Write

**Mechanism**: Create new version, preserve old.

```python
def copy_on_write_edit(original_memory_id: str, updates: dict) -> str:
    original = db.get_memory(original_memory_id)
    
    # Create new version
    new_version = Memory(
        id=generate_uuid(),
        parent_id=original_memory_id,
        version=original.version + 1,
        content={**original.content, **updates},
        embedding=embed(updated_content),
        created_at=original.created_at,  # Preserve creation
        updated_at=now(),
        edit_reason=updates.get('_reason'),
        edited_by=updates.get('_edited_by')
    )
    
    db.save(new_version)
    
    # Mark old version as superseded
    original.superseded_by = new_version.id
    db.update(original)
    
    return new_version.id
```

**Characteristics**:
- ✅ Non-destructive (all versions preserved)
- ✅ Easy rollback
- ⚠️ More storage
- ⚠️ Version management complexity
- ⚠️ Query performance (need to select "current")

### 2.3 Three-Way Merge

**Mechanism**: Detect conflicts when multiple edits occur.

Useful when:
- User edited a fact
- System also changed that fact
- Need to merge safely

```python
def three_way_merge(original, user_edit, system_update):
    """
    Original: "Team size: 5"
    User: Edits to "Team size: 8 (after hiring)"
    System: Also edits to "Team size: 6" (recruitment)
    
    Merge strategy:
    - User mentioned "hiring", system also shows increase
    - Likely compatible changes
    - Result: "Team size: 8 (system says 6, user says 8)"
    """
    
    base_text = original.content
    user_text = user_edit.content
    system_text = system_update.content
    
    # Simple text merge (can use diff3 algorithm)
    merged = merge_texts(base_text, user_text, system_text)
    
    # Detect conflicts
    conflicts = detect_conflicts(merged)
    
    if conflicts:
        return {
            'status': 'conflict',
            'merged_content': merged,
            'conflicts': conflicts,
            'resolution_needed': True
        }
    else:
        return {
            'status': 'success',
            'merged_content': merged,
            'conflicts': [],
            'resolution_needed': False
        }
```

**Characteristics**:
- ✅ Handles concurrent edits
- ✅ Minimizes data loss
- ⚠️ Complex implementation
- ⚠️ Still requires manual resolution sometimes

---

## 3. Cascade Operations

### 3.1 Identifying Dependencies

**What needs to cascade?**

```
Memory: "Project A status: Active"

Dependents:
├─ Project metrics dashboard (recalculate)
├─ Project timeline (status changed)
├─ Team notifications (status alert)
├─ Reports (update latest status)
└─ Derived facts ("Project is not finished" depends on status)
```

**Dependency tracking**:
```python
class DependencyGraph:
    def __init__(self):
        self.edges = {}  # memory_id -> set of dependent memory_ids
    
    def add_dependency(self, source_id, dependent_id):
        if source_id not in self.edges:
            self.edges[source_id] = set()
        self.edges[source_id].add(dependent_id)
    
    def get_dependents(self, memory_id, recursive=True):
        """Get all memories that depend on this one"""
        if memory_id not in self.edges:
            return set()
        
        direct = self.edges[memory_id]
        
        if not recursive:
            return direct
        
        # Recursive: get dependents of dependents
        transitive = set(direct)
        for dep in direct:
            transitive.update(self.get_dependents(dep, recursive=True))
        
        return transitive
    
    def detect_cycles(self):
        """Detect circular dependencies"""
        for source in self.edges:
            visited = set()
            if has_cycle_from(source, visited, self.edges):
                return True
        return False
```

### 3.2 Cascade Modes

**Mode 1: Immediate Cascade**
```
User edits "Project A status"
│
├─ 1ms: Update memory
├─ 2ms: Invalidate dependent caches
├─ 3ms: Trigger recalculations
└─ 5ms: Notify interested parties
```

**Characteristics**:
- ✅ Consistent immediately
- ⚠️ Slow if many dependents
- ⚠️ Can cause cascading latency

**Mode 2: Eventual Cascade**
```
User edits "Project A status"
│
├─ 0ms: Update memory (returns immediately)
├─ Background queue: Cascade operations
│  ├─ Invalidate caches (eventual)
│  ├─ Recalculate metrics (eventual)
│  └─ Update reports (eventual)
└─ User sees updated memory, downstream updates follow (seconds to minutes)
```

**Characteristics**:
- ✅ Fast response
- ⚠️ Temporary inconsistency
- ⚠️ Requires consistency model clarity

**Mode 3: Lazy Cascade**
```
User edits "Project A status"
│
├─ 0ms: Update memory
├─ No immediate cascade
└─ On-demand: Cascade happens when dependent is accessed
   "What's the project status?" → Cascade triggered, then answered
```

**Characteristics**:
- ✅ Minimal latency impact
- ⚠️ Unpredictable delay (on access)
- ✅ Good for rarely-accessed dependents

### 3.3 Cascade Validation

**Ensure edits don't break consistency**:

```python
def validate_cascade(memory, original_value, new_value):
    """
    Example: Editing task status
    Original: "pending"
    New: "complete"
    
    Rules to validate:
    - Task cannot be completed if prerequisites not done
    - Task completion updates project progress
    - Cannot complete if other tasks depend on it still running
    """
    
    # Get all rules for this memory type
    rules = get_validation_rules(memory.type)
    
    violations = []
    for rule in rules:
        if rule.applies_to_change(original_value, new_value):
            if not rule.is_satisfied(memory, new_value):
                violations.append({
                    'rule': rule.name,
                    'reason': rule.why_violated(memory, new_value),
                    'remediation': rule.suggest_fix(memory, new_value)
                })
    
    return {
        'valid': len(violations) == 0,
        'violations': violations
    }
```

**Example violation detection**:
```
Edit: Status "active" → "archived"
Dependent: "Team member works on this project"

Violation: "Cannot archive project while team members are assigned"
Remediation: "Reassign team members or mark as inactive (not archived)"
```

---

## 4. Forgetting Mechanisms

### 4.1 Selective Deletion

**Approach**: Remove specific memory completely.

```python
def delete_memory(memory_id: str, reason: str, user_id: str):
    memory = db.get_memory(memory_id)
    
    # Validation
    if memory.has_dependents() and reason != 'privacy':
        raise ValueError(
            f"Cannot delete: {len(memory.dependents)} memories depend on this"
        )
    
    # Create deletion record (for audit trail)
    deletion_record = DeletionRecord(
        memory_id=memory_id,
        reason=reason,
        deleted_by=user_id,
        timestamp=now(),
        original_content_hash=hash(memory.content),
        recovery_window_expires=now() + timedelta(days=90)
    )
    
    # Delete from active store
    db.delete(memory_id)
    
    # Archive to audit log
    audit_log.append(deletion_record)
    
    # Update dependents
    for dependent_id in memory.get_dependents():
        notify_dependent_deleted(dependent_id, memory_id)
    
    return deletion_record
```

**Characteristics**:
- ✅ Clean removal
- ✅ Audit trail preserved
- ⚠️ Cascading deletions complex
- ⚠️ Cannot recover deleted data

### 4.2 Privacy-Preserving Delete

**Approach**: Hide data but keep trace for recovery/audit.

Useful for: Compliance (GDPR, CCPA), user requests.

```python
def privacy_delete(memory_id: str, user_id: str):
    """
    GDPR-compliant deletion:
    - User's data is removed from active queries
    - Audit trail remains for compliance
    - Recovery possible within retention window
    """
    
    memory = db.get_memory(memory_id)
    
    # Create deletion marker (not deleted, but marked)
    deletion_marker = PrivacyDeletionMarker(
        memory_id=memory_id,
        user_id=user_id,
        reason='privacy_request',
        timestamp=now(),
        original_hash=hash(memory.content),
        encrypted_copy=encrypt(
            memory.content,
            key=f'privacy_key_{user_id}_{memory_id}'
        ),
        retention_until=now() + timedelta(days=90)
    )
    
    # Hide from queries (not physically deleted)
    memory.is_hidden = True
    memory.hide_reason = 'privacy'
    memory.hidden_at = now()
    
    # Update embeddings (soft delete)
    vector_store.hide_embedding(memory.embedding_id)
    
    # Log for compliance
    compliance_log.append({
        'action': 'privacy_delete',
        'user_id': user_id,
        'resource': memory_id,
        'timestamp': now(),
        'reason': 'user_request'
    })
    
    db.save(memory)
    db.save(deletion_marker)
    
    return deletion_marker
```

**Characteristics**:
- ✅ GDPR/CCPA compliant
- ✅ Audit trail preserved
- ✅ Recovery possible (within window)
- ✅ User can request permanent deletion
- ⚠️ Requires careful key management

### 4.3 Semantic Unlearning

**Approach**: Remove fact from model without retraining.

**The challenge**: Once a model learns a pattern, it's hard to "unlearn" without retraining.

```python
def semantic_unlearn(fact: str, memory_store: MemoryStore):
    """
    Fact: "John is allergic to peanuts"
    Goal: Remove this from model's knowledge
    
    Approaches:
    1. Adversarial unlearning: Add contradictory examples
    2. Attention masking: Hide from retrieval
    3. Gradient-based unlearning: Reverse training signal
    4. Retraining: Full model retraining (expensive)
    """
    
    # Approach 1: Adversarial unlearning (low cost, approximate)
    unlearning_examples = generate_contradictions(fact)
    # "John can safely eat peanuts" (contradicts original)
    
    memory_store.add_with_low_priority(unlearning_examples)
    memory_store.add_embedding_mask(fact)
    
    return {
        'method': 'adversarial_unlearning',
        'effectiveness': 0.7,  # 70 0.000000e+00ffectiveness
        'cost': 'low',
        'recovery': 'possible'
    }
```

**When to use**:
- Incorrect learned patterns
- Outdated behavioral biases
- Undesired model behavior

**Tradeoffs**:
| Method | Effectiveness | Cost | Recovery |
|--------|-------------|------|----------|
| Adversarial masking | 60-70