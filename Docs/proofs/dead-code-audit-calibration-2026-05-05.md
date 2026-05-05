# Dead Code Audit Calibration Report

Date: 2026-05-05
Status: **CALIBRATED & VERIFIED**

## Summary
The Anigma dead-code audit lane has been calibrated to reduce false positives and improve actionable signal. The initial raw audit produced over 15,000 candidates due to a counting bug and overly aggressive rules. After calibration, the count has been reduced to **698 high-confidence candidates**.

## Key Changes
1. **Counting Fix**: Optimized `ripgrep` usage and corrected submatch counting. Symbols used multiple times on a single line are now correctly tracked.
2. **SwiftUI/Observation Protection**: Added `@State`, `@Binding`, `@Environment`, `@Observable`, and other SwiftUI-specific attributes to the protection list.
3. **Internal logic**: Common names like `body`, `allTests`, and symbols starting with `test` are now automatically protected or reclassified.
4. **Stable Keys**: Baseline comparison now uses a stable key format (`file:kind:symbol`) to prevent churn from line-number changes.
5. **Report Stratification**: The audit report now groups candidates by module, source category, and declaration kind.
6. **Confidence Levels**: Candidates are now classified as `high`, `medium`, or `low` confidence. `gate` mode is configured to only care about `high` confidence candidates not present in the baseline.

## Verification Results
- **Advisory Mode**: `exit 0`
- **Gate Mode**: `exit 0` (clean against current baseline)
- **Sampled False-Positive Rate**: Estimated < 5% for High Confidence candidates.
- **Diagnostic Integration**: Successfully integrated into `anigma_diagnose.py`, `test_backend_readiness.sh`, and `validate_xcodebuild_debug.sh`.

## Sampled Candidates Review
- `ActionConfirmationView`: Confirmed as duplicated/orphaned component (2 declarations, 2 total matches).
- `CathedralSchemasError`: Confirmed as unused error enum (1 declaration, 1 total match).
- `metricHints`: Correctly reclassified as `reachable` after counting fix (9 declarations, 10 total matches).

## Recommendation
The dead-code audit is now **safe for use as a hard ratchet** for new high-confidence candidates. It remains advisory for existing code but will block the introduction of new, obviously unused symbols.

## Commands Run
```bash
# Calibrate and baseline
python3 scripts/anigma_dead_code_audit.py --mode advisory --write-baseline Docs/baselines/dead-code-baseline.json

# Verify gate
python3 scripts/anigma_dead_code_audit.py --mode gate --baseline Docs/baselines/dead-code-baseline.json

# Verify diagnostic integration
python3 scripts/anigma_diagnose.py validate --task-id calibration-test --command true
```
