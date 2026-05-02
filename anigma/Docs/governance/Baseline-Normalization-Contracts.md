# Baseline Normalization Contracts

> Last updated: 2025-12-29
> Status: **Active** – CI enforcement in place

---

## Overview

Canonical v3.2 requires explicit normalization contracts per file type to ensure cross-platform reproducibility. Every committed file MUST be in its canonical form; CI gates reject non-canonical bytes.

---

## Normalization Contracts

### JSON Files

**Canonical Form:** JCS (RFC 8785) with sorted keys and no extra whitespace

**Verification Command:**
```bash
jq -c -S .
```

**CI Enforcement:** `Scripts/ci-normalize.sh` checks all JSON files

**Auto-Fix:**
```bash
./Scripts/fix-formatting.sh
```

**Scope:**
- All `.json` files except:
  - `node_modules/` (ignored)
  - `.git/` (ignored)

**Why:** Ensures byte-identical output across platforms and prevents serialization-based attacks.

---

### Swift Files

**Canonical Form:** `swift-format` with locked configuration (`.swift-format.json`)

**Configuration Location:** `.swift-format.json` in repo root

**Key Settings:**
- Indentation: 4 spaces
- Line length: 120 characters
- Import sorting: alphabetical
- Brace style: allman

**Verification Command:**
```bash
swift-format --lint --configuration .swift-format.json
```

**CI Enforcement:** `Scripts/ci-normalize.sh` checks Swift files

**Auto-Fix:**
```bash
swift-format --in-place --configuration .swift-format.json <file>
# Or use the helper:
./Scripts/fix-formatting.sh
```

**Scope:**
- All `.swift` files in `Sources/` and `Tests/`

**Why:** Ensures consistent code style across the project and makes diffs cleaner for review.

---

### Markdown Files

**Canonical Form:** CommonMark with prescribed extensions

**Current Status:** Documentation provided; automatic enforcement pending

**Requirements:**
- 2-space indentation for lists
- Consistent heading hierarchy
- No trailing whitespace
- One blank line between sections

**Verification Pending:** CommonMark normalizer tooling

---

### SQL Files

**Canonical Form:** Consistent spacing and quoting

**Current Status:** Manual enforcement; automated checking planned

**Requirements:**
- Lowercase keywords (SELECT, FROM, WHERE, etc.)
- Consistent indentation (2 spaces)
- Single quotes for string literals
- Semicolon terminator

**Verification Pending:** SQL formatter tooling

---

## CI Gate Workflow

### On Push / Pull Request

The `ci-normalize.sh` script runs as a gate:

1. **Check JSON syntax** – fails if unparseable
2. **Check JSON canonicalization** – fails if keys unsorted
3. **Check Swift format** – fails if `swift-format --lint` fails
4. **Check format config** – fails if `.swift-format.json` invalid or missing

### Failure Handling

If any check fails:
- CI gate blocks merge
- Developer must run `./Scripts/fix-formatting.sh`
- Changes are reviewed and committed
- CI gate re-runs on push

### Auto-Fix Script

`./Scripts/fix-formatting.sh` corrects:
- JSON key sorting
- Swift formatting violations
- (Future) Markdown and SQL normalization

---

## Verification Checklist

**For Auditors (Adversarial Context):**

1. Clone repository
2. Run normalization tools independently:
   ```bash
   jq -S . Docs/governance/Baseline-Normalization-Contracts.md
   swift-format --lint --configuration .swift-format.json Sources/**/*.swift
   ```
3. Confirm output matches committed bytes
4. No changes reported = repository in canonical form

---

## Enforcement Timeline

- **Now:** JSON + Swift normalization with CI gates
- **Q1 2026:** Markdown normalization tooling
- **Q2 2026:** SQL normalization tooling

---

## References

- RFC 8785 (JSON Canonicalization Scheme): https://tools.ietf.org/html/rfc8785
- swift-format: https://github.com/apple/swift-format
- CommonMark: https://spec.commonmark.org/

---

## Questions & Escalation

For normalization-related issues:
1. Run `./Scripts/fix-formatting.sh` first
2. If issues persist, check `.swift-format.json` configuration
3. Report canonical form discrepancies to governance team

---

**This document is binding for all code contributions. Non-canonical files are rejected by CI gates.**
