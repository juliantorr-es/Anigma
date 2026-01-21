# P0 Model Registry Implementation Status

## Completed ✅

### 1. Model Contract Types (`Sources/AnigmaAppMac/Model/Contracts/ModelContracts.swift`)
- **TaskKind enum**: Defines supported ML task types (inference, embedding, transcription, classification, imageGeneration, speechSynthesis)
- **TaskParams enum**: Task-specific parameters with type safety
- **ModelSpec struct**: Immutable model specification with:
  - Model ID, hash, task kind, backend format
  - Dimension, tokenizer hash, license
  - Trust tier (first-class, compatible, experimental)
  - Source provenance (HuggingFace, local, bundled)
  - Canonical hash for signing
- **RunSpec struct**: Execution specification with:
  - Run ID, model spec, task params
  - Input hash for reproducibility
  - Workflow/job correlation
  - Data classification for policy gates
  - Canonical hash for signing
- **MLEvidenceHead struct**: Court-safe evidence with receipt and policy decision

### 2. Updated ModelRegistry (`Sources/AnigmaAppMac/Services/ModelRegistry.swift`)
- Uses ModelSpec contracts instead of ad-hoc ModelRegistryEntry
- Atomic file-based persistence with sorted JSON
- Operations:
  - `register(ModelSpec)`: Register governed model
  - `find(id)`: Lookup by ID
  - `query(taskKind, trustTier, backendFormat)`: Filtered queries
  - `updateTrustTier()`: Tier promotions/demotions
  - `verifyIntegrity()`: Hash-based verification
  - `delete()`: Safe deletion (preserves bundled models)
  - `listAll()`: Full registry dump

### 3. Test Suite (`Tests/AnigmaAppMacTests/ModelRegistryTests.swift`)
Comprehensive test coverage for:
- Register and find operations
- Query by task kind
- Query by trust tier
- Trust tier updates
- Canonical hash determinism
- Delete operations
- List all models

## Blockers 🚨

### 1. Build Errors in Contextum Module
The ContextumModule has compilation errors preventing tests from running:
- `IdempotencyGuard.swift`: Missing `.text()` parameter binding
- `ContextumDatabase.swift`: Type inference issues in `compactMap`
- These are separate from Model Registry but block the full test suite

### 2. Integration Errors in Orchestrators
- `LocalLLMOrchestrator.swift` and `SandboxedOrchestrator.swift` have mismatched MLWorker API calls
- Need to align with actual MLWorkerClient interface

### 3. Type Name Collision Fixed
- Renamed `SourceType` → `ModelSourceType` to avoid collision with existing `SourceType` in `SpineObjects.swift`

## Next Steps

### Immediate (P0)
1. **Fix Contextum build errors** so tests can run
2. **Run ModelRegistryTests** to verify P0 implementation
3. **Wire ModelRegistry into MLWorkerClient** for governed execution

### Phase 1 (After P0)
4. **Implement HF Source Adapter** (fetch, verify, describe)
5. **Add conversion receipts** for GGUF → MLX, HF → MLX
6. **License gate integration** at import time

### Phase 2
7. **Auto-indexing trigger** from artifact commits
8. **Model→Contextum bridg