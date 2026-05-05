# Proof: Block-Level Diffing Engine Design

## Status
- **Design Status**: Complete.
- **Reference**: `Docs/publishing/DESIGN_BLOCK_DIFFING_ENGINE.md`.
- **Preceding Proof**: `Docs/proofs/tb-2026-05-04-publisher-integrity-hardening.md`.

## Design Summary
- **Identity**: Fingerprints based on Type + Hierarchical position + Content hash.
- **Algorithm**: Tree-based comparison with "high-confidence" matching requirements.
- **Fallbacks**: Explicit fallback to the existing "Clear-and-Reappend" sync lane when diff confidence is low.
- **Safety**: "No-Destruction" guard for deletes and opt-in execution via `--block-diff` flag.

## Validation Strategy
- **Fake-client Harness**: Will be implemented to simulate Notion API responses, covering common editing scenarios (add, update, delete, reorder).
- **Smoke Tests**: Real-Notion verification will compare block IDs across two cycles with `--block-diff` enabled.

## Referential Integrity Impact
- **Positive**: Enables stable deep links for Notion blocks.
- **Risk**: Potential for low-confidence diffs to cause erroneous mutations.
- **Mitigation**: Conservative diff algorithm + mandatory fallback to the stable page-level sync.

## Recommended Implementation Task
1. Implement the tree-traversal logic in `notion/client.py`.
2. Implement the fingerprinting logic in `scripts/anigma_publish_notion_v2.py`.
3. Add the `diff_blocks` engine.
4. Run integration tests in dry-run mode before live sync.
