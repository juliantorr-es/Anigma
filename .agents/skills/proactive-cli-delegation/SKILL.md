---
name: proactive-cli-delegation
description: Core operating mandate for all tasks. Forces proactive discovery, documentation-reading, and delegation to locally installed CLI tools (e.g., jq, gh, ripgrep) and available MCP servers *before* writing custom scripts or using generic tools. Triggers on any task solvable via ecosystem tooling, data processing, API interaction, or system queries.
---

# Proactive CLI Delegation

You are operating in an environment equipped with rich ecosystem tools and Model Context Protocol (MCP) servers. Your core mandate is to **delegate work** to these specialized tools rather than building ad-hoc scripts (e.g., bash pipelines, python scripts) to solve problems.

## The Prime Directive

**Before writing custom code to parse, fetch, process, or search data, you MUST:**
1. Check if a local CLI tool or MCP server already exists for the task.
2. Read the tool's documentation or help output to guarantee correct syntax.
3. Delegate the task to the tool programmatically.

## Discovery Workflow

When faced with a task (e.g., "Parse this JSON", "Query GitHub", "Search logs"):

### 1. Identify Candidate Tools
- **CLIs:** Use `command -v <tool>` or `which <tool>` to verify existence (e.g., `jq`, `gh`, `rg`, `yq`, `curl`).
- **MCP Servers:** Use the `mcp-find` tool to query the catalog for relevant servers.

### 2. Documentation First (No Guessing)
Never assume the syntax of a CLI tool. Tool versions and flags change.
- Run `<tool> --help` or `<tool> -h` using `run_shell_command`.
- Read the output to construct the exact, correct command invocation.

### 3. Execution & Delegation
- Use `run_shell_command` with `--silent` or `-q` flags where applicable to minimize token output.
- If using an MCP server, ensure it is added via `mcp-add` and execute its tools via `mcp-exec` or direct calls.

## Example: JSON Processing

**BAD (Ad-hoc script):**
Writing a python script using `json` module to extract a deeply nested field from a 10MB file.

**GOOD (CLI Delegation):**
1. Run `command -v jq` to confirm `jq` is installed.
2. Run `jq --help` to confirm the syntax for the specific filter needed.
3. Run `run_shell_command` executing `jq -r '.deeply.nested.field' data.json`.

## Example: GitHub Interactions

**BAD (Generic API):**
Using `curl` to manually construct GitHub API requests with Bearer tokens.

**GOOD (CLI Delegation):**
1. Run `command -v gh` to confirm the GitHub CLI is installed.
2. Run `gh issue --help` to confirm the syntax for listing issues.
3. Execute the command `gh issue list --json title,url`.

## Error Handling

If a delegated tool fails:
1. Do not immediately revert to writing a custom script.
2. Read the error output carefully.
3. Re-consult the tool's `--help` output.
4. Correct your syntax and retry the delegation.