# Personal-Context Memory Evaluation Matrix (Anigma)

This matrix defines initial executable evaluation coverage for personal-context quality using current Anigma grounding contracts (`AnswerProvenanceRecord`, `RecallResult`, `AssistantContextSourcePolicy`) and assistant provenance generation in `AppModel.generateAssistantProvenance`.

## Scope

Inspired by LongMemEval categories, but grounded to current repo behavior:

1. knowledge update correctness
2. temporal reasoning
3. stale-memory abstention
4. profile consistency
5. real-task retrieval usefulness

Executable coverage lives in:

- `Tests/AssistantEvalFixturesTests/PersonalContextMemoryEvaluationTests.swift`

## Scoring Dimensions

Each dimension is scored on `[0.0, 1.0]` from observable grounded outputs.

| Dimension | Score Signals (current harness) | Pass Threshold |
|---|---|---|
| Knowledge update correctness | Top source ID matches expected latest source (0.6) + answer contains expected updated fragment (0.4) | `>= 0.90` |
| Temporal reasoning | Top source ID matches expected time-scoped source (0.5) + answer includes temporal cue (0.25) + recall not missing (0.25) | `>= 0.80` |
| Stale-memory abstention | Replay marked non-replayable (0.5) + abstaining answer text (0.3) + required missing-context markers present (0.2) | `>= 1.00` |
| Profile consistency | Principal ID stable (0.4) + project ID stable (0.3) + no pin/exclude conflict in policy (0.3) | `>= 1.00` |
| Real-task retrieval usefulness | Non-empty evidence sources (0.4) + confidence floor met (0.3) + answer includes useful retrieved fragment (0.3) | `>= 0.80` |

Overall suite threshold: average dimension score `>= 0.90`.

## Initial Scenario Set

| Scenario ID | Category | Grounded Behavior Protected |
|---|---|---|
| `knowledge-update-correctness` | Knowledge updates | Assistant should ground on superseding source (`runbook-v2`) rather than legacy source when both exist. |
| `temporal-reasoning` | Temporal reasoning | Time-scoped query should prioritize latest temporal evidence (`oncall-apr-2026`). |
| `stale-memory-abstention` | Abstention | With no recall hits and scan limit reached, assistant should abstain and expose missing-context reasons. |
| `profile-consistency` | Profile consistency | Provenance should keep stable `principalId`/`projectId` and conflict-free context policy. |
| `real-task-retrieval-usefulness` | Real task usefulness | Production-like replay query should return actionable grounded evidence and adequate confidence. |

## Grounding-Contract Tie-In

The matrix is intentionally tied to current contracts and generated fields:

- `AnswerProvenanceRecord.sources`, `answerText`, `confidence`
- `AnswerProvenanceRecord.missingContext`
- `AnswerProvenanceRecord.replay.replayable`
- `AnswerProvenanceRecord.principalId`, `projectId`, `contextPolicy`

This keeps the evaluation executable now, without broad refactors into unfinished profile-memory subsystems.

## Execution

Run targeted suite:

```bash
cd anigma
swift test --filter PersonalContextMemoryEvaluationTests
```

Run full assistant eval fixture suite:

```bash
cd anigma
swift test --filter AssistantEvalFixturesTests
```
