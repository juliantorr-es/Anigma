# Codebase Cleanup & Runtime Alignment Doctrine

## Purpose
Govern cleanup as evidence-backed alignment work to ensure the Anigma codebase remains lean, reachable, and aligned with the consolidated `anigmad` runtime model.

## Principles
1. **Evidence-First**: Audit findings are review candidates, not automatic bugs. Deletion or refactoring requires proof of the issue (e.g., dead-code reachability proof or executable-consolidation violation).
2. **Conservative Deletion**: Dead code is removed only after high-confidence unused classification, baseline comparison, and focused validation.
3. **Runtime Alignment**: Executable-consolidation assumptions (like `exit()`, `process_identity`, or `singleton_global_state`) are repaired only after proving they conflict with the consolidated `anigmad` model.
4. **Public API Protection**: Deletion of public APIs is forbidden without separate architectural approval, even if they appear unused by internal callers.
5. **Ratcheted Gates**: Baselines are used as ratchets to prevent new violations while allowing existing technical debt to be triaged over time.
6. **Advisory by Default**: Diagnostic lanes remain advisory until a calibration proof explicitly recommends promoting them to gate mode.

## Triage Priority
1. **Structural Risks**: Findings in `anigmad`-reachable code that impact lifecycle, IPC, or resource ownership (e.g., `shutdown_and_exit`, `daemon_ipc_binding`).
2. **Resource Integrity**: Violations of the consolidated process model (e.g., `process_identity`, `argv_and_environment`).
3. **Architectural Purity**: Global singletons or detached tasks that bypass governed authority layers.
4. **Cosmetic Hygiene**: Cosmetic logging or minor dead code (low priority unless in high-churn areas).

## Workflow
- **Audit**: Run automated lanes to identify candidates.
- **Triage**: Classify candidates as `confirmed_risk`, `likely_risk`, `benign`, `false_positive`, or `needs_context`.
- **Proof**: Generate evidence for `confirmed_risk` items.
- **Batch**: Group confirmed items into small, targeted cleanup batches (Batch 001, 002, etc.).
- **Validate**: Verify that cleanup doesn't break existing functionality.
