> **⚠️ SATURATED REVIEW PENDING**  
> This ADR is pending review for compatibility with the **Saturated Autonomous** architecture. Use with caution.

# ADR-0006: Atlasum Visual Atlas Engine

## Status

Accepted

## Date

2024-12-06

## Context

Anigma is a complex platform with multiple modules (AnigmaCore, Harmonia, Diaplasion, Accessum, Outlineum), extensive governance documentation (Constitution, ADRs, Implementation Rules), and evolving architecture. Navigating this through text documents alone is challenging, especially for:

- **Visual learners** who benefit from spatial representation of concepts
- **New contributors** trying to understand the platform structure
- **Stakeholders** who need a quick overview without reading all docs
- **iPad users** who want to explore the architecture interactively

We needed a visualization layer that:
1. Presents the platform structure as an interactive mind map
2. Works on touch devices (iPad) with pinch-zoom and tap navigation
3. Links to actual documentation for deeper exploration
4. Can later be embedded into Ergasterion via WKWebView
5. Respects Anigma's constraints (no runtime dependencies, no AGPL)

## Decision

We introduce **Atlasum** as the visual atlas engine for Anigma:

### Naming
- **Atlasum**: Internal engine name (Latin-ish, consistent with Anigma naming)
- **Anigma Atlas**: User-facing product name

### Architecture

```
Docs/Atlas/
├── anigma-atlas.md      # Source: Markmap-compatible Markdown
└── anigma-atlas.html    # Output: Self-contained interactive HTML

Tools/AtlasumWeb/
├── package.json         # Build-time dependencies
├── tsconfig.json        # TypeScript config
└── src/
    └── buildAtlas.ts    # Build script
```

### Key Design Choices

1. **Markdown as source**: The atlas is defined in `anigma-atlas.md` using nested headings and lists. This keeps the source human-readable, version-controllable, and editable without special tools.

2. **Markmap for rendering**: We use the Markmap library (MIT licensed) which transforms Markdown into interactive SVG mind maps with pan, zoom, and collapse/expand.

3. **Build-time only**: Node.js and npm are required only at build time to generate the static HTML. The output is a self-contained HTML file that requires no server or runtime.

4. **Ergasterion integration hooks**: The generated HTML includes a JavaScript hook (`window.anigmaAtlasNodeClicked`) that Ergasterion can intercept via `WKWebView` message handlers. This enables future integration where clicking a node in the Atlas navigates to the relevant section in the IDE.

5. **Accessibility features**:
   - ARIA roles (`role="tree"`, `role="main"`)
   - Keyboard navigation (+/−/0 for zoom, Ctrl+E/C for expand/collapse)
   - Skip link for screen readers
   - High contrast mode support via `prefers-contrast: high`
   - Light/dark mode via `prefers-color-scheme`

### What Atlasum Is NOT

- **Not a source of truth**: Atlas is a derived view of the documentation. The Constitution, ADRs, and READMEs remain authoritative.
- **Not a runtime dependency**: It's a visualization tool built at development time.
- **Not a replacement for reading docs**: It's a navigation aid, not a substitute for understanding the actual content.

## Consequences

### Positive

- Visual learners can explore Anigma's structure spatially
- Quick onboarding: new contributors get the big picture in seconds
- Documentation stays linked: every Atlas node can point to source docs
- Future-proof: can be embedded in Ergasterion when ready
- Respects constraints: no Python, no Node in production, MIT-licensed deps

### Negative

- Requires manual maintenance: when modules or docs change, the atlas source must be updated
- Another build step: developers need to run `./Scripts/build_atlas.sh` to regenerate

### Mitigations

- Added atlas maintenance rules to `Docs/ImplementationRules.md`
- Build script is simple and fast (< 5 seconds)
- Atlas source is just Markdown, easy to edit

## Implementation

Files created:
- `Docs/Atlas/anigma-atlas.md` – Atlas source
- `Docs/Atlas/anigma-atlas.html` – Generated output (after build)
- `Tools/AtlasumWeb/` – Build tool
- `Scripts/build_atlas.sh` – Build script

To regenerate the atlas:
```bash
./Scripts/build_atlas.sh
```

## Future Evolution

1. **Auto-generation**: Extract module/component/system structure from Swift source and generate atlas nodes automatically
2. **Multiple views**: Different atlas files for different audiences (developer view, stakeholder view, accessibility view)
3. **Ergasterion embedding**: Load atlas in WKWebView with bidirectional navigation
4. **Graph view**: Add a JSON-based graph view (nodes + edges) for showing dependencies, not just hierarchy

## References

- [Markmap](https://markmap.js.org/) – MIT licensed
- [ADR-0004: Module Boundaries](/ADR/0004-module-boundaries)
- [Anigma Constitution](/AnigmaConstitution)
