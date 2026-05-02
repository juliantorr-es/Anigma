# Public Release Dependency Exclusion Audit

## 1. Executive Verdict
The repository contains a significant number of generated build artifacts, development caches, and local environment-specific binaries. The current Git history is heavily polluted with these artifacts, which are blocking the GitHub public push (100MB+ per-file limit).

**Recommendation:** It is **NOT safe** to publish the current repository state without history excision. We must perform a history-cleaning operation (using `git-filter-repo`) to permanently remove these files before public publication.

---

## 2. Large Artifacts (Category A - Exclude)
These must be purged from history and added to `.gitignore`.

| Path | Size (approx) | Category |
| :--- | :--- | :--- |
| `cscope.out` | 228 MB | A |
| `cscope.po.out` | 318 MB | A |
| `anigma/.build/` | Multiple GBs | A |
| `anigma/.build-check/` | Large | A |
| `anigma/.venv_tools/` | 200 MB+ | A |

---

## 3. Vendored Binaries (Category B - Exclude/Document)
These binaries are currently vendored in `anigma/Vendor/lib/`. They need to be reviewed for redistribution licenses. If redistribution is not clearly permitted, these should be moved to a document-based setup instruction.

| Path | License Risk | Action |
| :--- | :--- | :--- |
| `anigma/Vendor/lib/libpdfium.dylib` | Unknown | Investigate/Exclude |
| `anigma/Vendor/lib/libav*.dylib` | Unknown | Investigate/Exclude |

---

## 4. Must-Exclude Paths (Filter List)
The following paths will be fed to `git filter-repo` to excise them from the full commit history:
- `cscope.out`
- `cscope.po.out`
- `anigma/.build/`
- `anigma/.build-check/`
- `anigma/.venv_tools/`
- `anigma/Vendor/lib/` (after determining provenance)
- `anigma/installer/*.dmg`
- `anigma/installer/*.pkg`

---

## 5. Recommended .gitignore Additions
```gitignore
# Build Artifacts
.build/
.build-check/
.venv_tools/
DerivedData/

# Cscope
cscope.out
cscope.po.out

# Binaries/Packages
*.dylib
*.dmg
*.pkg
*.app

# Archive Files
*.zip
*.tar
*.gz
*.tgz
```

---

## 6. Proposed Cleanup Command (Do Not Execute Yet)
`git filter-repo --path cscope.out --path cscope.po.out --path anigma/.build/ --path anigma/.build-check/ --path anigma/.venv_tools/ --invert-paths`

---

## 7. Manual Review Items
1. **Redistribution Rights**: Determine if the FFmpeg (`libav*`) and PDFium binaries in `anigma/Vendor/lib/` have commercial redistribution licenses compatible with an open-source project.
2. **Provenance**: Document the source of these binaries. If they were manually built/downloaded, switch to an automated dependency management tool (e.g., Homebrew, SwiftPM binary target).
