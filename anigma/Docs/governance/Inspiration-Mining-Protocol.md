# Inspiration Mining Protocol

> **Purpose:** Extract architectural patterns from inspiration repositories and convert them into Anigma-native, enforceable artifacts
> **Authority:** HarmoniaCLI (governance authority) with coordination from AnigmaCore (type authority)
> **Version:** 1.0
> **Status:** Active

---

## 1. Mission

Transform inspiration repositories into **Anigma-native architectural assets** through systematic extraction, validation, and governance. This protocol ensures that external patterns are properly interpreted, adapted, and integrated while maintaining:

- **Type authority boundaries** (no shadowing of Core types)
- **Contract authority compliance** (single source of truth for interfaces)
- **State authority isolation** (DatabaseCore for all persistence)
- **Governance authority enforcement** (Harmonia CLI surface only)
- **Provenance authority tracking** (Accessum artifact generation)

---

## 2. Required Inputs

### Absolute Paths Required
- `inspiration_path`: Path to inspiration repository folder
- `anigma_working_tree`: Path to Anigma repository working tree
- `north_star_phase_contract`: Path to current phase contract document
- `type_authority_map`: Path to `/Users/user/Developer/GitHub/Anigma/Docs/governance/type-authority-map.json`

### Prerequisites
- Clean Anigma working tree (`repo_clean_check` must pass)
- Type authority map current and validated
- North Star phase contract active and accessible
- Harmonia CLI operational (`Scripts/harmonia.sh` responsive)

---

## 3. Required Outputs

### Primary Artifacts
- **Pattern Cards**: Standardized documentation for each extracted pattern
- **ADRs**: Architecture Decision Records for cross-boundary changes
- **Roadmap Mapping**: Integration timeline and priority mapping
- **Adoption Spikes** (optional): Minimal implementations for validation

### Secondary Artifacts
- **Inspiration Dossier**: Complete analysis of source repository
- **Integration Plan**: Step-by-step implementation roadmap
- **Risk Assessment**: Security, licensing, and architectural risk analysis

---

## 4. Pattern Card Format

Every extracted pattern MUST follow this exact structure:

```markdown
# Pattern-{ID}: {Short Name}

## Source Information
- **Source Repository**: {repo_name}
- **Source Anchor**: {file_path or commit_hash}
- **Extraction Date**: {YYYY-MM-DD}
- **Extracting Agent**: {agent_id}

## Intent
{One-paragraph description of what problem this pattern solves}

## Forces
{What constraints or requirements make this pattern necessary}

## Boundary
{Where the pattern operates - Core vs Capability layer}

## Contract Surface
{Public API, types, and protocols that define the pattern}

## Failure Modes
{Known failure scenarios and mitigation strategies}

## What It Replaces
{Existing Anigma approach that this pattern supersedes, if any}

## Where It Lives in Anigma
{Target module and file structure for implementation}

## Acceptance Tests
{Test requirements to validate pattern adoption}

## Rollout Strategy
{Implementation timeline and migration approach}
```

---

## 5. Mapping Rules

### Cross-Module Interface Handling
- **Core-to-Core**: Direct integration with contract authority approval
- **Core-to-Capability**: Adapter pattern required, ADR mandatory
- **Capability-to-Capability**: Anti-corruption layer preferred
- **External-to-Anigma**: Full contract surface definition required

### Tool Governance
- **New Tools**: Must extend `ToolDescriptor` and `ToolRegistry`
- **Runtime Modifications**: Require HarmoniaCLI contract approval
- **Shell Commands**: Governed through `ShellToolRuntime` only
- **Git Operations**: Must use `GitToolRuntime` abstractions

### State-Machine Patterns
- **State Storage**: Must use DatabaseCore contracts
- **State Transitions**: Actor-isolated with Sendable compliance
- **Persistence**: SQLite-backed through DatabaseCore only
- **Serialization**: Canonical format for Accessum provenance

---

## 6. Extraction Loop (4-Step Process)

### Step 1: Read Top-Level Documentation
1. Scan README, CONTRIBUTING, ARCHITECTURE files
2. Identify main architectural concepts
3. Extract high-level patterns and design principles
4. Document repository's overall intent and scope

### Step 2: Write Repository Intent Summary
1. Create `00-summary.md` following `Inspiration/RECIPES/sample-repo/00-summary.md` template
2. Define relevance to Anigma's current phase goals
3. Identify architectural alignment points
4. Note any anti-patterns to avoid

### Step 3: Identify Candidate Patterns
1. Scan codebase for recurring architectural elements
2. Look for ECS patterns, state management, tool integration
3. Identify cross-cutting concerns and their solutions
4. Create preliminary pattern card drafts

### Step 4: Targeted Code Reads
1. Deep-dive into implementation of candidate patterns
2. Extract concrete APIs, data structures, and algorithms
3. Analyze dependencies and coupling characteristics
4. Validate pattern applicability to Anigma context

---

## 7. Adoption Decision Loop

### Pattern Classification
- **Adopt Now**: Immediate implementation in current phase
- **Adopt Later**: Deferrable to future phases
- **Don't Adopt**: Rejected due to misalignment or risks

### ADR Requirements
Patterns classified as "Adopt Now" MUST have accompanying ADRs addressing:
- **Boundary Impact**: How this affects Core/Capability separation
- **Type Authority**: Any new types that must be registered
- **Contract Authority**: New or modified contract surfaces
- **Migration Path**: How existing code transitions to new pattern
- **Risk Mitigation**: Security, performance, and maintenance risks

### Decision Criteria
- **Alignment with North Star**: Supports current phase objectives
- **Type Authority Compliance**: No shadowing of Core types
- **Governance Feasibility**: Can be enforced through existing mechanisms
- **Integration Cost**: Benefits outweigh implementation complexity
- **Risk Profile**: Acceptable security and architectural risks

---

## 8. Module Mapping Rules

### ContractsCore
- **Scope**: Contract definitions, interfaces, protocols
- **Authority**: Contract authority owner
- **Constraints**: Must remain minimal and stable

### AnigmaPrimitives
- **Scope**: Core types, ECS primitives, Sendable types
- **Authority**: Type authority owner
- **Constraints**: Cannot be extended or shadowed

### AnigmaCore
- **Scope**: ECS implementation, World, EntityId, Component, System
- **Authority**: Type authority owner
- **Constraints**: Core runtime only, no business logic

### Capability Modules
- **Scope**: Feature implementations, domain logic
- **Authority**: Module-specific with contract oversight
- **Constraints**: Must use Core types without modification

### Integration Rules
- **Core Extensions**: Forbidden without architectural review
- **Capability Dependencies**: Minimize cross-capability coupling
- **Shared Logic**: Prefer shared kernel over duplication
- **Adapters**: Use anti-corruption layer for external integrations

---

## 9. Implementation Approach

### Files First, Then Code
1. **Structure Creation**: Create directory structure and empty files
2. **Interface Definition**: Write contracts and types without implementation
3. **Documentation**: Complete pattern cards and ADRs
4. **Implementation**: Add business logic behind established contracts

### Governed Patch System
All implementation MUST follow the receipt chain:
1. `inspect_repo`: Verify current state
2. `generate_patch`: Create unified diff
3. `propose_patch`: Attach phase ID and acceptance criteria
4. `validate_patch`: Run governance gates
5. `apply_patch`: Apply only after validation passes

### Worktree Management
- **Feature Isolation**: Use `worktree_create` for each pattern
- **Parallel Development**: Multiple patterns in separate worktrees
- **Sequential Integration**: Apply patches through Integrator role
- **Rollback Capability**: `rollback_last_apply` available for failed migrations

### Testing Requirements
- **Unit Tests**: Component and System level validation
- **Integration Tests**: Cross-module boundary testing
- **Governance Tests**: Contract and authority compliance
- **Strict Concurrency**: Must pass `anigma_swift6_check`

---

## 10. Definition of Done

### Required Artifacts
- [ ] **Pattern Card**: Complete for each adopted pattern
- [ ] **ADR**: Approved for all boundary-impacting changes
- [ ] **Roadmap Entry**: Mapped to phase timeline with dependencies
- [ ] **Minimal Spike**: Working implementation for validation

### Quality Gates
- [ ] **Type Authority**: No conflicts with existing types
- [ ] **Contract Authority**: All interfaces properly defined
- [ ] **Governance Compliance**: Harmonia CLI validation passes
- [ ] **Strict Concurrency**: Swift6 checks pass with no warnings
- [ ] **Test Coverage**: Acceptance tests implemented and passing

### Integration Requirements
- [ ] **Patch Receipt Chain**: Complete and validated
- [ ] **Type Authority Map**: Updated if new types introduced
- [ ] **Contract Artifacts**: Stored in `Docs/governance/contract-artifacts/`
- [ ] **Phase Contract**: Current phase objectives satisfied
- [ ] **Documentation**: VitePress site builds successfully

### Handoff Criteria
- [ ] **Source Repository**: Analysis complete and archived
- [ ] **Pattern Registry**: Updated with new patterns
- [ ] **Tech Debt Log**: Any temporary workarounds documented
- [ ] **Knowledge Transfer**: Implementation guide created
- [ ] **Monitoring**: Observability hooks in place for adoption metrics

---

## 11. Agent Role Coordination

### Primary Agents
- **Architect**: Lead extraction and pattern identification
- **Builder**: Implement patterns using governed patch system
- **Validator**: Verify compliance and quality gates
- **Integrator**: Apply patches and manage release coordination

### Communication Protocol
- **Inspiration Dossier**: Shared understanding of source repository
- **Pattern Registry**: Common pattern catalog across all agents
- **Phase Contracts**: Shared understanding of current objectives
- **Receipt Chain**: Immutable record of all actions taken

### Escalation Paths
- **Type Conflicts**: Escalate to type authority owner
- **Contract Disputes**: Escalate to contract authority owner
- **Governance Violations**: Escalate to HarmoniaCLI maintainers
- **Security Concerns**: Escalate through security incident response

---

## 12. References

- **Type Authority Map**: `/Users/user/Developer/GitHub/Anigma/Docs/governance/type-authority-map.json`
- **Inspiration Structure**: `/Users/user/Developer/GitHub/Anigma/Inspiration/`
- **Contract Artifacts**: `/Users/user/Developer/GitHub/Anigma/Docs/governance/contract-artifacts/`
- **ADR Template**: `/Users/user/Developer/GitHub/Anigma/Docs/ADR/0000-template.md`
- **Consolidation Protocol**: `/Users/user/Developer/GitHub/Anigma/Docs/governance/consolidation-protocol.md`
- **Agent Contract**: `/Users/user/Developer/GitHub/Anigma/AGENTS.md`

---

*This protocol ensures that inspiration mining produces enforceable, well-governed architectural assets that strengthen Anigma while maintaining strict boundary enforcement and type safety.*
