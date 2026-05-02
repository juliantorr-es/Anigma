---
title: "Documentation Index"
description: "Complete inventory of all Anigma documentation files with status, owner, and completeness tracking."
audience: ["contributors", "developers", "documentation-team"]
complexity: "intermediate"
estimated_time: "10 minutes"
keywords: ["index", "inventory", "status", "maintenance", "documentation-map"]
prerequisites:
  - "Familiarity with Anigma project"
related_docs:
  - "documentation-style-guide.md"
  - "documentation-ownership.md"
last_updated: "2026-04-15"
status: "stable"
---

# Documentation Index

This document tracks all 227+ Anigma documentation files, their current status, owners, and completeness.

## Quick Statistics

- **Total Files**: 227
- **Complete (stable)**: 18
- **Stub/Draft**: 35
- **Needs Metadata**: 176
- **Target Completion**: 100% by Q3 2026

## Status Legend

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| **stable** | Complete and maintained | Minimal updates needed |
| **beta** | Nearly complete, under review | Final review pending |
| **experimental** | In development | Not ready for use |
| **stub** | Placeholder, content needed | Needs completion |
| **no-metadata** | No frontmatter | Needs metadata addition |
| **deprecated** | Outdated, use alternative | Migrate to new docs |
| **archived** | Historical reference | Rarely updated |

## Directory Structure Overview

Generated: 2026-04-15 22:14:42 UTC

### Main Directories

| Directory | Count | Purpose |
|-----------|-------|----------|
| `architecture/` | 18 files | System design and architecture |
| `archive/` | 18 files | Historical documentation |
| `concepts/` | 11 files | Fundamental concepts and theory |
| `development/` | 13 files | Development and contribution guidelines |
| `examples/` | 2 files | Code samples and implementations |
| `generated/` | 0 files |  |
| `generated_guides/` | 10 files |  |
| `getting-started/` | 11 files | Quick setup and first steps |
| `guides/` | 16 files | How-to guides and tutorials |
| `migrations/` | 9 files | Migration guides for versions |
| `reference/` | 39 files | API and technical reference |
| `releases/` | 3 files | Release notes and versioning |
| `runtime/` | 2 files | Deployment and operations |
| `troubleshooting/` | 8 files | Error solving and FAQs |

---


## ARCHITECTURE Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `architecture > README.md` | ✅ stable | 2026-04-16 | TBD |
| `architecture > capsules.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > database-architecture.md` | 📝 stub | 2026-04-16 | TBD |
| `architecture > harmonia-backend.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > harmonia-cli.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > harmonia-executables.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > harmonia-v2.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > logging.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > metal-compute.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > networking.md` | 📝 stub | 2026-04-16 | TBD |
| `architecture > observability.md` | 📝 stub | 2026-04-16 | TBD |
| `architecture > performance.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > phase3.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > plugin-system.md` | 📝 stub | 2026-04-16 | TBD |
| `architecture > plugins.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > schema.md` | ⚠️ no-metadata | unknown | TBD |
| `architecture > security.md` | 📝 stub | 2026-04-16 | TBD |
| `architecture > stability-gates.md` | ⚠️ no-metadata | unknown | TBD |

## ARCHIVE Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `archive > README.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > migrations > harmonia-phase2.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > tasks > rlm-completion.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > tasks > td-completion.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-2 > analysis.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-2 > docs-index.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-2 > executive.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-3 > bundle-fix.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-3 > checklist.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-3 > completion.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-3 > evidence.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > phase-3 > smoke-test.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > active > completion-report.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > sessions > active > interim-report.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > summaries > final-status.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > handoffs > assistant-analysis.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > reports > analysis-checklist.md` | ⚠️ no-metadata | unknown | TBD |
| `archive > reports > ui-denial-banner.md` | ⚠️ no-metadata | unknown | TBD |

## CONCEPTS Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `concepts > README.md` | ✅ stable | 2026-04-16 | TBD |
| `concepts > architecture.md` | ⚠️ no-metadata | unknown | TBD |
| `concepts > backend.md` | ⚠️ no-metadata | unknown | TBD |
| `concepts > build-status.md` | ⚠️ no-metadata | unknown | TBD |
| `concepts > compilation.md` | ⚠️ no-metadata | unknown | TBD |
| `concepts > components.md` | ⚠️ no-metadata | unknown | TBD |
| `concepts > data-model.md` | 📝 stub | 2026-04-16 | TBD |
| `concepts > design-principles.md` | 📝 stub | 2026-04-16 | TBD |
| `concepts > execution-model.md` | 📝 stub | 2026-04-16 | TBD |
| `concepts > macos-capabilities.md` | ⚠️ no-metadata | unknown | TBD |
| `concepts > modules.md` | 📝 stub | 2026-04-16 | TBD |

## DEVELOPMENT Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `development > README.md` | ✅ stable | 2026-04-16 | TBD |
| `development > ci-cd-pipeline.md` | 📝 stub | 2026-04-16 | TBD |
| `development > code-style-guide.md` | 📝 stub | 2026-04-16 | TBD |
| `development > development-workflow.md` | 📝 stub | 2026-04-16 | TBD |
| `development > documentation-ownership.md` | ✅ stable | 2026-04-15 | TBD |
| `development > documentation-style-guide.md` | ✅ stable | 2026-04-15 | TBD |
| `development > linting.md` | ⚠️ no-metadata | unknown | TBD |
| `development > performance-guidelines.md` | 📝 stub | 2026-04-16 | TBD |
| `development > project-structure.md` | 📝 stub | 2026-04-16 | TBD |
| `development > task-system-design-phase.md` | ✅ stable | 2026-04-16 | TBD |
| `development > task-system-implementation-phase.md` | ✅ stable | 2026-04-16 | TBD |
| `development > task-system-research-phase.md` | ✅ stable | 2026-04-16 | TBD |
| `development > testing-strategy.md` | 📝 stub | 2026-04-16 | TBD |

## EXAMPLES Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `examples > README.md` | ⚠️ no-metadata | unknown | TBD |
| `examples > architecture-diagram.md` | ⚠️ no-metadata | unknown | TBD |

## GENERATED_GUIDES Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `generated_guides > AI_FRAMEWORKS.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > AI_FRAMEWORKS_EXTENDED.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > BUILD_SYSTEMS.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > BUILD_SYSTEMS_EXTENDED.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > DATA_PERSISTENCE.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > DATA_PERSISTENCE_EXTENDED.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > SWIFTPM_FIRST_WORKFLOW.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > SWIFTPM_MULTIPLE_PRODUCERS.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > SWIFT_6_2_AND_INTEROP.md` | ⚠️ no-metadata | unknown | TBD |
| `generated_guides > SWIFT_6_2_AND_INTEROP_EXTENDED.md` | ⚠️ no-metadata | unknown | TBD |

## GETTING STARTED Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `getting-started > README.md` | ✅ stable | 2026-04-16 | TBD |
| `getting-started > faq.md` | 📝 stub | 2026-04-16 | TBD |
| `getting-started > final-setup.md` | ⚠️ no-metadata | unknown | TBD |
| `getting-started > first-project.md` | 📝 stub | 2026-04-16 | TBD |
| `getting-started > installation.md` | 📝 stub | 2026-04-16 | TBD |
| `getting-started > local-setup.md` | ⚠️ no-metadata | unknown | TBD |
| `getting-started > mcp-installation.md` | ⚠️ no-metadata | unknown | TBD |
| `getting-started > mcp-status.md` | ⚠️ no-metadata | unknown | TBD |
| `getting-started > project-structure.md` | ✅ stable | 2026-04-16 | TBD |
| `getting-started > quick-start-commands.md` | 📝 stub | 2026-04-16 | TBD |
| `getting-started > quick-start.md` | ⚠️ no-metadata | unknown | TBD |

## GUIDES Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `guides > CONTRIBUTING.md` | ✅ stable | 2026-04-16 | TBD |
| `guides > README.md` | ✅ stable | 2026-04-16 | TBD |
| `guides > build-final.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > build-order.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > building-analysis.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > building-fixes.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > building-summary.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > building.md` | 📝 stub | 2026-04-16 | TBD |
| `guides > cli-view.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > compilation-audit.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > compilation-fixes.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > debugging.md` | 📝 stub | 2026-04-16 | TBD |
| `guides > implementing-features.md` | 📝 stub | 2026-04-16 | TBD |
| `guides > performance.md` | ⚠️ no-metadata | unknown | TBD |
| `guides > running-in-production.md` | 📝 stub | 2026-04-16 | TBD |
| `guides > testing.md` | ⚠️ no-metadata | unknown | TBD |

## MIGRATIONS Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `migrations > cli-thin-client > API_REFERENCE.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > FAQ_BEST_PRACTICES.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > INDEX.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > MIGRATION_SUMMARY.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > PERFORMANCE_GUIDE.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > README.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > RELEASE_NOTES.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > TROUBLESHOOTING.md` | ⚠️ no-metadata | unknown | TBD |
| `migrations > cli-thin-client > USER_MIGRATION_GUIDE.md` | ⚠️ no-metadata | unknown | TBD |

## REFERENCE Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `reference > README.md` | ✅ stable | 2026-04-16 | TBD |
| `reference > api-governance-analysis.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > api-governance.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > api.md` | 📝 stub | 2026-04-16 | TBD |
| `reference > command-line.md` | 📝 stub | 2026-04-16 | TBD |
| `reference > configuration.md` | 📝 stub | 2026-04-16 | TBD |
| `reference > data-formats.md` | 📝 stub | 2026-04-16 | TBD |
| `reference > environment-variables.md` | 📝 stub | 2026-04-16 | TBD |
| `reference > fan-out-budgets.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > implementation-status.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > linting.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > module-reference.md` | 📝 stub | 2026-04-16 | TBD |
| `reference > policies.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > requirements.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > security.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > swiftlint-index.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > task-system-reference.md` | ✅ stable | 2026-04-16 | TBD |
| `reference > type-audits-current.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > type-audits.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > guardrails.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > hardening.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > implementation.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > inventory-audit.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > inventory-complete.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > inventory-quick-ref.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > quick-ref-card.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > remediation.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > stubs > visibility-audit.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > audits > anycodable.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > audits > binary-consolidation.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > audits > calm-surface.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > audits > canonicalization.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > audits > capsule-batching.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > governance > authority-boundaries.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > governance > refactor-index.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > governance > refactor.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > governance > violations-complete.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > governance > violations-implementation.md` | ⚠️ no-metadata | unknown | TBD |
| `reference > governance > violations-refactor.md` | ⚠️ no-metadata | unknown | TBD |

## RELEASES Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `releases > README.md` | ✅ stable | 2026-04-16 | TBD |
| `releases > changelog.md` | 📝 stub | 2026-04-16 | TBD |
| `releases > roadmap.md` | 📝 stub | 2026-04-16 | TBD |

## RUNTIME Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `runtime > DeterminismEnvelope.md` | ⚠️ no-metadata | unknown | TBD |
| `runtime > KernelABIContract.md` | ⚠️ no-metadata | unknown | TBD |

## TROUBLESHOOTING Directory

| File | Status | Updated | Owner |
|------|--------|---------|-------|
| `troubleshooting > README.md` | ✅ stable | 2026-04-16 | TBD |
| `troubleshooting > build-issues.md` | 📝 stub | 2026-04-16 | TBD |
| `troubleshooting > compilation-session.md` | ⚠️ no-metadata | unknown | TBD |
| `troubleshooting > compilation.md` | ⚠️ no-metadata | unknown | TBD |
| `troubleshooting > error-reference.md` | 📝 stub | 2026-04-16 | TBD |
| `troubleshooting > mlx-compilation.md` | ⚠️ no-metadata | unknown | TBD |
| `troubleshooting > performance-issues.md` | 📝 stub | 2026-04-16 | TBD |
| `troubleshooting > runtime-issues.md` | 📝 stub | 2026-04-16 | TBD |

---

## Maintenance Guidelines

### For Documentation Owners

1. **Review Status**: Regularly review your section's status
2. **Update Metadata**: Ensure all required fields are present
3. **Track Updates**: Update `last_updated` when making changes
4. **Monitor Quality**: Check links and examples still work
5. **Plan Improvements**: Use `stub` status to track needed work

### Current Priorities (Q2 2026)

1. Add frontmatter to all 176 no-metadata files
2. Complete 35 stub files with full content
3. Review all beta files for final approval
4. Establish ownership for each section
5. Implement automated validation

### Milestone Targets

| Milestone | Date | Target |
|-----------|------|--------|
| **Metadata Complete** | April 30, 2026 | 100% files have frontmatter |
| **Stubs Filled** | May 31, 2026 | All stubs → stable/beta |
| **Full Review** | June 30, 2026 | 100% files reviewed by owner |
| **Maintenance Ready** | July 1, 2026 | Workflows fully operational |

---

## How to Use This Index

### For Contributors

1. Find the file you want to update in this index
2. Check its current status
3. If `stub`, review what's needed and contribute
4. If `stable`, ensure changes maintain quality
5. Submit PR through normal process

### For Owners

1. Find your section in this index
2. Count total files and completion percentage
3. Identify files needing updates (check `last_updated` date)
4. Plan maintenance schedule based on status
5. Report progress monthly to documentation team

### For CI/CD

1. This index is auto-generated weekly
2. Updates reflect current file metadata
3. Use as source of truth for documentation health
4. Track metrics against targets above

---

## Next Steps

- [ ] Review your section's status
- [ ] Add/update frontmatter for priority files
- [ ] Create issues for stub files needing content
- [ ] Schedule regular maintenance reviews
- [ ] Contribute to improving documentation quality

---

**Status**: Stable
**Last Generated**: 2026-04-15 22:14:42 UTC
**Total Files Indexed**: 227
**Maintainer**: Documentation Team
