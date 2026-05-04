# [FOLLOW-UP] Architecture Operations Capability Implementation

**Document ID:** TD-FOLLOWUP-AOC-2025-001
**Parent:** Architecture Operations Capability Roadmap
**Status:** FUTURE - Blocked until anigma-app Debug builds reliably
**Priority:** P2
**Kind:** followup
**Risk:** medium

---

## Summary

This follow-up task tracks the eventual implementation of the `ArchitectureOperationsCapability` as described in the roadmap document at `Docs/roadmap/future-capabilities/architecture-operations-capability.md`.

**This is not implementation-ready.** The task is explicitly blocked by the prerequisite that `anigma-app` Debug builds reliably.

---

## Prerequisite Gate

**BLOCKER:** Implementation cannot begin until:

```bash
bash Scripts/validate_xcodebuild_debug.sh --scheme anigma-app
```

**Returns exit code 0 consistently.**

---

## What This Task Covers

This task covers the migration of ad hoc operational scripts into a proper, governed Anigma capability. The scope includes:

1. **Evidence Indexing** - Building and maintaining indexes of tasks, proofs, reports, relationships, and diagrams
2. **Validation Lanes** - Running xcodebuild Debug, tier boundary, cycle detection, and exported import validation
3. **Documentation Rendering** - Converting JSON evidence to Markdown and other presentation formats
4. **Diagram Generation** - Creating and managing Mermaid/DOT/SVG artifacts
5. **Publishing** - Syncing artifacts to Notion, Obsidian, static sites, or local filesystem
6. **Integration Auth** - Managing provider authentication (internal tokens first, OAuth later)
7. **Agent Context** - Providing machine-readable project state for local coding agents

---

## What This Task Does NOT Cover

**Non-goals (explicit):**

- [ ] Implementing OAuth before Phase 4
- [ ] Making Notion the canonical source of truth
- [ ] Requiring external AI agents for local validation
- [ ] Requiring MCP for local operation
- [ ] Exposing raw private cockpit data as public docs
- [ ] Replacing Git as source of truth
- [ ] Migrating scripts into runtime before the prerequisite gate passes
- [ ] Creating fake modules with stubs to claim progress

---

## Current State

### Existing Scripts and Artifacts (Do Not Touch Yet)

The following scripts and artifacts exist and work in their current form. They are **not to be modified** until implementation begins:

| Category | Script/Artifact | Path | Status |
|---|---|---|---|
| Validation | xcodebuild Debug validation | `Scripts/validate_xcodebuild_debug.sh` | ✅ Working |
| Validation | Tier boundary validator | `tools/governance/scripts/validate_tiers.py` | ✅ Working |
| Validation | Cycle detector | `tools/governance/scripts/validate_no_cycles.py` | ✅ Working |
| Validation | Exported import validator | `tools/governance/scripts/validate_exported_imports.py` | ✅ Working |
| Validation | Package graph auditor | `Scripts/anigma_package_graph_audit.py` | ✅ Working |
| Indexing | Task index | `Docs/td/index/tasks.jsonl` | ✅ Working |
| Indexing | Proof index | `Docs/td/index/proofs.jsonl` | ✅ Working |
| Indexing | Report index | `Docs/td/index/reports.jsonl` | ✅ Working |
| Indexing | Relationship index | `Docs/td/index/relationships.jsonl` | ✅ Working |
| Indexing | Diagram index | `Docs/td/index/diagrams.jsonl` | ✅ Working |
| Rendering | Artifact renderer | `Scripts/anigma_artifact_render.py` | ✅ Working |
| Rendering | TD bootstrap | `Scripts/td_bootstrap_from_docs.py` | ✅ Working |
| Publishing | Notion client | `Scripts/notion/client.py` | ✅ Working |
| Publishing | Notion publisher v2 | `Scripts/anigma_publish_notion_v2.py` | ✅ Working |
| Publishing | Publishing doctrine | `Docs/publishing/notion.md` | ✅ Working |
| Diagrams | Module relationships | `Docs/diagrams/generated/module-relationships.mmd` | ✅ Working |

### Proof Artifacts (Reference)

The following proof artifacts serve as examples and requirements for the future capability:

| Proof | Path | Relevance |
|---|---|---|
| xcodebuild validation | `Docs/proofs/td-xcodebuild-debug-validation-lane.md` | Validation lane pattern |
| Tier violation resolution | `Docs/proofs/td-8f2e57-decouple-anigmapipeline-mediacore.md` | Architecture fix pattern |
| SecurityEventsManager fix | `Docs/proofs/td-securityeventsmanager-databasecore-tier-violation.md` | Tier boundary pattern |
| Notion sync | `Docs/proofs/notion-current-documentation-cockpit-sync.md` | Publishing pattern |

---

## Implementation Phases

Implementation follows the **Migration Plan** defined in the roadmap document. The phases are:

### Phase 0: Stabilize Current Scripts (Prerequisite)

All scripts must work reliably before any migration begins. This phase is the **gate** for all subsequent work.

**Checklist:**
- [ ] `Scripts/validate_xcodebuild_debug.sh --scheme anigma-app` passes
- [ ] All Python validators pass
- [ ] Notion schema bootstrap is stable and idempotent
- [ ] Publisher produces consistent results on double-run
- [ ] All JSONL indexes are valid and up-to-date

### Phase 1: Define Contracts

Define portable contracts for all capability boundaries.

**Deliverables:**
- `ArchitectureOperationsContracts` module
- `EvidenceIndexContracts` module
- `ValidationLaneContracts` module
- `DocumentationPublishingContracts` module
- `DiagramContracts` module
- `IntegrationAuthContracts` module
- `AgentContextContracts` module

### Phase 2: Port Deterministic Logic

Migrate deterministic, non-side-effecting logic first.

**Deliverables:**
- JSONL indexer
- Hash/stale detection
- Mermaid/DOT generation
- Evidence to Markdown rendering
- Unit tests

### Phase 3: Port Validation Orchestration

Migrate validation orchestration to native code.

**Deliverables:**
- xcodebuild wrapper
- SwiftPM describe + graph validator wrapper
- Normalized validation receipts
- Failure classification
- Integration tests

### Phase 4: Add Notion Adapter

Implement Notion publishing as governed capability.

**Deliverables:**
- Notion API client behind contracts
- Internal token support
- Schema discovery and bootstrap
- Idempotent upsert operations
- Dry-run and live modes
- Receipt emission

### Phase 5: App UI

Add Cockpit UI to anigma-app.

**Deliverables:**
- Architecture Cockpit dashboard
- Validation lanes panel
- Stale proofs panel
- Relationship graph panel
- Publish plan review UI
- Provider connection status
- Agent context export UI

### Phase 6: OAuth and External Onboarding

Add OAuth and external provider support.

**Deliverables:**
- Notion OAuth 2.0 integration
- macOS Keychain credential storage
- Provider abstraction layer
- Multi-account support
- Connection UI
- MCP server integration (optional)

---

## Acceptance Criteria

This follow-up task is considered **DONE** only when ALL of the following are true:

1. **anigma-app Debug builds** reliably.
2. **Anigma can generate indexes** without shelling out to ad hoc scripts.
3. **Anigma can run validation lanes** and emit receipts.
4. **Anigma can detect stale proofs** by comparing content hashes.
5. **Anigma can produce a publish plan** for Notion.
6. **Anigma can publish to Notion** in dry-run and live modes.
7. **Every mutation has a receipt.**
8. **Local agent context export works** without paid cloud-agent reasoning.
9. **All contracts are stable** and documented.
10. **The app/daemon composes** capabilities at runtime from contract boundaries.

---

## Dependencies

### Blocking Dependencies

1. **anigma-app Debug builds reliably** - Absolute prerequisite.
2. **Existing scripts remain unchanged** - No modifications until implementation begins.
3. ** Roadmap approval** - The roadmap document must be reviewed and accepted.

### Non-Blocking Dependencies

1. **OAuth implementation** - Deferred to Phase 6.
2. **MCP integration** - Deferred to Phase 6, optional.
3. **External provider support** - Deferred to Phase 6.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Prerequisite gate never passes | Medium | High | Focus on making anigma-app Debug build first |
| Contract instability | Medium | Medium | Extensive review before implementation |
| OAuth complexity | Low | Medium | Defer until Phase 6, start with internal tokens |
| MCP scope creep | Low | Medium | Keep MCP as adapter boundary, not core |
| Agents ignore cockpit | Medium | Medium | Make cockpit output more useful than reconstructing state |

---

## Validation

Because this is a follow-up task for future implementation:

**Current validation:**
- [ ] Confirm all referenced scripts exist and are unchanged
- [ ] Confirm all referenced proof artifacts exist
- [ ] Confirm the roadmap document exists and is approved
- [ ] Confirm no production Swift code was changed
- [ ] Confirm anigma-app Debug build status

**Future validation (when implementation begins):**
- [ ] Phase 0 checklist complete
- [ ] Phase 1 contracts compile and are documented
- [ ] Phase 2 deterministic logic works without scripts
- [ ] Phase 3 validation lanes produce receipts
- [ ] Phase 4 publishing works in dry-run and live modes
- [ ] Phase 5 UI integrates with capabilities
- [ ] Phase 6 OAuth and MCP integration complete (optional)

---

## Related Documents

- **Roadmap:** `Docs/roadmap/future-capabilities/architecture-operations-capability.md`
- **Publishing Doctrine:** `Docs/publishing/notion.md`
- **Proof: xcodebuild validation:** `Docs/proofs/td-xcodebuild-debug-validation-lane.md`
- **Proof: tier violation:** `Docs/proofs/td-8f2e57-decouple-anigmapipeline-mediacore.md`
- **Proof: SecurityEventsManager fix:** `Docs/proofs/td-securityeventsmanager-databasecore-tier-violation.md`
- **Proof: Notion sync:** `Docs/proofs/notion-current-documentation-cockpit-sync.md`

---

## Next Actions

1. **Review the roadmap** at `Docs/roadmap/future-capabilities/architecture-operations-capability.md`
2. **Prioritize making anigma-app Debug build** - this unblocks all architecture capability work
3. **Do not start implementation** until the prerequisite gate passes
4. **Maintain existing scripts** in their current working state

---

## Document History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | Anigma Architecture | Initial follow-up creation |
