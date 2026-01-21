# Anigma Workflow Canonical Record

## Source: AGENTS.md

### Two-Tier Architecture
> Anigma follows a **layered governance model** with strict separation between:
> 
> 1. **Core Governance Layer** - Production-hardened, court-safe substrate with minimal dependencies
> 2. **Capability Modules** - Feature-rich ecosystem modules that plug into Core via contracts
> 
> ---
[AGENTS.md:5]

### Core Governance Layer (Non-Negotiable)
> ### Harmonia is the only governance/runtime surface
> 
> When you need governance state, trust state, security events, or any automation output:
> 
> **Primary CLI Operations:**
> - Run Harmonia CLI via the deterministic wrapper: `Scripts/harmonia.sh <subcommand> [args...]`.
> - Available subcommands: `swift6`, `security`, `trust`
> 
> **Surface Testing Operations:**
> - Run Harmonia Surface for slot/session/request testing: `Scripts/harmonia-surface.sh [args...]`.
> - Use for concurrency testing, system validation, and telemetry collection
> 
> **Critical Rules:**
> - Do NOT run `swift build`, `swift test`, `swift run`, `xcodebuild`, or any `./.build/.../harmonia*` path directly.
> - Do NOT invoke `.tools/bin/harmonia*` from scripts; always use the wrapper scripts.
> - Automation consumes stdout only (a single JSON envelope). Keep diagnostics on stderr.
[AGENTS.md:14]

> ### Production-Grade Court-Safe ML Worker Integration
> 
> The Core layer provides a **cryptographically auditable governed subsystem** that produces Accessum artifacts with hardware-backed authenticity and court-safe provenance.
> 
> #### Production Security Requirements
> 
> - **Hardware-backed signing**: All evidence heads signed with Secure Enclave/TPM keys
> - **Trusted timestamping**: External RFC3161 TSA verification for legal timestamps
> - **Canonical serialization**: Cross-platform deterministic byte signing
> - **Key custody management**: Hardware-protected private keys with rotation/revocation
> - **Offline verification**: Evidence bundles verifiable without trusting Anigma infrastructure
> 
> #### Evidence Generation Commands
> 
> **"Why Did You Say That?" Receipt Generation**:
> ```bash
> # Generate legal-grade receipt for any query
> anigma-receipt explain --agent-id "agent-123" --legal-grade --format pdf
> 
> # Create court-ready evidence bundle
> anigma-receipt bundle --type legal_discovery --sign --timestamp
> 
> # Air-gapped verification by hostile auditors
> anigma-verify ./evidence-bundle-20241213/ \
>     --strict \
>     --trust-anchors ./auditor-certs/ \
>     --revocation-list ./revoked-keys.txt \
>     --format html \
>     --output verification-report.html
> ```
> 
> #### Core Integration Requirements
> 
> - **ML worker produces court-safe artifacts**: All embeddings and chat completions become ledger entries with hardware-backed provenance
> - **Use existing Accessum integration**: ML operations follow runId/ml/stepId/ structure automatically
> - **Preserve production security boundaries**: Raw logs captured separately, hardware signatures and timestamps attached
> - **Document backend configuration**: Record which models and binaries are used for governance
> - **Test with mock mode**: Use `ML_WORKER_MOCK_MODE=true` for development without security requirements
> - **Generate receipts on demand**: Use `anigma-receipt` for instant evidence generation
> - **Support offline verification**: Ensure all verification data is bundled for air-gapped validation
[AGENTS.md:31]

### Capability Modules Layer (Feature-Rich Ecosystem)
> ### Architectural Reuse Requirements
> 
> When implementing new behavior in Capability Modules, **reuse existing abstractions before adding new ones**:
> 
> - For ECS logic, prefer existing `Component`, `System`, `World`, and `Scheduler` patterns from `AnigmaCore` and `HarmoniaModule`.
> - For memory, prefer `TriMemory`, `HarmoniaMemory`, and existing SQLite stores over introducing new persistence layers.
> - For tools and orchestration, extend `ToolDescriptor`, `ToolRegistry`, `FileToolRuntime`, `GitToolRuntime`, `ShellToolRuntime`, and `ToolOrchestrator` instead of creating parallel runtimes or registries.
> - For CLI behavior, prefer extending existing Harmonia CLI commands and subcommands before creating new binaries or ad-hoc scripts.
> - Use `Scripts/harmonia.sh` for CLI operations and `Scripts/harmonia-surface.sh` for surface testing.
[AGENTS.md:76]

> ### Required "Search Before Create" Workflow
> 
> Before adding a new module, type, or subsystem:
> 
> 1. Search the codebase (via opencode tools or CLI) for related names and responsibilities:
>    - Similar components/systems in `Sources/*/Components` and `Sources/*/Systems`.
>    - Existing services, memory stores, or orchestrators for the same concern.
> 2. If an existing abstraction can be reused or extended without breaking design constraints, do that instead of creating a sibling.
> 3. If you still introduce something new, **document in the PR / commit message** which existing options were evaluated and why they were rejected.
[AGENTS.md:86]

> ### Core Abstraction Map
> 
> - **ECS core**: `World`, `EntityId`, `Component`, `System`, `Scheduler`
> - **Memory**: `TriMemoryArchitecture`, `HarmoniaMemory`, SQLite-backed stores
> - **Tools**: `ToolDescriptor`, `ToolRegistry`, `FileToolRuntime`, `GitToolRuntime`, `ShellToolRuntime`, `ToolOrchestrator`
> - **Governance**: Themis / policy engine / CI gates (do not bypass; extend)
> 
> Use these by default when building new features. Only introduce new "cores" when genuinely required.
[AGENTS.md:96]

> ### Agent Pipeline (Conceptual)
> 
> Multi-agent flows for Harmonia/Anigma should follow this order:
> 
> 1. **Architect**: plan and produce structured stub specs; no file writes.
> 2. **Builder**: implement stubs using existing abstractions and tools; run tests.
> 3. **Validator**: compare implementation vs. spec; check risks and tests.
> 4. **Scribe**: update `AGENTS.md`, docs, and `Docs/TechDebt.md` to reflect changes.
> 5. **Tech-Debt Scout**: periodically scan for duplication, drift, and consolidation work; record items in `Docs/TechDebt.md`.
[AGENTS.md:105]

> ### Inspiration Mining Agent
> 
> #### Agent Profile
> **Read-heavy, mutation-starved configuration** - Specialized agent for extracting architectural patterns from external repositories while maintaining strict governance boundaries. Cannot make direct code changes or write patches without following the governed toolchain.
> 
> #### Protocol Reference
> Must follow the [Inspiration Mining Protocol](Docs/governance/Inspiration-Mining-Protocol.md) for all extraction and analysis activities. Protocol compliance is mandatory and enforced through receipt validation.
> 
> #### Tool Access
> **Allowed Tools (Read-Only):**
> - \ - Read files from inspiration repositories and Anigma codebase
> - \ - List directory contents for repository structure analysis
> - \ - Find files by patterns for systematic scanning
> - \ - Search file contents for pattern identification
> - \ - Complex search and analysis workflows
> - \/\ - Task management for pattern tracking
> - \ - Regenerate pattern registry and roadmap (only)
> 
> **Forbidden Tools (No Direct Mutation):**
> - \, \, \ - Direct file modification tools
> - \ - Cannot commit changes directly
> - \, \ - Cannot execute builds
> - Any tool that modifies repository state without governed patch chain
> 
> #### Mandatory Workflow
> 1. **Protocol Compliance**: Must follow Inspiration Mining Protocol exactly
> 2. **Pattern Card Creation**: Cannot skip pattern card generation for any identified patterns
> 3. **ADR Requirements**: Must create ADRs for any patterns requiring boundary changes
> 4. **Type Authority Check**: Must verify no conflicts with existing type authority
> 5. **Governance Validation**: All outputs must pass HarmoniaCLI validation
> 
> #### Escalation Path
> When ready to adopt patterns:
> 1. Hand off to Builder agent through governed toolchain
> 2. Use \ to generate structured patch
> 3. Create proposal with phase ID and acceptance criteria
> 4. Builder agent validates and applies patches using receipt chain
> 5. Integrator agent manages final commits through \n
> **Critical Constraint**: This agent NEVER writes code directly. It produces structured analysis that other agents implement.
[AGENTS.md:118]

> ### Tool Usage
> Agent sessions must rely on the governed toolchain instead of ad-hoc shell commands:
> 
> - `repo_clean_check`: ensure the branch, working tree, and submodules are clean before generating patches.
> - `swiftpm`/`swiftpm_log`: run builds/tests under strict concurrency and summarize diagnostics before advancing.
> - `binary_build_preflight`: dry-run the release build for a product before invoking `build_binary`.
> - `build_binary`: produce artifacts after a successful preflight, copy them to `Artifacts/bin`, compute SHA256, and optionally codesign.
> - `inspiration_patterns`: regenerate the Docs pattern registry/backlog and apply the resulting patch hash via the inspect→apply chain.
> - `generate_patch` → `propose_patch` (phaseId + acceptanceRefs required) → `validate_patch` → `apply_patch`: keep the receipt chain intact so the plugin can enforce phase contracts and gates.
> - `diagnose_patch_failure`: run this when validation/apply reports a problem; it reads the receipts + stored patch to explain the failure and point you to the right next tool (generate_patch, inspect_repo, etc.).
> - `quarantine_patch` / `rollback_last_apply`: recover from failed migrations without resetting the repo.
> - `commit_changes`: Integrator-only tool that runs gates, guards forbidden paths, and commits when receipts/gates are green.
> 
> Always attach the phase ID and acceptance criteria in your proposal so the plugin knows what mission the patch serves.
> 
> Refer to `agent_tools.md` for the verbatim implementation of every custom tool and for the `nextTool` guidance they emit. The plugin observes `.opencode/ledger/workflow.jsonl`, the phase contracts in `Docs/governance/phases/`, and those receipts, so stay inside the inspect→generate→propose→validate→apply flow even when working in plan mode or when drift tempts you to jump ahead.
[AGENTS.md:160]

> ## BUILD, LINT, AND TEST COMMANDS
> 
> - Add doc comments to public APIs. Note ported code with `// Ported from: X.py`.
> - Follow [ImplementationRules.md](Docs/ImplementationRules.md) for ECS, jobs, stubs, testing.
> - Add `#warning("STUB: ...")` and `// STUB_TRACK:` comments; update `Docs/TechDebt.md`.
> - Keep components domain-specific in `{Module}/Components/`.
> - Write tests for components, systems, workflows; run `swift test` before commit.
[AGENTS.md:177]

> ## EMERGENCY SECURITY PROCEDURES
> 
> ### Key Compromise Response
> 
> ```bash
> # Emergency key revocation
> anigma-key revoke --fingerprint "compromised-key-hash" \
>     --reason "security_incident" \
>     --authorized-by "security_admin" \
>     --incident-id "INC-2024-001"
> 
> # Generate verification bundle for compromised period
> anigma-verify --create-bundle \
>     --start-date "2024-12-01" \
>     --end-date "2024-12-13" \
>     --include-revoked-keys
> ```
> 
> The Core layer maintains the highest governance standards with cryptographic guarantees that survive infrastructure compromise, making ML operations court-admissible and legally defensible, while Capability Modules provide rich functionality without compromising security posture.
[AGENTS.md:189]

### Cross-Module Changes: Three-Pass Governance Pipeline
> ## Cross-Module Changes: Three-Pass Governance Pipeline (Required)
> Any change that crosses module boundaries or alters a public surface must follow the three-pass pipeline.
> 
> ### Pass 1 (Contract)
> - Add/update a contract artifact in `Docs/governance/contract-artifacts/`.
> - Define authority boundary, surface API, concurrency model, stop conditions, acceptance tests, migration plan.
> 
> ### Pass 2 (Implementation)
> - Implement behind the surface inside Capability modules.
> - No new public APIs beyond the contract artifact.
> - Mutable state must stay actor-isolated.
> 
> ### Pass 3 (Migration/Hardening)
> - Swap call sites to the surface.
> - Add adapters only behind the surface.
> - Add regression tests and logging/evidence hooks.
> - Document quarantine/backstop behavior.
> 
> CI enforces presence of a contract artifact for boundary-touching diffs via `scripts/governance/verify_contract_artifacts.sh`.
[AGENTS.md:207]

## Source: .opencode

### Tool Configuration (`.opencode/config.json`)
```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["./plugin.ts"],
  "tools": {
    "read": true,
    "grep": true,
    "glob": true,
    "list": true,

    "bash": false,
    "write": false,
    "edit": false,
    "patch": false,

    "inspect_repo": true,
    "generate_patch": true,
    "propose_patch": true,
    "validate_patch": true,
    "apply_patch": true,

    "swiftpm": true,
    "swiftpm_log": true,
    "build_binary": true,
    "docs_patch": true,
    "scratch_worktree": true,
    "vitepress_build": true,
    "worktree_create": true,
    "worktree_remove": true,
    "inspiration_patterns": true,
    "binary_build_preflight": true,
    "repo_clean_check": true,
    "quarantine_patch": true,
    "rollback_last_apply": true,
    "commit_changes": true
  }
}
```
[.opencode/config.json:1]

### Lifecycle Governance Plugin (`.opencode/plugin.ts`)
```ts
const LEDGER_PATH = ".opencode/ledger/workflow.jsonl";
const QUARANTINE_PATH = ".opencode/ledger/quarantine.jsonl";
const PHASE_DIR = "Docs/governance/phases";
```
[.opencode/plugin.ts:11]

```ts
function ensureReceiptChain(patchHash: string, ledger: ReturnType<typeof readReceipts>) {
  const scoped = ledger.filter((r) => r.patchHash === patchHash);
  requireInOrder(scoped, ["inspection", "generation", "proposal", "validation"]);
  const latestValidation = scoped.filter((r) => r.kind === "validation").slice(-1)[0];
  if (!latestValidation?.ok) throw new Error("Latest validation receipt is not ok.");
}
```
[.opencode/plugin.ts:75]

```ts
async function enforcePhaseContract(directory: string, patchHash: string, detail: any) {
  const phaseId = detail?.phaseId;
  const acceptanceRefs = Array.isArray(detail?.acceptanceRefs) ? detail.acceptanceRefs : [];
  if (!phaseId) throw new Error("Proposal missing phaseId.");
  if (!acceptanceRefs.length) throw new Error("Proposal must cite at least one acceptance criterion.");

  const contractPath = findPhaseContractPath(directory, phaseId);
  const { acceptanceSet, acceptanceNormalized, gates } = parsePhaseContract(contractPath);
  if (!acceptanceSet.size) throw new Error(`Phase ${phaseId} has no listed acceptance criteria.`);

  for (const ref of acceptanceRefs) {
    const trimmed = ref.trim();
    if (!trimmed) continue;
    if (!acceptanceNormalized.has(trimmed.toLowerCase())) {
      throw new Error(`Acceptance criterion "${trimmed}" not found in ${phaseId} contract (${contractPath}).`);
    }
  }

  for (const gate of gates) {
    if (!gate) continue;
    const runResult = await runCommand(gate, directory);
    if (!runResult.ok) {
      throw new Error(
        `Phase ${phaseId} gate "${gate}" failed:\n${runResult.stderr || runResult.stdout}`
      );
    }
  }
}
```
[.opencode/plugin.ts:156]

```ts
if (input.tool === "apply_patch") {
  const patchHash: string | undefined = output.args?.patchHash;
  if (!patchHash) throw new Error("Missing patchHash argument for apply_patch.");
  const quarantined = quarantineSet(quarantinePath);
  if (quarantined.has(patchHash)) {
    throw new Error(`Patch ${patchHash} is quarantined (use quarantine_patch to update).`);
  }
  const ledger = readReceipts(ledgerPath);
  ensureReceiptChain(patchHash, ledger);
  const validation = ledger.filter((r) => r.kind === "validation" && r.patchHash === patchHash).reverse()[0];
  if (!validation) throw new Error("No validation receipt found for this patch.");
  verifyBaseHashes(directory, validation.detail?.baseHashes ?? {});
  const proposal = getLatestProposalForPatch(ledger, patchHash);
  if (!proposal) throw new Error("No proposal receipt for this patch.");
  await enforcePhaseContract(directory, patchHash, proposal.detail ?? {});
}

if (input.tool === "commit_changes") {
  const status = await runGit(["status", "--porcelain=v1"], directory);
  if (!status.ok) throw new Error(`Failed to read git status: ${status.stderr}`);
  const dirty = parsePorcelain(status.stdout);
  const forbidden = dirty.filter((entry) => entry.path.startsWith(".opencode/") || entry.path.startsWith("Docs/governance/"));
  if (forbidden.length) {
    throw new Error(`Forbidden paths modified: ${forbidden.map((f) => f.path).join(", ")}`);
  }
  const head = await runGit(["rev-parse", "--abbrev-ref", "HEAD"], directory);
  if (head.stdout.trim() !== "main") throw new Error("Commits are only allowed on 'main'.");
  const sub = await runGit(["submodule", "status", "--recursive"], directory);
  const dirtySubmodule = sub.stdout.split("\n").some((line) => line.startsWith("+") || line.startsWith("-") || line.startsWith("U"));
  if (dirtySubmodule) throw new Error("Submodule(s) are out of sync; please sync before committing.");
  const receipts = readReceipts(ledgerPath);
  const lastApply = receipts.filter((r) => r.kind === "apply_result" && r.ok).slice(-1)[0];
  if (!lastApply) throw new Error("No successful apply_result found; commit not allowed.");
}
```
[.opencode/plugin.ts:189]

```ts
try {
  const payload = JSON.parse(output.output);
  if (payload && payload.patchHash && payload.ok === false) {
    appendQuarantineRecord(
      quarantinePath,
      ledgerPath,
      payload.patchHash,
      payload.detail?.note ?? "Tool reported failure",
      input.tool,
      { agent: "plugin", sessionID: input.sessionID, messageID: input.callID }
    );
  }
} catch {
  // best-effort only
}
```
[.opencode/plugin.ts:226]

### Agent Role Playbooks (`.opencode/agent`)

#### Integrator
> # Integrator (applies/makes governance decisions)
> 
> 1. Integrator is the only session allowed to run `apply_patch`, `commit_changes`, or any mutating tool. All subagents operate in isolated worktrees; they feed patchHashes + receipt evidence back to you.
> 2. Before applying patches, verify:
>    * `repo_clean_check` reports expected branch and clean state.
>    * Plugin has recorded a full inspection→generation→proposal→validation chain for each patchHash.
>    * No patchHash is quarantined (the plugin already enforces this, but double-check if needed).
> 3. After patch application, run `swiftpm`+`strict concurrency` and any relevant `build_binary`/`vitepress_build` gates to prove the milestone-specific DoD.
> 4. Commit changes using `commit_changes` only when all receipts/gates are satisfied; record the milestone DoD in `Docs/governance/phase-contracts` or the relevant milestone doc.
> 5. When applying multiple scoped subagent outputs, sequence them so they respect dependencies; use `git worktree add` + `scratch_worktree` metadata as needed, but never mutate subagent worktrees.
[.opencode/agent/integrator.md:1]

#### Judge
> # Authority Judge
> 
> 1. Read the Scout’s Duplication Dossier; make no repo mutations yet.
> 2. Decide one of three outcomes for each duplication: `shared-kernel` (tiny stable shared subset), `primitive-authority` (move concept wholesale to one owner), or `anti-corruption adapter` (wrap with translation/adapter and keep both bounded contexts separate).
> 3. Record each decision in an ADR/RFC-style artifact under `Docs/governance/contract-artifacts/` or `Docs/strategy/`, describing:
>    * Motivation and semantic invariants.
>    * Chosen bucket with justification plus coupling implications.
>    * Migration playbook: new canonical surface, adapters, shared contracts, validation gates.
> 4. Emit an “authority map update” (structured YAML/JSON) listing the winning owner for each concept, the adapter interface, and the scope of Shared Kernel exposure; keep the high-friction shared-kernel entries small.
> 5. No patch generation occurs in this phase; the artifact is purely a decision record and informs the Migrator.
[.opencode/agent/judge.md:1]

#### Migrator
> # Migrator (Strangler deployment)
> 
> 1. Use only approved patch chain tools (`generate_patch`, `propose_patch`, `validate_patch`, `apply_patch` via the Integrator) plus the new `repo_clean_check`, `swiftpm`, `swiftpm_log`, and `build_binary` helpers. Run everything in a detached worktree (`scratch_worktree` or `worktree_create` per scope) so main remains untouched.
> 2. Follow the migration playbook defined by the Judge:
>    * Create the new canonical surface.
>    * Add adapters, anti-corruption layers, or shared kernel stubs as temporary bridges.
>    * Migrate call sites module-by-module under SWIFT_STRICT_CONCURRENCY=complete or `-Xswiftc -strict-concurrency=complete`.
>    * Keep shared kernel surfaces small; annotate anything unstable with high-friction warnings.
>    * After call sites move, delete legacy definitions and ensure `repo_clean_check` passes before generating a patch.
> 3. Validate each patch batch with `validate_patch` (triggered automatically via the plugin) and capture build/log evidence (SwiftPM log + optional `vitepress_build` if docs touched).
> 4. Output patch hashes, summaries, and any `repo_clean_check` or build receipts so the Integrator can `apply_patch` and commit from the governed chain. Never commit or apply directly from this agent.
[.opencode/agent/migrator.md:1]

#### Scout
> # Duplicate Scout (read-only)
> 
> 1. Run only the read/grep/glob/list tools plus the existing non-mutating custom helpers (e.g., `inspect_repo`, `swiftpm_log`, `embeddings`). Do not write, patch, commit, or call `apply_patch`.
> 2. Document every duplication candidate as a structured Duplication Dossier:
>    * `Concept`: canonical name(s) you observed (module/type/function).
>    * `Locations`: absolute or workspace-relative file paths.
>    * `Semantics`: invariants, concurrency/actor requirements, payload shapes, known differences.
>    * `Risk`: migration sensitivity (shared kernel candidate, anti-corruption need, leave alone).
>    * `Proposed bucket`: `shared-kernel`, `authority/bridge`, or `independent`.
> 3. Keep reasoning short; cite the diagnostic evidence (tool outputs, logs, repo search results) that drove each bucket assignment.
> 4. Submit the dossier as the subtask output (JSON or clearly delimited sections). No modifications to the repo are produced by this agent.
[.opencode/agent/scout.md:1]
