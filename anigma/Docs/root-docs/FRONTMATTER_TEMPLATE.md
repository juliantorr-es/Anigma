# Frontmatter Template for Anigma Documentation

Every document in the Anigma documentation should include YAML frontmatter at the top. This metadata helps both humans and agents understand the document's context, complexity, and how it relates to other documentation.

## Template

```markdown
---
title: "Document Title"
description: "Brief description of what this document covers (1-2 sentences)"
audience: ["developers", "contributors", "operators", "agents"]
complexity: "beginner|intermediate|advanced"
estimated_time: "15 minutes"
keywords: ["keyword1", "keyword2", "keyword3"]
prerequisites:
  - "Prerequisite 1"
  - "Prerequisite 2"
related_docs:
  - "path/to/related/doc1.md"
  - "path/to/related/doc2.md"
commands:
  - "executable command 1"
  - "executable command 2"
error_ref: "troubleshooting/relevant-errors.md"
last_updated: "2026-04-16"
status: "stable|beta|experimental"
---

# Document Title

...content...
```

## Field Reference

### Required Fields

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `title` | string | Human-readable document title | "Building Anigma from Source" |
| `description` | string | 1-2 sentence overview | "Complete guide to compiling Anigma..." |
| `audience` | array | Who this doc is for | ["developers", "agents"] |
| `complexity` | string | Skill level required | "intermediate" |
| `estimated_time` | string | How long to read | "15 minutes" |

### Optional Fields

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `keywords` | array | Search terms | ["build", "compile", "xcode"] |
| `prerequisites` | array | Required knowledge/tools | ["Xcode 12+", "Git"] |
| `related_docs` | array | Links to related documents | ["guides/testing.md"] |
| `commands` | array | Executable commands shown | ["./build.sh"] |
| `error_ref` | string | Where to find error solutions | "troubleshooting/build-issues.md" |
| `last_updated` | string | Last edit date | "2026-04-16" |
| `status` | string | Document status | "stable" |

## Audience Values

Possible audiences:
- **developers**: Software developers using/extending Anigma
- **contributors**: People contributing to Anigma itself
- **operators**: People deploying and running Anigma
- **agents**: AI agents using this documentation
- **first-timers**: New users getting started
- **advanced**: Expert users needing deep technical details

## Complexity Levels

- **beginner**: No prior knowledge assumed
- **intermediate**: Assumes familiarity with Anigma basics
- **advanced**: Assumes deep knowledge of architecture/internals

## Time Estimates

Format: "X minutes" or "X hours" or "varies"

Examples:
- "5 minutes" - Quick reference
- "15 minutes" - Medium guide
- "1 hour" - Deep dive
- "varies" - Depends on task

## Example: Building Guide

```markdown
---
title: "Building Anigma"
description: "Complete guide to building Anigma from source code using Swift and Xcode"
audience: ["developers", "contributors", "agents"]
complexity: "intermediate"
estimated_time: "15 minutes"
keywords: ["build", "compile", "swift", "xcode", "make", "cmake"]
prerequisites:
  - "Xcode 12 or later"
  - "macOS 10.15 or later"
  - "Git installed"
  - "Familiarity with command line"
related_docs:
  - "getting-started/installation.md"
  - "troubleshooting/build-issues.md"
  - "guides/testing.md"
  - "development/development-workflow.md"
commands:
  - "cd anigma && ./build.sh"
  - "./build.sh --test"
  - "./build.sh --release"
error_ref: "troubleshooting/build-issues.md"
last_updated: "2026-04-16"
status: "stable"
---

# Building Anigma

This guide walks you through building Anigma from source...
```

## Example: API Reference

```markdown
---
title: "API Reference - HarmoniaModule"
description: "Complete API documentation for HarmoniaModule public interfaces"
audience: ["developers", "agents"]
complexity: "advanced"
estimated_time: "varies"
keywords: ["api", "reference", "harmonia", "interface", "functions"]
related_docs:
  - "concepts/modules.md"
  - "guides/implementing-features.md"
  - "reference/module-reference.md"
last_updated: "2026-04-16"
status: "stable"
---

# API Reference - HarmoniaModule

## Overview

HarmoniaModule provides the following public APIs...
```

## Example: Troubleshooting Guide

```markdown
---
title: "Troubleshooting Build Errors"
description: "Solutions to common build problems and error explanations"
audience: ["developers", "contributors"]
complexity: "intermediate"
estimated_time: "10 minutes"
keywords: ["troubleshoot", "build", "error", "failed", "solution"]
prerequisites:
  - "Basic understanding of building"
related_docs:
  - "guides/building.md"
  - "troubleshooting/error-reference.md"
error_ref: "troubleshooting/error-reference.md"
last_updated: "2026-04-16"
status: "stable"
---

# Troubleshooting Build Errors

## Common Build Issues

### Error: Command not found...
```

## Best Practices

1. **Be Specific**: "Building Anigma" not "Guide"
2. **Include Keywords**: Think about what agents will search for
3. **Link Related Docs**: Help readers discover related content
4. **Update Status**: Mark if document is experimental or stable
5. **Keep Time Estimates Accurate**: Users rely on these
6. **List Prerequisites**: Agents check these before starting

## Frontmatter in Different Sections

### Getting Started Documents
```yaml
audience: ["first-timers", "developers"]
complexity: "beginner"
estimated_time: "5-15 minutes"
prerequisites: [] # Usually none
```

### Reference Documents
```yaml
audience: ["developers", "agents"]
complexity: "advanced"
estimated_time: "varies"
# Many related docs
```

### Troubleshooting Documents
```yaml
audience: ["developers", "operators"]
complexity: "intermediate"
estimated_time: "5-10 minutes"
error_ref: "self" # Points to error solutions
```

### Architecture Deep Dives
```yaml
audience: ["advanced", "contributors", "agents"]
complexity: "advanced"
estimated_time: "20-30 minutes"
prerequisites: ["familiarity with concepts/architecture.md"]
```

## Validation

To validate frontmatter:
1. Ensure all required fields are present
2. Verify links in `related_docs` exist
3. Check that audience values are from approved list
4. Confirm complexity is one of: beginner/intermediate/advanced
5. Ensure time estimate format is correct

## Maintenance

- Update `last_updated` whenever content changes
- Review `related_docs` when adding new documents
- Update `status` if document becomes experimental or deprecated
- Keep keywords current with document content

---

**For agents**: Parse this frontmatter to understand:
- Prerequisites before executing instructions
- Estimated time for task planning
- Related documents for context
- Complexity for routing decisions
- Keywords for semantic search

**For humans**: Use frontmatter to quickly assess:
- Is this the right document for me?
- Do I have the prerequisites?
- How much time should I allocate?
- What else should I read?
