# ADR-0003: No Python or Node at Runtime

> **Status:** Accepted  
> **Date:** 2025-12-06  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

The legacy repositories contain Python code and occasionally use Node tools:

- **Outlineum**: Full Python backend (`backend/outlineum/`)
- **Harmonia**: Some Python scripts for ML experiments
- **AltMedia**: Python OCR pipelines, Tesseract wrappers
- **Various**: Node-based tooling in lab environments

For institutional deployment (colleges, accessibility services), we face constraints:
- IT departments resist installing Python/Node runtimes
- Version management across machines is complex
- Security review for interpreted languages is harder
- Maintenance burden increases with multiple runtimes

---

## Decision

**The Anigma repository must not contain Python source files or require Python/Node.js at runtime.**

### Prohibited

| Item | Prohibition |
|------|-------------|
| Python source files (`.py`) | Not allowed in repo |
| Python runtime dependency | Not allowed on deployed machines |
| Node.js runtime requirement | Not allowed on deployed machines |
| Shelling out to Python/Node | Not allowed in production code |
| AGPL/GPL dependencies | Not allowed (license incompatibility) |

### Permitted

| Item | Condition |
|------|-----------|
| Swift source code | Primary language |
| System frameworks | Foundation, CoreImage, Vision, etc. |
| Permissively-licensed C/C++ | Where necessary |
| MLX/MLXNN | For on-device ML |
| JS/TS for UI builds | Build-time only, outputs static assets |

### JavaScript Exception

JS/TS is allowed **only** for:
1. Build-time projects that output static HTML/CSS/JS
2. Prebuilt static assets committed as resources

Examples:
- Monaco editor bundle for Ergasterion (built separately, bundled into app)
- React admin dashboard (npm build → static files → served by daemon)

**Node is never required on deployed machines.**

---

## Rationale

### Why No Python?

1. **Deployment simplicity**: One runtime (Swift) to install and maintain
2. **Institutional acceptance**: IT departments prefer compiled binaries
3. **Performance**: No interpreter startup overhead
4. **Security**: Compiled code is easier to audit and sign

### Why No Node at Runtime?

Same reasons, plus:
- Electron-style apps are heavy and hard to secure
- Static web assets achieve same goals without runtime

### Why Allow Build-Time JS?

- Web UIs are legitimately easier with modern JS frameworks
- Monaco editor is the best code editing component
- Static output means no runtime dependency

### Alternatives Considered

1. **Embed Python interpreter**: Rejected (complexity, size, security)
2. **Use PyInstaller bundles**: Rejected (still runtime dependency)
3. **Skip web UIs entirely**: Rejected (dashboards are valuable)
4. **Use Tauri/Electron**: Rejected (runtime complexity)

---

## Consequences

### Positive

- Single runtime simplifies deployment
- Institutions can deploy with standard macOS tooling
- No Python version conflicts
- Easier security auditing

### Negative

- Must reimplement Python algorithms in Swift
- Lose some Python ML ecosystem (mitigated by MLX)
- Build process for web assets adds complexity

### Neutral

- Different skill set required (Swift vs. Python)

---

## Migration

### From Python Outlineum Backend

| Python | Swift Replacement |
|--------|-------------------|
| ImageMagick via shell | CoreImage |
| Potrace via shell | CoreGraphics or optional external binary |
| FastAPI | Swift daemon with Vapor or raw HTTP |
| Python ECS | AnigmaCore ECS |

### From Python ML Pipelines

| Python | Swift Replacement |
|--------|-------------------|
| PyTorch | MLX |
| Transformers | MLX-native models |
| Tesseract | Apple Vision |
| PDF parsing | PDFKit + custom parsers |

### Lab Code Policy

Legacy Python code can remain in lab repos for:
- Behavioral reference
- Test case generation
- Algorithm documentation

But production implementations must be Swift.

---

## References

- Constitution: `Docs/AnigmaConstitution.md` Section 3
- Implementation rules: `Docs/ImplementationRules.md`
- Web assets: `web-assets/README.md`
