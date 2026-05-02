---
title: "Documentation Style Guide"
description: "Standards and conventions for writing Anigma documentation to ensure consistency, clarity, and maintainability across all documents."
audience: ["contributors", "developers", "agents"]
complexity: "intermediate"
estimated_time: "20 minutes"
keywords: ["documentation", "style", "conventions", "writing", "standards", "frontmatter"]
prerequisites:
  - "GitHub account with repository access"
  - "Basic Markdown knowledge"
  - "Familiarity with Anigma project structure"
related_docs:
  - "documentation-ownership.md"
  - "documentation-index.md"
  - "../FRONTMATTER_TEMPLATE.md"
last_updated: "2026-04-15"
status: "stable"
---

# Documentation Style Guide

This guide establishes standards for writing, formatting, and maintaining Anigma documentation. Following these conventions ensures consistency across all documentation and makes it easier for contributors, developers, and AI agents to understand and navigate the knowledge base.

## Table of Contents

1. [Frontmatter Requirements](#frontmatter-requirements)
2. [Markdown Conventions](#markdown-conventions)
3. [Writing Style](#writing-style)
4. [Structure and Organization](#structure-and-organization)
5. [Code Examples](#code-examples)
6. [Links and References](#links-and-references)
7. [Author Checklist](#author-checklist)

---

## Frontmatter Requirements

Every documentation file MUST include YAML frontmatter at the top. This metadata helps both humans and AI systems understand document purpose, complexity, and relationships.

### Required Fields

```yaml
---
title: "Document Title"
description: "Brief description (1-2 sentences)"
audience: ["developers", "contributors"]
complexity: "beginner|intermediate|advanced"
estimated_time: "X minutes"
last_updated: "YYYY-MM-DD"
status: "stable|beta|experimental|stub"
---
```

### Field Details

| Field | Required | Values | Example |
|-------|----------|--------|---------|
| `title` | ✅ | String | "Building Anigma from Source" |
| `description` | ✅ | String (1-2 sentences) | "Complete guide to compiling Anigma..." |
| `audience` | ✅ | Array: developers, contributors, operators, agents, first-timers, advanced | ["developers", "agents"] |
| `complexity` | ✅ | beginner, intermediate, advanced | "intermediate" |
| `estimated_time` | ✅ | "X minutes", "X hours", or "varies" | "15 minutes" |
| `keywords` | ❌ | Array of search terms | ["build", "compile", "swift"] |
| `prerequisites` | ❌ | Array of requirements | ["Xcode 12+", "Git"] |
| `related_docs` | ❌ | Array of relative paths | ["guides/testing.md"] |
| `commands` | ❌ | Array of executable commands | ["./build.sh"] |
| `error_ref` | ❌ | Path to error reference | "troubleshooting/build-issues.md" |
| `last_updated` | ✅ | ISO date (YYYY-MM-DD) | "2026-04-16" |
| `status` | ✅ | stable, beta, experimental, stub | "stable" |

### Frontmatter Example

```yaml
---
title: "Building Anigma"
description: "Complete guide to building Anigma from source code using Swift and Xcode"
audience: ["developers", "contributors", "agents"]
complexity: "intermediate"
estimated_time: "15 minutes"
keywords: ["build", "compile", "swift", "xcode"]
prerequisites:
  - "Xcode 12 or later"
  - "macOS 10.15 or later"
  - "Git installed"
related_docs:
  - "getting-started/installation.md"
  - "guides/testing.md"
  - "development/development-workflow.md"
commands:
  - "cd anigma && ./build.sh"
  - "./build.sh --test"
error_ref: "troubleshooting/build-issues.md"
last_updated: "2026-04-16"
status: "stable"
---
```

---

## Markdown Conventions

### Headings

- Use `#` for document title (only one per document)
- Use `##` for major sections
- Use `###` for subsections
- Use `####` for sub-subsections
- Avoid nesting deeper than 4 levels

```markdown
# Document Title          (One per file)
## Major Section         (2-3 per document)
### Subsection          (Under major sections)
#### Sub-subsection     (Rarely needed)
```

### Emphasis

- **Bold** for UI elements, key terms: `**Settings Menu**`
- *Italic* for emphasis, file paths when not in code: `*optional parameter*`
- `code` for inline code, commands, file names: `` `npm install` ``

```markdown
Click **Settings** to open the configuration dialog.
The optional *username* parameter can be omitted.
Run `npm install` to install dependencies.
```

### Lists

- Use `-` for unordered lists
- Use `1.` for ordered lists
- Use indentation (2 spaces) for nested items
- Leave blank line before and after list blocks

```markdown
## Features

- Feature one
- Feature two
  - Sub-feature 2a
  - Sub-feature 2b
- Feature three

## Installation Steps

1. Download the installer
2. Run the setup wizard
   1. Accept the license
   2. Choose installation directory
3. Start using Anigma
```

### Tables

Use pipe syntax for tables with alignment:

```markdown
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Left     | Center   | Right    |
| aligned  | aligned  | aligned  |
```

### Code Blocks

- Use triple backticks with language identifier
- Always specify language: `bash`, `swift`, `python`, `json`, `yaml`, `markdown`, etc.
- Include comments for non-obvious code

```bash
# Build Anigma in release mode
./build.sh --release --verbose
```

```swift
// Query the database
let results = try database.query("SELECT * FROM users")
```

### Blockquotes

Use `>` for important notes and warnings:

```markdown
> ⚠️ **Warning**: This action cannot be undone. Back up your data first.

> 💡 **Tip**: Use `--verbose` flag to see detailed build output.

> ℹ️ **Note**: This feature requires Xcode 12 or later.
```

---

## Writing Style

### Tone and Voice

- **Clear and Direct**: Avoid jargon; explain technical terms
- **Active Voice**: "The build process creates binaries" not "Binaries are created"
- **Inclusive**: Write for beginners; explain assumptions
- **Concise**: Use short sentences; one idea per sentence
- **Professional**: Avoid slang, exclamations, or casual language

### Guidelines

✅ **DO**:
- Use present tense for current behaviors
- Define acronyms on first use: "The Build Tool Chain (BTC)"
- Break paragraphs into 2-3 sentences maximum
- Use specific examples over abstract descriptions
- End lists with periods if items are complete sentences

❌ **DON'T**:
- Use future tense: "The build will create files" → "The build creates files"
- Assume knowledge of Anigma internals
- Use vague terms: "stuff", "things", "etc."
- Write paragraphs longer than 4 sentences
- Use exclamation marks or multiple punctuation marks

### Examples

**Clear and Direct:**
```markdown
Install Anigma using Homebrew:
brew install anigma

This command downloads and installs the latest version.
```

**Avoid Vague:**
```markdown
❌ "Various configuration options are available"
✅ "You can customize logging level, database connection, and API timeout in config.yaml"
```

**Use Active Voice:**
```markdown
❌ "The build process is run to create the executable"
✅ "Run the build process to create the executable"
```

---

## Structure and Organization

### Document Template

All documents should follow this structure:

```markdown
---
[FRONTMATTER]
---

# Document Title

## Overview
Brief description of what this document covers (2-3 sentences).

## Prerequisites
List any required knowledge or tools.

## Main Content Sections
Organize content into logical sections.

## Common Issues
Troubleshooting or gotchas specific to this topic.

## Next Steps
What to do after reading this document.

## See Also
- [Related Document 1](path/to/doc1.md)
- [Related Document 2](path/to/doc2.md)

---

**Status**: [stable|beta|experimental]
**Last Updated**: [Date]
**Maintainer**: [Owner]
```

### Sections Guidelines

- **Overview**: 2-3 sentences explaining what the document covers
- **Prerequisites**: Required knowledge or tools before starting
- **Main Content**: 2-4 major sections with subsections as needed
- **Common Issues**: Troubleshooting problems specific to this topic
- **Next Steps**: Where to go after reading
- **See Also**: Links to related documentation

### File Naming

- Use lowercase with hyphens: `documentation-style-guide.md`
- Be descriptive: `swift-performance-guidelines.md` not `guide.md`
- Avoid special characters except hyphens and underscores
- Organize by purpose: `/getting-started/`, `/guides/`, `/reference/`, `/troubleshooting/`

---

## Code Examples

### Requirements

- **Realistic**: Use actual, working code examples
- **Focused**: Show only relevant portions; use `...` to indicate omitted code
- **Runnable**: Examples should be copy-paste ready when possible
- **Documented**: Explain what the code does before or after the block
- **Consistent**: Match project conventions and style

### Example Patterns

**Before and After:**
```markdown
### Without Error Handling
```swift
let data = try? loadFile("config.json")
```

### With Error Handling
```swift
do {
    let data = try loadFile("config.json")
    process(data)
} catch {
    print("Failed to load config: \(error)")
}
```
```

**Progressive Complexity:**
```markdown
### Simple Case
```bash
./build.sh
```

### With Options
```bash
./build.sh --release --verbose --test
```

### Complete Example
```bash
# Build with all options for debugging
./build.sh \
    --release \
    --verbose \
    --test \
    --coverage
```
```

**Highlighting Key Parts:**
```markdown
```swift
let config = Configuration()
config.verboseLogging = true      // Enable detailed output
config.maxRetries = 3              // Set retry limit
config.timeout = 30.0              // Set 30 second timeout
process(config)
```
```

### Comments in Code

- Explain **why**, not what (code shows what)
- Keep comments brief and aligned with code
- Update comments when code changes
- Remove commented-out code

```swift
// ❌ BAD: Explains what
counter += 1  // Add one to counter

// ✅ GOOD: Explains why
counter += 1  // Increment retry count before sleep
```

---

## Links and References

### Internal Links

- Use relative paths: `[Link Text](../path/to/doc.md)`
- Not: `[Link Text](/docs/path/to/doc.md)`
- Keep directory structure in mind
- Test links during review

```markdown
See [Building Guide](../guides/building.md) for more details.
Review [Architecture Overview](../../concepts/architecture.md) first.
```

### External Links

- Use full URLs: `[Link Text](https://example.com)`
- Add context about what the link is
- Prefer linking to Anigma documentation over external sites

```markdown
For more information about Swift, see [The Swift Programming Language](https://swift.org/documentation).
```

### Cross-References

- Reference documents by title, not path
- Use consistent terminology
- Update references when documents move

```markdown
✅ See the [Performance Guidelines](performance-guidelines.md) for optimization tips.
❌ See performance-guidelines.md for optimization tips.
```

### Link Validation

All links in your document will be validated:
- Internal links must point to existing files
- Related docs in frontmatter must be valid
- Broken links will fail CI checks

Before submitting, verify:
1. All `related_docs` links exist
2. All inline `[link](path)` references work
3. No typos in file paths

---

## Author Checklist

Before submitting documentation, verify all items:

### Content Requirements
- [ ] Frontmatter is complete with all required fields
- [ ] Title accurately describes content
- [ ] Description is 1-2 sentences
- [ ] Audience is appropriate and complete
- [ ] Complexity level is accurate (beginner/intermediate/advanced)
- [ ] Time estimate is realistic
- [ ] Status field is appropriate (stable/beta/experimental/stub)

### Structure Requirements
- [ ] Document has Overview section
- [ ] Document is organized into logical sections (2-4 major sections)
- [ ] Headings use correct levels (only one # per document)
- [ ] Document has "See Also" section with related docs
- [ ] Footer shows status and last updated date

### Markdown Requirements
- [ ] Code blocks have language specifiers (bash, swift, etc.)
- [ ] All lists are formatted correctly
- [ ] All tables are properly aligned
- [ ] Important notes use blockquote syntax
- [ ] Emphasis uses correct markers (bold **text**, italic *text*)

### Link Requirements
- [ ] All internal links use relative paths
- [ ] All related_docs in frontmatter exist
- [ ] External links have context
- [ ] No broken or typo'd links

### Writing Requirements
- [ ] Active voice used throughout
- [ ] Technical terms are explained
- [ ] Sentences are concise (max 3 per paragraph)
- [ ] No slang or casual language
- [ ] Examples are clear and runnable
- [ ] Instructions are specific and actionable

### Code Requirements
- [ ] All code examples are accurate and runnable
- [ ] Code blocks include explanatory comments
- [ ] Examples show realistic use cases
- [ ] No commented-out code blocks
- [ ] Commands show expected output or results

### Final Review
- [ ] Proofread for spelling and grammar
- [ ] No unnecessary acronyms or jargon
- [ ] Document provides clear value
- [ ] Related documents are properly linked
- [ ] Estimated time is realistic
- [ ] Frontmatter keywords match content

---

## Common Mistakes to Avoid

| Mistake | Problem | Fix |
|---------|---------|-----|
| Missing frontmatter | Document metadata lost | Add required YAML front matter |
| Inconsistent heading levels | Navigation breaks | Use `#`, `##`, `###` consistently |
| Broken internal links | Users can't navigate | Use relative paths and verify links exist |
| Code blocks without language | Syntax highlighting fails | Add language: ` ```bash ` |
| Vague descriptions | Unclear purpose | Be specific: "Installation Guide" not "Guide" |
| No prerequisites | Users attempt docs unprepared | List required knowledge |
| Long paragraphs | Hard to read | Break into 2-3 sentence chunks |
| Passive voice | Confusing responsibility | Use active voice |
| Outdated `last_updated` | Unclear freshness | Update date when content changes |

---

## Examples from Existing Docs

### ✅ Well-Written Document

See `docs/FRONTMATTER_TEMPLATE.md` for comprehensive frontmatter examples with proper structure, clear sections, and complete formatting.

### ✅ Clear Code Examples

From `docs/development/code-style-guide.md`:
- Examples show realistic scenarios
- Comments explain non-obvious choices
- Multiple related examples build understanding

### ✅ Proper Structure

From `docs/README.md`:
- Clear frontmatter with all required fields
- Quick Navigation section with direct links
- Organized by user role and use case
- Links to specific guides and references

---

## Updating This Guide

This style guide is a living document. Update it when:
- New conventions are established
- Repeated mistakes suggest clarification needed
- Tool changes affect documentation process
- Community feedback indicates issues

Changes to the style guide should:
1. Follow the guide itself (meta!)
2. Include rationale in commit message
3. Notify documentation owners
4. Consider impact on existing docs

---

## Questions and Support

- **Documentation Questions**: See `docs/development/documentation-ownership.md`
- **Submit Feedback**: Create an issue tagged `documentation`
- **Report Broken Links**: Use the validate-docs.sh script and report findings

---

**Status**: Stable
**Last Updated**: 2026-04-16
**Maintainer**: Documentation Team
