# Command System Ledger & Events

`harmonia cmd run` now records every rendered command and decision into two governed artifacts: the ledger at `.opencode/ledger/workflow.jsonl` and the session-scoped event stream under `Artifacts/praxis/events/<session-id>/ …`.

The ledger records are plain JSON lines conforming to `CommandLedgerRecord` (see `Sources/PraxisCore/CommandSystem/CommandLedger.swift`). Each entry includes the session ID, agent profile, command name, receipt path, and a `detail` map that auditors can extend with tool/validation metadata. The event stream records transitions such as `commandStarted`, `permissionDecision`, and `commandCompleted` using `CommandEvent` objects serialized to `Artifacts/praxis/events/<session-id>`.

Dashboard or audit tooling should reuse the supplied helpers:

1. Use `CommandLedgerReader` (`Sources/PraxisCore/CommandSystem/CommandLedgerReader.swift`) to load all ledger entries and group them by session. It handles ISO8601 timestamps and ensures the ledger directory exists.
2. Use `CommandEventReader` (`Sources/PraxisCore/CommandSystem/CommandEventReader.swift`) to list the events for a given session. Each event already carries the artifact paths you need for stdout/stderr traces.

The built-in audit command (`harmonia cmd audit`) already demonstrates how to combine both readers and render human-friendly output. Extend or re-use that pattern in dashboards, reporting scripts, or any manual inspection workflows so you consume the exact same data that Praxis stores for replay.

If you expose this data to other systems, be sure to preserve the ledger/event provenance (session ID, receipt path, agent profile) so downstream consumers can tie findings back to a governed command invocation.
