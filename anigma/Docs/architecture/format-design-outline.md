# Format Design, Black Boxes, and Why Anigma Won’t Rot

## 0. Opening

“We are not teaching documents, governance, or compliance—this is about structuring software so it survives.” Walk through three systems (accessibility pipeline, Harmonia runner, compliance deployment) to show the method.

## 1. What we optimize for

- **Dependability** across OS, dependency, and personnel churn.
- **Extendability** that adds modules instead of refactors.
- **Team scalability** so a single contributor owns a slice end-to-end.
- **Velocity** by treating tiny speed bumps as risks before they compound.
- **Risk** is interface drift, hidden dependencies, and unverifiable behavior.

## 2. Finish code by finishing interfaces

You finish when the interface is stable. Contracts—schemas, invariants, capability rules—are the product. Implementations come and go.

## 3. Modules as black boxes

Explain the boundary: documented interface, replaceable implementation. Anigma’s governed cores and runtime contracts live behind those black boxes.

## 4. Wrap what you don’t own

Foreign APIs are risks. Wrap them and expose your own abstractions so dependency tentacles can’t creep into Harmonia/AnigmaCore.

## 5. Pick the primitive

Pick the actual object you manipulate: jobs, traces, ledgers, artifacts. If the primitive is wrong you get special cases; if it’s right you get reuse.

## 6. Structure vs semantics

Structure (JSON, NDJSON, pipes) needs semantics (“runId,” “capability required,” “output derived from those inputs”). Keep structures small but semantically rich.

## 7. Core that owns truth

Harmonia enforces invariants: stable runId, declared inputs/outputs, declared capabilities, hashed outputs, replayable traces, admin-controlled retention, provenance emitted for every execution. That’s governance becoming physics.

## 8. Plugins as capability declarations

Job components and tool runtimes declare inputs, outputs, params, required capabilities. UI and orchestrators derive from those descriptors instead of bespoke glue.

## 9. Tooling enables parallel work

Build minimal runners, recorders, replayers, log viewers, simulators. Tools keep integration debuggable before the full product exists.

## 10. Docs become governance when executable

Docs that describe are art. Docs that show evidence and fail CI are governance. Every claim needs artifact paths, runnable commands, invariants, and a “last verified” stamp. Status docs become audit surfaces.

## 11. Burn notice: multi-platform and ML scale because the contract is stable

With the contract fixed you can swap UIs, inference backends, storage engines, and deployments. All share the same schema, invariants, and evidence trail.

## 12. Close

Repeat the thesis: format design is the real software, black boxes keep teams sane, tooling enables parallel work, docs become governance when verifiable.

**If it can’t be replayed from artifacts, it didn’t happen.**
