# Inference: Memory + Cache Contracts

Modern local inference isn’t bottlenecked by raw compute anymore—it’s bottlenecked by cache. KV caches make compute scale linearly with context, but every additional token still requires reading and validating large key/value blobs. In Anigma’s deterministic, auditable pipelines, cache behavior is not an implementation detail; it’s an engine contract.

This folder documents that contract: cache artifacts are first-class, provenance-rich objects; memory budgets are policy-driven and logged; reuse gates validate artifact scope, policy, and inputs before anything ever pedals a cached tensor; and backend adapters expose stable formats. The result: predictable performance, deterministic runs, explainable audits, and portable backends.

See the companion files in this directory for the artifact envelope schema, storage layout, reuse gate rules, memory budget policy, backend adapter expectations, governance-aware ModelSpec/RunSpec rules, and the provider landscape that keeps Harmonia’s inference stack portable.
