# Design: Notion Block-Level Diffing Engine

## 1. Objective
To maintain stable Notion block IDs across sync cycles, enabling persistent deep links while preserving the "source-first" architectural governance of the Anigma repository.

## 2. Block Identity Model
A block's identity is defined by a stable fingerprint constructed from:
- **Block Type**: (e.g., `paragraph`, `heading_1`, `code`)
- **Hierarchy Position**: Heading path/depth + ordinal index.
- **Content Hash**: Normalized text signature for leaf nodes.

### Identity Rules
- **Safe Match**: If a block at `[Heading A, Ordinal B]` has the same type as the rendered source, we treat it as an update.
- **Confidence Scoring**: 
  - High: Identical type and similar content hash.
  - Low: Ambiguous duplicate content, mixed hierarchy.
- **Fallback**: If identity is ambiguous, fall back to "Clear-and-Reappend" (current behavior) to avoid destructive/incorrect mutations.

## 3. Diff Algorithm
1. **Fetch**: Retrieve current Notion block tree (`get_block_children` recursively).
2. **Render**: Generate fresh block tree from source Markdown.
3. **Compare**:
   - `Match`: If `existing_block` and `new_block` share a stable fingerprint, update in place.
   - `Append`: New blocks not found in the existing tree are added to the end (or inserted if the tree allows, but appending is safer for MVP).
   - `Archive/Delete`: Blocks no longer present in the new source are removed, only if the deletion confidence is high (e.g., clear, unreferenced text).
   - `Conflict`: If confidence is low, discard diff actions and trigger page-level fallback.

## 4. Safety Policy
- **Cautious Deletion**: Never delete blocks if the match rate is below 80%.
- **No-Destruction Guard**: Continue existing empty-render guard (refuse to clear if new render is empty).
- **Opt-in Only**: Block diffing will be guarded by a `--block-diff` flag.
- **Diagnostic Mode**: All diff actions (`MATCH`, `UPDATE`, `APPEND`, `DELETE`, `FALLBACK`) must be logged.

## 5. Implementation Sequence
1. **Infrastructure**: Add `get_block_tree_recursive` to Notion client.
2. **Fingerprinting**: Implement stable block hashing.
3. **Engine**: Add `diff_blocks` logic.
4. **Integration**: Update `sync_docs_site` to use the diff engine if `--block-diff` is passed.

## 6. Verification
- **Functional**: Verify identity for paragraph edits, list item additions, and heading movements.
- **Safety**: Verify page-level fallback on high-risk diffs.
- **Stability**: Consecutive syncs confirm block ID persistence for high-confidence matches.
