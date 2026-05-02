# AGENTS_HERMES.md - Hermes Agent Guidelines with Shared Memory Integration

## Mandatory: TD + Sidecar Workflow

This repository uses Sidecar `td` for task and session coordination. Reference: https://sidecar.haplab.com/docs/td

1. Start of every conversation/context window (or after `/clear`):
   ```bash
   td usage --new-session
   ```
2. Use a quiet status check after setup:
   ```bash
   td usage -q
   ```
3. Start implementation on a tracked issue:
   ```bash
   td start <issue-id>
   # Multi-issue work:
   td ws start "<work-session-name>"
   td ws tag <issue-id> [issue-id...]
   ```
4. Log progress as you go:
   ```bash
   td log "<progress note>"
   # or: td ws log "<progress note>"
   ```
5. Before ending context, record handoff (required):
   ```bash
   td handoff <issue-id> \
     --done "<completed and tested work>" \
     --remaining "<specific pending tasks>" \
     --decision "<why this approach was chosen>" \
     --uncertain "<open questions>"
   # or: td ws handoff
   ```
6. Completion flow: material implementer runs `td review <issue-id>`; an independent reviewer runs `td approve <issue-id>`. Review/admin coordination, dependency moves, blocker notes, milestone updates, and documentation/research/note-only participation do not by themselves prevent approval.
7. Never use `td close` for completed implementation work. Use `td close` only for admin closures (duplicate/won't-fix/cleanup).
8. Do not start a new session mid-work unless you are intentionally beginning a new context.

This document outlines how Hermes Agent should interact with the Anigma codebase, leveraging Shared memory for persistent context and improved effectiveness.

## Quick Start

1. **Always check Shared memory first**: `memory_store(mode: "search", query: "[topic]", scope: "project")`
2. **Use Hermes Agent tools**: Worktree isolation, KDCO primitives, Anigma CI tools
3. **Follow git discipline**: One plan → One worktree → Multiple tasks → One commit → Cleanup
4. **Maintain memory hygiene**: Add timestamps, review stale memories per plan
5. **Coordinate memory systems**: Extract → Shared memory → Prune workflow for context/Shared memory synergy

## Documentation Structure

This documentation is organized into focused modules:

### **Core Guidelines**
- **[AGENTS_PLUGINS.md](AGENTS_PLUGINS.md)** - Hermes plugin usage and patterns
- **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Three-tier memory system and housekeeping
- **[AGENTS_GIT.md](AGENTS_GIT.md)** - Git management and workflow discipline
- **[AGENTS_DIGESTION.md](AGENTS_DIGESTION.md)** - Inspiration repo analysis pipeline
- **[AGENTS_ROADMAP.md](AGENTS_ROADMAP.md)** - Roadmap relevance and tracking pipeline

### **Reference Materials**
- **[AGENTS_QUICKREF.md](AGENTS_QUICKREF.md)** - Cheat sheet for common tasks
- **[AGENTS_EXAMPLES.md](AGENTS_EXAMPLES.md)** - Complete workflow examples

## Essential Principles

### **1. Shared memory-First Approach**
- Always query Shared memory before starting work
- Add new insights with timestamps
- Maintain three-tier memory system

### **2. Plugin-Driven Development**
- Use worktrees for isolated development
- Leverage KDCO primitives for common tasks
- Run CI gates before committing

### **3. Git Hygiene**
- Prevent branch/worktree sprawl
- Follow complete workflow per plan
- Clean up after completion

### **4. Continuous Learning**
- Digest inspiration repos regularly
- Update roadmap based on patterns
- Maintain institutional knowledge

## Getting Started

For new agents, read in this order:
1. **[AGENTS_QUICKREF.md](AGENTS_QUICKREF.md)** - Essential commands and patterns
2. **[AGENTS_GIT.md](AGENTS_GIT.md)** - Workflow discipline
3. **[AGENTS_SUPERMEMORY.md](AGENTS_SUPERMEMORY.md)** - Memory management
4. **[AGENTS_PLUGINS.md](AGENTS_PLUGINS.md)** - Tool usage
5. **[AGENTS_DIGESTION.md](AGENTS_DIGESTION.md)** - Learning from inspiration

## Updates

When you discover new patterns or improve workflows:
1. **Update relevant memory** in Shared memory
2. **Document in appropriate module**
3. **Cross-reference** between modules

---

**Last Updated**: 2026-04-27
**Based on Shared memory Insights**: 13+ project memories
**Primary Contributor**: Julian Torres
**Architecture**: Three-tier capsule-based Swift 6 platform
**Hermes Agent Version**: 0.11.0
**Context Window**: 128K tokens
**Model**: gemma4:e4b (8B parameters, 4-bit quantized)
**Optimized for**: M1 Mac 16GB RAM with memory-safe configuration