# Rig Agents

Rig can draft and launch non-interactive external agents in a constrained, allowlisted way.

## Doctrine

- The local LLM only drafts advisory plans.
- Rig validates the plan before anything launches.
- Only known agents in `Docs/dev/rig/agent-registry.yaml` may be launched.
- Launches are non-interactive and use fixed command templates.
- No arbitrary shell commands are allowed.
- No `shell=True`.
- Git mutation is blocked unless a validated plan explicitly allows it, and even then Rig still requires confirmation.
- Agent output is not authoritative until Rig validation and proofs pass.

## Registry

- `codex`: `codex exec {prompt_file}`
- `gemini`: `gemini -p {prompt} --output-format stream-json`
- `claude`: `claude -p {prompt}`
- `vibe`: `vibe --prompt {prompt}` but disabled by default

## Artifacts

- Plans: `.build/rig/agents/plans/<plan_id>.json`
- Plan markdown: `.build/rig/agents/plans/<plan_id>.md`
- Runs: `.build/rig/agents/runs/<run_id>/agent-run.json`
- Prompt: `.build/rig/agents/runs/<run_id>/prompt.md`
- Stdout: `.build/rig/agents/runs/<run_id>/stdout.log`
- Stderr: `.build/rig/agents/runs/<run_id>/stderr.log`
- Events: `.build/rig/agents/runs/<run_id>/events.jsonl`

## Commands

- `python3 scripts/rig.py agent status`
- `python3 scripts/rig.py agent plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`
- `python3 scripts/rig.py agent validate-plan --plan .build/rig/agents/plans/<plan_id>.json`
- `python3 scripts/rig.py agent launch --from-plan .build/rig/agents/plans/<plan_id>.json --dry-run`
- `python3 scripts/rig.py agent launch --from-plan .build/rig/agents/plans/<plan_id>.json --confirm`

