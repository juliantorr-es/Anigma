# AGENT CONTRACT

## Two-Tier Architecture: Core Governance + Capability Modules

Anigma follows a **layered governance model** with strict separation between:

1. **Core Governance Layer** - Production-hardened, court-safe substrate with minimal dependencies
2. **Capability Modules** - Feature-rich ecosystem modules that plug into Core via contracts

---

## CORE GOVERNANCE LAYER (Non-Negotiable)

### Harmonia is the only governance/runtime surface

When you need governance state, trust state, security events, or any automation output:

**Primary CLI Operations:**
- Run Harmonia CLI via the deterministic wrapper: `Scripts/harmonia.sh <subcommand> [args...]`.
- Available subcommands: `swift6`, `security`, `trust`

**Surface Testing Operations:**
- Run Harmonia Surface for slot/session/request testing: `Scripts/harmonia-surface.sh [args...]`.
- Use for concurrency testing, system validation, and telemetry collection

**Critical Rules:**
- Do NOT run `swift build`, `swift test`, `swift run`, `xcodebuild`, or any `./.build/.../harmonia*` path directly.
- Do NOT invoke `.tools/bin/harmonia*` from scripts; always use the wrapper scripts.
- Automation consumes stdout only (a single JSON envelope). Keep diagnostics on stderr.

### Production-Grade Court-Safe ML Worker Integration

The Core layer provides a **cryptographically auditable governed subsystem** that produces Accessum artifacts with hardware-backed authenticity and court-safe provenance.

#### Production Security Requirements

- **Hardware-backed signing**: All evidence heads signed with Secure Enclave/TPM keys
- **Trusted timestamping**: External RFC3161 TSA verification for legal timestamps
- **Canonical serialization**: Cross-platform deterministic byte signing
- **Key custody management**: Hardware-protected private keys with rotation/revocation
- **Offline verification**: Evidence bundles verifiable without trusting Anigma infrastructure

#### Evidence Generation Commands

**"Why Did You Say That?" Receipt Generation**:
```bash
# Generate legal-grade receipt for any query
anigma-receipt explain --agent-id "agent-123" --legal-grade --format pdf

# Create court-ready evidence bundle
anigma-receipt bundle --type legal_discovery --sign --timestamp

# Air-gapped verification by hostile auditors
anigma-verify ./evidence-bundle-20241213/ \
    --strict \
    --trust-anchors ./auditor-certs/ \
    --revocation-list ./revoked-keys.txt \
    --format html \
    --output verification-report.html
```

#### Core Integration Requirements

- **ML worker produces court-safe artifacts**: All embeddings and chat completions become ledger entries with hardware-backed provenance
- **Use existing Accessum integration**: ML operations follow runId/ml/stepId/ structure automatically
- **Preserve production security boundaries**: Raw logs captured separately, hardware signatures and timestamps attached
- **Document backend configuration**: Record which models and binaries are used for governance
- **Test with mock mode**: Use `ML_WORKER_MOCK_MODE=true` for development without security requirements
- **Generate receipts on demand**: Use `anigma-receipt` for instant evidence generation
- **Support offline verification**: Ensure all verification data is bundled for air-gapped validation

---

## CAPABILITY MODULES LAYER (Feature-Rich Ecosystem)

### Architectural Reuse Requirements

When implementing new behavior in Capability Modules, **reuse existing abstractions before adding new ones**:

- For ECS logic, prefer existing `Component`, `System`, `World`, and `Scheduler` patterns from `AnigmaCore` and `HarmoniaModule`.
- For memory, prefer `TriMemory`, `HarmoniaMemory`, and existing SQLite stores over introducing new persistence layers.
- For tools and orchestration, extend `ToolDescriptor`, `ToolRegistry`, `FileToolRuntime`, `GitToolRuntime`, `ShellToolRuntime`, and `ToolOrchestrator` instead of creating parallel runtimes or registries.
- For CLI behavior, prefer extending existing Harmonia CLI commands and subcommands before creating new binaries or ad-hoc scripts.
- Use `Scripts/harmonia.sh` for CLI operations and `Scripts/harmonia-surface.sh` for surface testing.

### Required "Search Before Create" Workflow

Before adding a new module, type, or subsystem:

1. Search the codebase (via opencode tools or CLI) for related names and responsibilities:
   - Similar components/systems in `Sources/*/Components` and `Sources/*/Systems`.
   - Existing services, memory stores, or orchestrators for the same concern.
2. If an existing abstraction can be reused or extended without breaking design constraints, do that instead of creating a sibling.
3. If you still introduce something new, **document in the PR / commit message** which existing options were evaluated and why they were rejected.

### Core Abstraction Map

- **ECS core**: `World`, `EntityId`, `Component`, `System`, `Scheduler`
- **Memory**: `TriMemoryArchitecture`, `HarmoniaMemory`, SQLite-backed stores
- **Tools**: `ToolDescriptor`, `ToolRegistry`, `FileToolRuntime`, `GitToolRuntime`, `ShellToolRuntime`, `ToolOrchestrator`
- **Governance**: Themis / policy engine / CI gates (do not bypass; extend)

Use these by default when building new features. Only introduce new "cores" when genuinely required.

### Agent Pipeline (Conceptual)

Multi-agent flows for Harmonia/Anigma should follow this order:

1. **Architect**: plan and produce structured stub specs; no file writes.
2. **Builder**: implement stubs using existing abstractions and tools; run tests.
3. **Validator**: compare implementation vs. spec; check risks and tests.
4. **Scribe**: update `AGENTS.md`, docs, and `Docs/TechDebt.md` to reflect changes.
5. **Tech-Debt Scout**: periodically scan for duplication, drift, and consolidation work; record items in `Docs/TechDebt.md`.

---


### Inspiration Mining Agent

#### Agent Profile
**Read-heavy, mutation-starved configuration** - Specialized agent for extracting architectural patterns from external repositories while maintaining strict governance boundaries. Cannot make direct code changes or write patches without following the governed toolchain.

#### Protocol Reference
Must follow the [Inspiration Mining Protocol](Docs/governance/Inspiration-Mining-Protocol.md) for all extraction and analysis activities. Protocol compliance is mandatory and enforced through receipt validation.

#### Tool Access
**Allowed Tools (Read-Only):**
- \ - Read files from inspiration repositories and Anigma codebase
- \ - List directory contents for repository structure analysis
- \ - Find files by patterns for systematic scanning
- \ - Search file contents for pattern identification
- \ - Complex search and analysis workflows
- \/\ - Task management for pattern tracking
- \ - Regenerate pattern registry and roadmap (only)

**Forbidden Tools (No Direct Mutation):**
- \, \, \ - Direct file modification tools
- \ - Cannot commit changes directly
- \, \ - Cannot execute builds
- Any tool that modifies repository state without governed patch chain

#### Mandatory Workflow
1. **Protocol Compliance**: Must follow Inspiration Mining Protocol exactly
2. **Pattern Card Creation**: Cannot skip pattern card generation for any identified patterns
3. **ADR Requirements**: Must create ADRs for any patterns requiring boundary changes
4. **Type Authority Check**: Must verify no conflicts with existing type authority
5. **Governance Validation**: All outputs must pass HarmoniaCLI validation

#### Escalation Path
When ready to adopt patterns:
1. Hand off to Builder agent through governed toolchain
2. Use \ to generate structured patch
3. Create proposal with phase ID and acceptance criteria
4. Builder agent validates and applies patches using receipt chain
5. Integrator agent manages final commits through \n
**Critical Constraint**: This agent NEVER writes code directly. It produces structured analysis that other agents implement.

---

### Tool Usage
Agent sessions must rely on the governed toolchain instead of ad-hoc shell commands:

- **anigma-mcp**: PRIORITIZE the 'anigma-mcp' toolset for all codebase investigation, context retrieval, and high-level system analysis. Use 'read_file', 'context_search', 'trace_query', and 'verify_evidence_chain' as primary investigative tools.
- `repo_clean_check`: ensure the branch, working tree, and submodules are clean before generating patches.
- `swiftpm`/`swiftpm_log`: run builds/tests under strict concurrency and summarize diagnostics before advancing.
- `binary_build_preflight`: dry-run the release build for a product before invoking `build_binary`.
- `build_binary`: produce artifacts after a successful preflight, copy them to `Artifacts/bin`, compute SHA256, and optionally codesign.
- `inspiration_patterns`: regenerate the Docs pattern registry/backlog and apply the resulting patch hash via the inspect→apply chain.
- `generate_patch` → `propose_patch` (phaseId + acceptanceRefs required) → `validate_patch` → `apply_patch`: keep the receipt chain intact so the plugin can enforce phase contracts and gates.
- `diagnose_patch_failure`: run this when validation/apply reports a problem; it reads the receipts + stored patch to explain the failure and point you to the right next tool (generate_patch, inspect_repo, etc.).
- `quarantine_patch` / `rollback_last_apply`: recover from failed migrations without resetting the repo.
- `commit_changes`: Integrator-only tool that runs gates, guards forbidden paths, and commits when receipts/gates are green.

Always attach the phase ID and acceptance criteria in your proposal so the plugin knows what mission the patch serves.

Refer to `agent_tools.md` for the verbatim implementation of every custom tool and for the `nextTool` guidance they emit. The plugin observes `.opencode/ledger/workflow.jsonl`, the phase contracts in `Docs/governance/phases/`, and those receipts, so stay inside the inspect→generate→propose→validate→apply flow even when working in plan mode or when drift tempts you to jump ahead.

## BUILD, LINT, AND TEST COMMANDS

- Add doc comments to public APIs. Note ported code with `// Ported from: X.py`.
- Follow [ImplementationRules.md](Docs/ImplementationRules.md) for ECS, jobs, stubs, testing.
- Add `#warning("STUB: ...")` and `// STUB_TRACK:` comments; update `Docs/TechDebt.md`.
- Keep components domain-specific in `{Module}/Components/`.
- Write tests for components, systems, workflows; run `swift test` before commit.

---

## EMERGENCY SECURITY PROCEDURES

### Key Compromise Response

```bash
# Emergency key revocation
anigma-key revoke --fingerprint "compromised-key-hash" \
    --reason "security_incident" \
    --authorized-by "security_admin" \
    --incident-id "INC-2024-001"

# Generate verification bundle for compromised period
anigma-verify --create-bundle \
    --start-date "2024-12-01" \
    --end-date "2024-12-13" \
    --include-revoked-keys
```

The Core layer maintains the highest governance standards with cryptographic guarantees that survive infrastructure compromise, making ML operations court-admissible and legally defensible, while Capability Modules provide rich functionality without compromising security posture.

## Cross-Module Changes: Three-Pass Governance Pipeline (Required)
Any change that crosses module boundaries or alters a public surface must follow the three-pass pipeline.

### Pass 1 (Contract)
- Add/update a contract artifact in `Docs/governance/contract-artifacts/`.
- Define authority boundary, surface API, concurrency model, stop conditions, acceptance tests, migration plan.

### Pass 2 (Implementation)
- Implement behind the surface inside Capability modules.
- No new public APIs beyond the contract artifact.
- Mutable state must stay actor-isolated.

### Pass 3 (Migration/Hardening)
- Swap call sites to the surface.
- Add adapters only behind the surface.
- Add regression tests and logging/evidence hooks.
- Document quarantine/backstop behavior.

CI enforces presence of a contract artifact for boundary-touching diffs via `scripts/governance/verify_contract_artifacts.sh`.
