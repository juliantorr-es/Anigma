# Dependency Boundary Notes

Dependency hygiene in Anigma is a discipline, not a one-time purge. The goal is to treat every external integration as an **engine** (the thing doing the work) behind an **adapter** (your owned boundary), then swap implementations in place without the rest of the codebase knowing anything changed.

## 1. Boundary modules for capability classes

- Group third-party duties (CLI parsing, DB access, regex/data packs, doc parsing, audio I/O, etc.) into capability classes.
- Build a single boundary module per capability; provide a stable internal API that harmonia/Accessum/AnigmaCore talk to.
- Keep the boundary module as the only place that couples to the dependency, so replacing that dependency touches only one module.

## 2. Anti-Corruption Layers + the Strangler Pattern

- Define translation/adapter code (an Anti-Corruption Layer) that keeps outside semantics from leaking into the core model.
- Behind that layer, write conformance tests that describe the capabilities you rely on today and the ones you might need soon.
- Start with the third-party dependency fulfilling the boundary API so the tests pass, then swap in native implementations one capability at a time.
- The Strangler pattern lets you grow the native implementation until the dependency becomes optional, while the same tests keep asserting the same behavior.

## 3. Replace dependency addiction with measurable capability

- Never reverse engineer a random dependency feature because it is “cool.” Reverse engineer the capability you can name, cite, and test.
- The test suite becomes your proof-of-capability; the third-party dependency simply plays the role of a reference implementation under the boundary.
- Once native code matches the tests, you can retire the dependency without a costly rewrite, because the behavior contract is already recorded.

## 4. Weight isolation

- Keep heavy stacks (ML, audio, etc.) out-of-process whenever practical; the worker/subprocess model already does this for MLX.
- In-process, pin dependencies to the smallest scope that still makes sense (one CLI target or one boundary module) rather than importing them into AnigmaCore just because it was easy at the time.
- Optional capabilities stay optional; version control, restart, and kill of subprocesses keep Harmonia lightweight.
