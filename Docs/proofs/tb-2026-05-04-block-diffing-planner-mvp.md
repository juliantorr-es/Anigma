# Proof: Block-Level Diffing Planner MVP

## Status
- **Implementation**: Completed
- **Changes**: Created `Scripts/notion/block_diff.py` (planner) and `tests/test_notion_block_diff.py` (test suite).
- **Goal**: Implement deterministic, governance-safe block-level diff planning.

## Implemented
- **Fingerprinting**: `get_block_fingerprint` generates stable hashes based on type, content, and language.
- **Diff Logic**: `plan_diff` generates a mutation plan with `KEEP`, `UPDATE`, `APPEND`, `DELETE`, and `FALLBACK` actions.
- **Safety**: 
    - Removed incorrect fallback on empty rendered list.
    - Preserved existing page-level fallback for type mismatches.
- **Testing**: Verified paragraph edits, additions, deletions, and type mismatches.

## Validation Results
- `python3 -m unittest tests/test_notion_block_diff.py` :: Passed (4 tests).
- `python3 -m py_compile Scripts/notion/block_diff.py` :: Passed.

## Artifact Integrity
- Canonical Sources: Unchanged.
- Publisher Behavior: Unchanged (no live integration yet).

## Remaining Limitations
- **Stable slot matching**: Currently uses index-based matching (O(N) with positional assumptions). A more robust diff using the fingerprint for reordering is planned.
- **Nested children**: Not currently handled.

## Recommended Next Task
- Wire the `plan_diff` output into `scripts/anigma_publish_notion_v2.py` behind an opt-in `--block-diff` flag.
- Implement real mutation execution based on the generated `MutationPlan`.
