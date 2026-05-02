# Module Graduation Policy

> **Status**: APPROVED  
> **Date**: 2025-12-31  
> **Scope**: Requirements for graduating experimental features to production modules

---

## Overview

Experimental features in `HarmoniaModuleExperimental` must meet graduation criteria before moving to production modules like `HarmoniaModule`.

## Graduation Criteria

### Required (All Must Pass)

1. **Stability**: Feature has been in experimental for at least 2 release cycles
2. **Test Coverage**: Unit tests covering happy path and error cases
3. **Documentation**: API documentation and usage examples exist
4. **No STUB_TRACK**: Feature contains no STUB_TRACK or TODO markers for core functionality
5. **Build Clean**: Feature builds without warnings when isolated

### Recommended

- Integration tests with production modules
- Performance benchmarks
- Security review for sensitive features (Security/ subdirectory)

## Graduation Statuses

Use these tags at the top of experimental files:

```swift
// GRADUATION: ready - Meets all criteria, ready for promotion
// GRADUATION: research - Not intended for production, research/exploration only
// GRADUATION: deprecated - Should be deleted or replaced
// GRADUATION: blocked - Criteria not met, see TODO
```

## Current Inventory

| Subdirectory | Files | Status | Notes |
|-------------|-------|--------|-------|
| Inspiration/ | 9 | research | AST fingerprinting incomplete per ScoutRegistry TODO |
| Research/ | 11 | research | Experimental research features |
| Security/ | 19 | blocked | Needs security review before promotion |

## Process

1. Developer adds `// GRADUATION: ready` tag to file
2. Create PR moving file to target module
3. Reviewer verifies graduation criteria
4. Merge with appropriate commit message referencing this policy

## Non-Graduating Features

Features tagged `// GRADUATION: research` are explicitly not intended for production. They may:
- Explore alternative approaches
- Prototype future capabilities  
- Support internal tooling

These features may be used by internal tooling but should not be depended on by production modules.
