# LLM Guidelines for Anigma

> Compact instructions for AI assistants working on the Anigma codebase.

## Agent Contract

You are bound by the Anigma Agent Contract, which defines your modus operandi and non-negotiable rules for working in this repository. All your actions must comply with this contract. (see AGENTS.md, Docs/LLM/AGENT-CONTRACT.md)

---

## Before You Start

1. **Read the Agent Contract**: `AGENTS.md` (or `Docs/LLM/AGENT-CONTRACT.md`)
2. **Read the Constitution**: `Docs/AnigmaConstitution.md`
3. **Check the Roadmap**: `Docs/Roadmap.md`
4. **Review relevant ADRs**: `Docs/ADR/`
5. **Follow implementation rules**: `Docs/ImplementationRules.md`

---

## Core Principles

### AnigmaCore is the Only ECS

```swift
// ✅ CORRECT
import AnigmaCore

struct MyComponent: Component, Codable { ... }
struct MySystem: System { ... }

// ❌ WRONG - Never create parallel ECS
protocol MyComponent { ... }  // NO
class MyWorld { ... }         // NO
```

### No Python, No Node

```swift
// ❌ NEVER DO THIS
Process.run("python3", ["script.py"])
Process.run("node", ["tool.js"])

// ✅ Re-implement in Swift
func processImage(_ url: URL) -> ProcessedImage { ... }
```

### Lab Code is Reference Only

External repos (`Harmonia`, `Apertum_Accesum`, etc.) contain older implementations.

- **Do**: Study patterns, learn algorithms, extract requirements
- **Don't**: Copy code directly, translate line-by-line
- **Must**: Re-design in Swift fitting AnigmaCore model

---

## When Editing Code

### Check ADRs First

Before modifying ECS, Jobs, or Workflows:
1. Check `Docs/ADR/` for relevant decisions
2. If your change conflicts, propose a new ADR
3. If no ADR exists for a major decision, create one

### Prefer Convergence

If you find duplicate patterns:
```swift
// Found in Module A:
enum JobStatus { case pending, running, done }

// Found in Module B:
enum TaskState { case waiting, active, complete }

// ✅ Converge to AnigmaCore.JobStatus
// Update both modules to use it
```

### Document Migration Source

```swift
//
//  OCRSystem.swift
//  AltMediaModule/Systems
//
//  Ported from: Harmonia_DSPS_AltMediaEngine/ocr_pipeline.py
//  Uses Apple Vision instead of Tesseract
//
```

---

## Quick Patterns

### Creating a Component

```swift
import AnigmaCore

public struct DocumentComponent: Component, Codable {
    public let sourcePath: String
    public var processedPath: String?
    public var pageCount: Int = 0
    
    public init(sourcePath: String) {
        self.sourcePath = sourcePath
    }
}
```

### Creating a System

```swift
import AnigmaCore

public struct OCRSystem: System {
    public var name: String { "OCR" }
    
    public init() {}
    
    public func update(world: World) async {
        let docs = await world.query(DocumentComponent.self)
        for (entity, doc) in docs {
            // Process...
        }
    }
}
```

### Creating a Workflow

```swift
import AnigmaCore

public struct OCRWorkflow: Workflow {
    public var name: String { "OCR Processing" }
    public var jobTypeId: String { "altmedia.ocr" }
    public var systemNames: [String] { ["Ingest", "OCR", "QA"] }
    
    public init() {}
}
```

### Registering a Module

```swift
public enum AltMediaModule {
    public static func register(world: World, registry: WorkflowRegistry) async throws {
        await world.registerSystem(IngestSystem())
        await world.registerSystem(OCRSystem())
        await world.registerSystem(QASystem())
        
        await registry.register(OCRWorkflow())
    }
}
```

---

## Decision Tree

```
Need to add ECS types?
├── Generic (EntityId, World, etc.) → AnigmaCore ✅
└── Domain-specific → Module ✅

Need to add job handling?
├── Generic (Scheduler, JobStatus) → AnigmaCore ✅
└── Job types, workflows → Module ✅

Need external tool functionality?
├── Python script → Re-implement in Swift ✅
├── Node tool → Re-implement or use static build ✅
└── System framework → Use directly ✅

Making architecture change?
├── Minor (internal refactor) → Just do it ✅
└── Major (API change, new pattern) → Write ADR first ✅
```

---

## Forbidden Patterns

| Pattern | Why It's Wrong |
|---------|----------------|
| `import MyModuleECS` | No module-specific ECS |
| `class World` in module | World is in AnigmaCore only |
| `shell("python", ...)` | No Python at runtime |
| `require('tool')` | No Node at runtime |
| Copy-pasting from lab repos | Re-design, don't translate |
| Skipping ADR for major change | Document decisions |

---

## When in Doubt

1. Check `AnigmaConstitution.md`
2. Check `ImplementationRules.md`
3. Check existing ADRs
4. Ask before proceeding with uncertain architecture

---

## Files to Reference

| File | Purpose |
|------|---------|
| `Docs/AnigmaConstitution.md` | Fundamental principles |
| `Docs/Roadmap.md` | Development plan |
| `Docs/ImplementationRules.md` | Do/don't rules |
| `Docs/ADR/*.md` | Architecture decisions |
| `Sources/AnigmaCore/` | Core ECS and Jobs |

## Gemini CLI Custom Slash Commands

To facilitate structured, repeatable interactions, several project-scoped custom commands are available via the Gemini CLI. These commands encapsulate complex workflows and enforce output contracts, making them the preferred way to interact with specific Anigma processes.

*   **`/deconstruct_inspo <repo_name>`**: Deconstructs one inspiration repository into an Anigma recipe bundle, enforcing strict scope and output contract.
*   **`/triage_inspo`**: Triage all repos in `Anigma/Inspiration/INBOX/`, updating the manifest with relevance tags and summaries.
*   **`/recipe_validator <repo_name>`**: Validates a recipe bundle against its output contract, reporting quality issues.
*   **`/mapping_enforcer <repo_name>`**: Enforces a strict table format for `02-anigma-mapping.md` within a recipe bundle.
*   **`/proposal_generator <task_brief_name> <output_path>`**: Generates an `ActionProposal` JSON from a TASK-BRIEF, conforming to the `ActionProposal.schema.json`.
*   **`/cctv_summarizer <cctv_logs_path>`**: Summarizes `CCTVEvent` JSON logs into a human-readable governance narrative.
*   **`/doc_link_hygiene`**: Scans key documentation files for consistency, missing links, and policy drift.

## Inspiration Deconstruction Workflow

When analyzing inspiration repositories (found in `Anigma/Inspiration/INBOX/`), use the `/deconstruct_inspo` slash command or run `Scripts/inspiration_deconstruct.sh`. This workflow ensures a structured, deterministic analysis and output contract for generating recipe bundles.

## Future: MCP Integration for Inspiration Deconstruction

For tighter control and a more robust "agent-safe" workflow, the inspiration deconstruction process (`inspiration_deconstruct.sh`) can evolve into a Harmonia MCP (Model Context Protocol) tool. This would expose a schema-described tool like `anigma_inspiration_deconstruct(repo_path) -> {recipe_path, status}` that Gemini (or other agents) can invoke. This approach ensures that the model can only "clean up the folder" through a precisely defined and governed gate. (feedback from review)

## Canonical Policy Source (`policy-pack.toml`)

`policy-pack.toml` (`Docs/LLM/policy-pack.toml`) is the canonical machine source of truth for repository policy. All automated checks and policy enforcement in CI and Harmonia should derive their rules from this file. (feedback from review)

## Task Briefs

All tasks assigned to agents should adhere to the `TASK-BRIEF.template.md` to ensure clarity, provide necessary context, and prevent hallucinated work. (see Docs/LLM/TASK-BRIEF.template.md)

## Harmonia's Operational Injection (Future)

Harmonia, as the governed front door for automation, is intended to strictly enforce the modus operandi of AI agents. (feedback from review)

*   **Prompt Prepending**: Harmonia should prepend the `AGENT-CONTRACT.digest.md` (Docs/LLM/AGENT-CONTRACT.digest.md), current governance snapshot, and trust tier, along with a "you are in strict-silo by default" banner, to every LLM prompt it sends.
*   **Forced Action Proposal**: The only allowed interface between an LLM and code changes will be a required "Action Proposal" wrapper, adhering to a defined schema (`Docs/LLM/ActionProposal.schema.json`). Every governance decision and event will be logged according to the `CCTVEvent` schema (`Docs/LLM/CCTVEvent.schema.json`).
    *   **Required Response**: LLMs may only respond with:
        1) An `ActionProposal` (with schema defined in `Docs/LLM/ActionProposal.schema.json`)
        2) A `Justification` (with citations to repo docs/ADRs)
        3) A `TestPlan`
        4) A `RollbackPlan`
    *   **Blocking Non-Compliance**: If an LLM cannot comply, it must respond with "BLOCKED" and explain why. The Write Gate will reject any attempt to output raw code without an `ActionProposal`, unless the trust tier explicitly allows it.

## Continuous Integration (CI) Enforcement (Future)

The CI system will act as a "bad cop" to mechanically enforce the project's modus operandi, ensuring invariants are proven automatically every time. CI must fail if it detects any of the following (feedback from review):

*   **Preflight Run**: `Scripts/agent_preflight.sh` does not run and pass as the very first step of CI.
*   **Policy-Pack Loading**: `policy-pack.toml` cannot be loaded or is invalid.

### Schema Validation

*   **ActionProposal Schema**: Any `ActionProposal` submitted to the repo does not validate against `Docs/LLM/ActionProposal.schema.json`. This includes valid and invalid fixture files failing validation as expected.
*   **CCTVEvent Schema**: Any `CCTVEvent` generated does not validate against `Docs/LLM/CCTVEvent.schema.json`. This includes valid and invalid fixture files failing validation as expected.

### Core Doctrine Violations

*   **Forbidden Runtimes**: New `.py` files appear in production targets. `Process.run("python", ...)` or `Process.run("node", ...)` patterns appear in production targets outside approved build-time tool folders.
*   **ECS Inconsistency**: A second `World` or `Component` protocol/materialization appears outside `AnigmaCore`.
*   **Dependency Policy**: A dependency is added with a license not on the allowlist or has known vulnerabilities (requires dependency review gate).
*   **Module Boundaries**: A new module directory is introduced without an ADR reference.

### Code Quality & Debt

*   **Stub Tracking**: Untracked `STUB_TRACK` entries exist. Stubs are introduced without corresponding tracking entries in `Docs/TechDebt.md`.

### Governance Process

*   **ActionProposal Compliance**: An agent attempts to write code without a valid `ActionProposal` in the expected location or format (even if this is a convention at first, CI must enforce it).
*   **Logging Compliance**: Agent-attributed commits lack required `CCTVEvent` log artifacts or these artifacts are invalid.
*   **Contract Digest Drift**: The calculated `agent_contract_digest` (from `policy-pack.toml` and `AGENTS.md`) does not match any embedded references.
