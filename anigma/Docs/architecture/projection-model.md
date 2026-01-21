# Projection Model

A **projection** is any view or artifact derived from the Document Truth Model (DTM) plus current policy state. Projections may be cached, but they must be reproducible deterministic functions over their inputs. That prevents the “Speckle-style fog” where the data hub exists but the transforms cannot be replayed.

## What counts as a projection

- UI screens (inspector panels, remediation workspaces, governance dashboards).
- Export artifacts (tagged PDFs, large-print outlines, cleaned DIFFs).
- Indexes or feeds (search indexes, job timelines, log streams).
- Automation outputs (notifications, summaries, timeline snapshots).

Each projection is defined by:

1. Input DTM version(s) (hash/sequence).
2. Policy state (mode, trust level, capability gates).
3. Projection definition (name, parameters, layout intent).
4. Action outputs if it triggered downstream work.

## Determinism and caching

- The projection definition is a pure function over `DTM × policy`. It may cache results, but the cache must be invalidated when the DTM version or relevant policy state changes.
- Tests verify that replaying the same DTM version + policy state yields the same projection payload (schema, export bytes, etc.). That’s how you guarantee reproducibility and avoid one-off cloud jobs nobody can rerun.
- The docs include a single worked example: “Highlighted remediation view for page `P-2023-ocr`” states its input hashes, the layout schema, and how policy gating changed when trust mode toggled.

## Projection round-trip

- The engine emits events describing the projection request, the DTM versions used, policy decisions, and the rendered schema snapshot.
- Renderers subscribe, cache the schema, render nodes, and submit capability-gated actions back to the engine.
- If the projection triggered a new job (e.g., remediation edit), the resulting DTM delta references the projection request in its provenance.

Working fixtures: store one JSON representing the remediation UI schema plus its input DTM metadata in `Docs/fixtures/projections/remediation-ui-schema.json`. CI compares generated projection payloads to that golden file whenever schema or projection logic changes.
