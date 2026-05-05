# Design: Notion Table Block Diffing and Mutation

## 1. Objective
Enable stable ID preservation for cells in Notion tables, preventing page-wide clear-and-reappend cycles during table content updates while adhering to strict architectural governance.

## 2. Hierarchical Identity Model
A table's identity is resolved as a tree:
- **Table Block**: Identity via {Type, PagePath, TableIndex, ColumnCount}.
- **Row Block**: Identity via {TableID, RowOrdinal, ContentHash}.
- **Cell Block**: Identity via {RowID, ColumnOrdinal, ContentHash}.

## 3. Safe Mutation Policy
- **Permitted Mutations**:
    - `UPDATE` (Cell Text): Allowed only if column count matches and RowIdentity is high-confidence.
- **Blocked/Fallback Mutations**:
    - Structural Mismatch: Column count changes, table resizing.
    - Order Mismatch: Row reordering, row deletion, row insertion.
    - Ambiguity: Duplicate rows with identical fingerprints.
    - Unsupported Payloads: Non-textual cell content (e.g., mentions, files, multi-select).

## 4. Execution Policy
- **Update Only**: Phase 1 is restricted to cell text updates only.
- **Diagnostic Requirement**: All table diffing requires `--block-diff` and will be validated via dry-run reports before being eligible for live execution.
- **Fail-Closed**: If structural integrity is in doubt, the executor must abort the specific table mutation and fall back to the existing page-level sync lane.

## 5. Implementation Sequence
1. **Planner**: Update `block_diff.py` to recognize `table` and `table_row` types and generate cell-level fingerprints.
2. **Executor**: Add logic to handle `update_table_cell` via the Notion API.
3. **Safety**: Validate row/column stability before applying any patches.

## 6. Validation
- **Fake-client Harness**: Tests covering cell text edits, column count mismatches, and structural changes.
- **Diagnostics**: Ensure table update plans clearly report row/column confidence scores.
- **Governance**: Verify that tables remain protected from destructive reordering until a Row-Mutation Policy is established.
