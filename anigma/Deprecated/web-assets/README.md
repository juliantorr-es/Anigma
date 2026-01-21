# Web Assets

This directory contains JS/TS front-end projects that compile to static assets.

**Key rules:**
- Node/npm used **only at build time**
- Output is static HTML/JS/CSS
- No Node runtime on institutional machines
- All licenses must be clean (MIT, Apache 2.0, BSD)

## Projects

### `ergasterion-monaco/`
Monaco editor bundle for Ergasterion's WKWebView.
- Input: Monaco + minimal wrapper code
- Output: Single HTML + JS bundle embedded in macOS app

### `anigma-dashboard/`
Optional ops dashboard for Anigma control plane.
- React + Tailwind + Headless UI
- React Flow for workflow/DAG visualization
- Recharts for metrics
- Talks to daemon via HTTP/WebSocket

### `dsps-console/`
Optional DSPS staff portal for alt-media review.
- TipTap for rich text editing
- PDF.js for document preview
- OCR correction UI

## Build Pattern

Each project follows:
```
project/
├── package.json      # Build deps only
├── src/              # Source
├── dist/             # Built static assets (gitignored)
└── README.md
```

Build output goes to `dist/`, which is either:
- Copied to Swift app Resources (Ergasterion)
- Served by daemon at `/admin` endpoint (dashboards)

## License Allowlist

Only use libraries with these licenses:
- MIT
- Apache 2.0
- BSD (2/3-clause)
- ISC
- Unlicense / CC0

Avoid:
- GPL/LGPL (copyleft complications)
- Commercial-only
- Anything with unclear terms
