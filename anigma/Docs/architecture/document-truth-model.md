# Document Truth Model

Anigma treats documents like BIM treats buildings: one canonical model, many derived views. The **Document Truth Model (DTM)** is the canonical representation of pages, text structure, semantics, accessibility intent, provenance, and governance state. Everything else—UI screens, exports, reports, indexes—is a projection of that model under policy.

## Entities and relationships

- **Pages** are geometry+coordinates with stable identifiers and relationships to artifacts (PDF, image, scan, etc.).
- **Text structure** is a hierarchy (runs → tokens → lines → blocks) annotated with reading order, language metadata, script, and orientation.
- **Objects** (tables, figures, math, forms, annotations) are first-class nodes that may contain child structures and metadata; they are not “special cases.”
- **Derived semantics** (headings, lists, citations, links, footnotes, references) are explicit nodes that can be asserted or revised and traced back to source spans.
- **Accessibility intent** (alt text, heading level, reading order overrides, label associations, remediation decisions) is stored as structured data—not left to the renderer to infer.
- **Provenance + policy** annotations accompany every entity change: who triggered it, which job executed it, what policy gates were evaluated, and which artifacts were consumed/produced.

These objects must remain coherent; if you edit a heading, update its tokens, citations, and provenance rather than mutating silent state elsewhere.

## Versioning and invariants

- The DTM is append-only in meaning. You may refine derived fields, correct metadata, or add annotations, but you cannot rewrite history without recording the transformation (job, inputs, policy decision, timestamp, actor).
- Every DTM artifact carries a version stamp (hash or sequence) and links to the job that last mutated it. That version is usable in deterministic projections and audits.
- DTM invariants are documented as tests: for example, “page geometry must reference a published artifact,” “derived headings have provenance back to at least one token span,” or “accessibility overrides cite a policy exception and recording UI node.”

## Example workflow (scan → DTM → remediation)

1. Input: scanned PDF image. OCR job produces tokenized text plus layout geometry.
2. The engine records a DTM delta: new page object, token hierarchy, derived headings, and accessibility hints inferred from layout (with provenance referencing the OCR job).
3. The remediation job takes the same DTM and adds corrected alt text and annotation nodes, each change tagged with a policy evaluation (was it low-risk correction, was it audited).
4. Every node retains its version path so future projections can reconstruct the exact state the remediation UI displayed.

Working fixtures (small JSON snapshots of DTM fragments) live in `Docs/fixtures/dtm-example.json`. CI can load that fixture, run the canonical validators, and ensure the DTM invariants survive schema or projection changes.
