## Harmonia wrapper policy

Always run Harmonia through the deterministic wrappers in the project root:
- `Scripts/harmonia.sh` for CLI operations (swift6, security, trust)
- `Scripts/harmonia-surface.sh` for surface testing and concurrency validation

Do not execute `swift run`, `swift build`, `.build/.../harmonia*`, or `xcodebuild` directly.  
Let the wrappers manage installation and deterministic JSON output. Do not parse or reformat the JSON response; treat it as authoritative.

## Tool-based workflows

Gemini-powered agents should never mutate the repo directly. Instead, rely on the sanctioned custom tools plus the plugin-enforced receipt chain:

- Start with `repo_clean_check` to ensure you are on `main`, submodules are clean, and the working tree does not touch forbidden paths before generating any patches.
- Use `generate_patch` ➜ `propose_patch` (now requiring `phaseId` + `acceptanceRefs`) ➜ `validate_patch` so the plugin can run the gates listed in the referenced phase contract before `apply_patch` is allowed.
- To prove a SwiftPM release will succeed before requesting a binary, run `binary_build_preflight` for the target product and only invoke `build_binary` once the preflight returns `ok: true`.
- For docs-related work, generate the Inspiration registry/backlog with `inspiration_patterns` and apply only the resulting patch hash so the registry and roadmap stay in sync with the backlog.
- Always let the Integrator session run `apply_patch`/`commit_changes`, and ensure each proposal detail references a `phaseId` and acceptance criteria from `Docs/governance/phases/*.md`.

Consult `agent_tools.md` whenever you want the exact source for a tool, the receipts it emits, and the `nextTool` hint it returns. The plugin enforces the inspect→generate→propose→validate→apply pipeline based on those receipts plus the phase contracts, so avoid skipping steps or inventing a freeform patch when you already have governed helpers.
If validation or apply fails, run `diagnose_patch_failure` to get a machine-friendly diagnosis (receipt gaps, stale bases, malformed headers, etc.) and the next tool you should call before trying again.
