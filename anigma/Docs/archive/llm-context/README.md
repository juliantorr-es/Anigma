# Anigma LLM Context Documentation Index

This directory contains comprehensive documentation for AI agents working with Anigma's two-tier architecture. The documentation is organized to provide clear guidance on operating within the security boundaries while effectively extending the system's capabilities.

## Documentation Structure

### Core Architecture Documentation

**[00-two-tier-architecture-guide.md](./00-two-tier-architecture-guide.md)**
- **Purpose**: Executive overview and primary operating guide
- **Audience**: All AI agents working with Anigma
- **Content**: Two-tier architecture explanation, decision trees, quick reference matrix
- **Key Sections**: Core vs Capability separation, agent workflows, security boundaries

**[01-core-governance-deep-dive.md](./01-core-governance-deep-dive.md)**
- **Purpose**: Technical deep dive into Core Governance Layer
- **Audience**: Agents working with security, ML operations, or Core Layer
- **Content**: Harmonia interface, evidence generation, emergency procedures
- **Key Sections**: Court-safe ML integration, hardware security, verification procedures

**[02-capability-modules-development.md](./02-capability-modules-development.md)**
- **Purpose**: Comprehensive guide for Capability Module development
- **Audience**: Agents implementing new features or modules
- **Content**: Module patterns, architectural reuse, testing strategies
- **Key Sections**: Search-before-create workflow, integration patterns, performance optimization

### Operational Procedures

**[03-agent-workflows-procedures.md](./03-agent-workflows-procedures.md)**
- **Purpose**: Standard operating procedures for agent workflows
- **Audience**: All AI agents following multi-agent processes
- **Content**: Multi-agent pipeline, decision trees, error handling
- **Key Sections**: Agent handoff protocol, common workflows, recovery procedures

**[04-security-governance-compliance.md](./04-security-governance-compliance.md)**
- **Purpose**: Security and compliance requirements
- **Audience**: All agents, especially those handling sensitive data
- **Content**: Security boundaries, compliance requirements, incident response
- **Key Sections**: Core Layer security, ML operations security, emergency procedures

## Quick Start for Agents

### 1. First-Time Agent Setup

1. **Read the Architecture Guide**: Start with `00-two-tier-architecture-guide.md`
2. **Understand Your Role**: Determine if you're working with Core Layer or Capability Modules
3. **Learn Security Boundaries**: Review `04-security-governance-compliance.md`
4. **Follow Workflows**: Use procedures from `03-agent-workflows-procedures.md`

### 2. Task-Based Navigation

| Task Type | Primary Document | Secondary Documents |
|-----------|------------------|-------------------|
| Core Layer operations | `01-core-governance-deep-dive.md` | `04-security-governance-compliance.md` |
| New feature development | `02-capability-modules-development.md` | `03-agent-workflows-procedures.md` |
| Security incident response | `04-security-governance-compliance.md` | `01-core-governance-deep-dive.md` |
| Module maintenance | `02-capability-modules-development.md` | `03-agent-workflows-procedures.md` |
| Multi-agent coordination | `03-agent-workflows-procedures.md` | `00-two-tier-architecture-guide.md` |

### 3. Critical Decision Points

**Before ANY Action:**
- Am I working with Core Layer or Capability Modules?
- Have I searched existing abstractions?
- Do I understand the security implications?
- Which workflow phase should I be in?

**Core Layer Rules:**
- ALWAYS use `Scripts/harmonia.sh` for CLI operations
- ALWAYS use `Scripts/harmonia-surface.sh` for surface testing
- NEVER use direct Swift build commands
- ALWAYS generate evidence for ML operations
- NEVER bypass security boundaries

**Capability Module Rules:**
- ALWAYS search before creating new abstractions
- NEVER create circular dependencies
- ALWAYS follow existing patterns
- NEVER duplicate Core Layer functionality

## Architecture Summary

### Two-Tier Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Core Governance Layer                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │ AnigmaCore  │ │DatabaseCore │ │  HarmoniaSpine      │   │
│  │ (ECS)       │ │ (Secure DB) │ │  (Governance)       │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
│                        │                                   │
│              ┌─────────▼─────────┐                         │
│              │  Harmonia Wrapper  │                         │
│              │  (ONLY Interface)  │                         │
│              └───────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                  Capability Modules                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │HarmoniaModule│ │DiaplasionMod│ │  Other Modules...   │   │
│  │(AI/ML)      │ │(Alt-Media)  │ │                     │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Security First**: Core Layer maintains court-safe, cryptographically auditable security
2. **Clear Boundaries**: Strict separation between Core and Capability layers
3. **Architectural Reuse**: Prefer existing abstractions over creating new ones
4. **Governance by Default**: All operations must respect governance policies
5. **Evidence Required**: ML operations must generate verifiable evidence

## Agent Responsibilities

### Core Layer Agents
- Maintain security boundaries
- Ensure evidence generation
- Follow emergency procedures
- Use Harmonia wrapper exclusively

### Capability Module Agents
- Search before creating
- Follow existing patterns
- Maintain module boundaries
- Document decisions

### All Agents
- Follow multi-agent workflows
- Update documentation
- Track technical debt
- Report security incidents

## Common Pitfalls to Avoid

### Core Layer Violations
- Using `swift build` directly
- Creating custom ECS implementations
- Bypassing Harmonia for governance
- Direct database access

### Capability Module Violations
- Creating duplicate abstractions
- Circular dependencies
- Ignoring existing patterns
- Poor documentation

### Workflow Violations
- Skipping workflow phases
- Poor handoff communication
- Inadequate testing
- Missing documentation updates

## Getting Help

### Security Issues
- Follow emergency procedures immediately
- Generate evidence bundles
- Document all actions

### Technical Questions
- Search existing documentation
- Review similar implementations
- Consult architectural patterns

### Process Issues
- Follow workflow procedures
- Document blockers
- Escalate through proper channels

## Documentation Maintenance

This documentation set is maintained as part of the Anigma project. When making architectural changes:

1. Update relevant documentation files
2. Ensure consistency across all documents
3. Update this index as needed
4. Follow the Scribe phase in multi-agent workflows

## Version Information

- **Last Updated**: 2025-12-15
- **Architecture Version**: Two-Tier Architecture v1.0
- **Target Audience**: AI Agents working with Anigma
- **Maintenance**: Part of Anigma project documentation

For the most current information, always refer to the main Anigma repository and the latest versions of these documents.