# Contributing to Anigma

We welcome contributions to Anigma! This guide provides an overview of the development process and the specific workflow that all contributors, including AI agents, should follow.

## Development Workflow

Anigma uses a deterministic, tool-based workflow to ensure the integrity and quality of the codebase. All changes to the repository must be made through the sanctioned tools and processes.

### For AI Agents

As an AI agent, you must strictly adhere to the following workflow:

1.  **Start with `repo_clean_check`:** Before making any changes, ensure that you are on the `main` branch, that all submodules are clean, and that the working tree does not touch any forbidden paths.

2.  **Use the `generate_patch` ➜ `propose_patch` ➜ `validate_patch` ➜ `apply_patch` pipeline:**
    *   **`generate_patch`:** Generate a patch file for your proposed changes.
    *   **`propose_patch`:** Propose the patch for review. This will require a `phaseId` and `acceptanceRefs` from the `Docs/governance/phases/*.md` files.
    *   **`validate_patch`:** The plugin will run a series of gates to validate the patch against the referenced phase contract.
    *   **`apply_patch`:** Once the patch is validated, the Integrator session will apply it to the codebase.

3.  **Use `binary_build_preflight` for SwiftPM releases:** To ensure that a SwiftPM release will succeed, run `binary_build_preflight` for the target product before invoking `build_binary`.

4.  **Use `inspiration_patterns` for docs-related work:** For any documentation-related work, generate the Inspiration registry/backlog with `inspiration_patterns` and apply only the resulting patch hash to keep the registry and roadmap in sync with the backlog.

5.  **Let the Integrator session run `apply_patch`/`commit_changes`:** Ensure that each proposal detail references a `phaseId` and acceptance criteria from `Docs/governance/phases/*.md`.

6.  **Consult `agent_tools.md`:** For the exact source for a tool, the receipts it emits, and the `nextTool` hint it returns, consult the `agent_tools.md` file.

7.  **Handle validation or application failures:** If a patch fails validation or application, run `diagnose_patch_failure` to get a machine-friendly diagnosis and the next tool you should call before trying again.

**Important:** Do not mutate the repository directly. All changes must go through the sanctioned tool-based workflow.

### For Human Contributors

At present, all contributions, including those from human developers, must follow the same tool-based workflow as AI agents. This is to ensure a consistent and verifiable chain of custody for all changes to the codebase.

We are working on providing a more streamlined workflow for human contributors in the future.

## Code Style and Conventions

Please adhere to the existing code style and conventions in the project. We use `.swift-format.json` to enforce a consistent style for all Swift code.

## Questions and Support

If you have any questions or need assistance with the contribution process, please open an issue on GitHub.
