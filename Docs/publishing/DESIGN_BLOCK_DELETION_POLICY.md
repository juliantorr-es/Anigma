# Design: Block-Level Destructive Mutation Policy

## 1. Objective
Enable safe, audited removal of Notion blocks via the publisher, while maintaining strict architectural governance and referential integrity.

## 2. Destructive Action Eligibility
Destructive operations (`ARCHIVE`) are strictly governed:
- **High-Confidence Only**: Deletion is only permitted when the block fingerprint match has a high-confidence score (e.g., unambiguous structural position and content).
- **Subtree Integrity**: Nested subtrees are only eligible if the parent and all children match the "remove" signature, preventing fragmented data loss.
- **Fail-Closed**: If deletion creates structural ambiguity, the entire sync operation fails before mutation.

## 3. Tombstone Proof Model
Every destructive operation (dry-run or live) must generate a tombstone record (JSONL) with:
- `page_title`, `page_id`, `block_id`, `block_type`
- `hierarchical_path`, `content_hash`
- `reason` (e.g., "removed from source"), `confidence_score`
- `timestamp`, `mode` (dry-run/live)
- `before_after_summary`

## 4. Execution Policy
- **Dual-Opt-In**: Destructive actions require both `--block-diff` and `--allow-block-archive` flags.
- **No-Destruction Guard**: The publisher refuses to delete blocks if the source rendered payload is empty or otherwise invalid.
- **Audit Requirement**: Tombstones must be emitted before mutation execution begins.

## 5. Failure Handling
- **Partial Execution**: If a mid-sequence archive fails, the engine stops and reports the state.
- **Rollback**: Notion API does not support transactional block deletion; the system is designed to "fail-closed."

## 6. Validation
- **Unit Tests**: Mock a page with three paragraphs and attempt to archive the second one to verify logic.
- **Diagnostic Mode**: Verify dry-run outputs include the tombstone summary for intended deletes.
- **Smoke Tests**: Real-Notion verification on a test page to confirm only the specified blocks are archived.
