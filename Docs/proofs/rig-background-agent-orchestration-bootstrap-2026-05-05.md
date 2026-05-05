# Rig Background Agent Orchestration Bootstrap

## Files Created

- [`scripts/rig_cli/commands_agent.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_cli/commands_agent.py)
- [`scripts/rig_tools/agent_plan.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/agent_plan.py)
- [`scripts/rig_tools/agent_launcher.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/agent_launcher.py)
- [`scripts/test_agent_launcher.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/test_agent_launcher.py)
- [`Docs/dev/rig/AGENTS.md`](/Users/user/Developer/GitHub/Anigma_clean/Docs/dev/rig/AGENTS.md)
- [`Docs/dev/rig/agent-registry.yaml`](/Users/user/Developer/GitHub/Anigma_clean/Docs/dev/rig/agent-registry.yaml)
- [`Docs/schemas/rig.agent_plan.v1.schema.json`](/Users/user/Developer/GitHub/Anigma_clean/Docs/schemas/rig.agent_plan.v1.schema.json)
- [`Docs/schemas/rig.agent_run.v1.schema.json`](/Users/user/Developer/GitHub/Anigma_clean/Docs/schemas/rig.agent_run.v1.schema.json)
- [`Docs/proofs/rig-background-agent-orchestration-bootstrap-2026-05-05.md`](/Users/user/Developer/GitHub/Anigma_clean/Docs/proofs/rig-background-agent-orchestration-bootstrap-2026-05-05.md)

## Files Modified

- [`scripts/rig_cli/main.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_cli/main.py)
- [`scripts/rig_tools/schema_validation.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/schema_validation.py)
- [`scripts/rig_tools/session_bundle.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/session_bundle.py)
- [`scripts/rig_tools/monitor.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/monitor.py)
- [`scripts/rig_tools/agent_plan.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/agent_plan.py)
- [`scripts/rig_tools/agent_launcher.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/agent_launcher.py)
- [`scripts/rig_cli/commands_agent.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_cli/commands_agent.py)
- [`Docs/dev/rig/README.md`](/Users/user/Developer/GitHub/Anigma_clean/Docs/dev/rig/README.md)
- [`scripts/test_rig_cli.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/test_rig_cli.py)

## Commands Run

- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_agent_launcher.py`
- `python scripts/test_agent_launcher.py`
- `python scripts/rig.py agent status`
- `python scripts/rig.py agent plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`
- `python scripts/rig.py agent validate-plan --plan .build/rig/agents/plans/td-cleanup-005-codex-plan.json`
- `python scripts/rig.py agent launch --from-plan .build/rig/agents/plans/td-cleanup-005-codex-plan.json --dry-run`
- `python scripts/rig.py schema validate --artifact .build/rig/agents/plans/td-cleanup-005-codex-plan.json`
- `python scripts/rig.py schema validate --family rig.agent_plan.v1`
- `python scripts/rig.py schema validate --family rig.agent_run.v1`
- `python scripts/rig.py monitor snapshot`
- `python scripts/rig.py bundle session --task td-cleanup-005 --dry-run`
- `python scripts/anigma_diagnose.py validate --task-id rig-background-agent-orchestration-bootstrap --command true`

## Exit Codes

- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_agent_launcher.py` -> `0`
- `python scripts/test_agent_launcher.py` -> `0`
- `python scripts/rig.py agent status` -> `0`
- `python scripts/rig.py agent plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit` -> `0`
- `python scripts/rig.py agent validate-plan --plan .build/rig/agents/plans/td-cleanup-005-codex-plan.json` -> `0`
- `python scripts/rig.py agent launch --from-plan .build/rig/agents/plans/td-cleanup-005-codex-plan.json --dry-run` -> `0`
- `python scripts/rig.py schema validate --artifact .build/rig/agents/plans/td-cleanup-005-codex-plan.json` -> `0`
- `python scripts/rig.py schema validate --family rig.agent_plan.v1` -> `0`
- `python scripts/rig.py schema validate --family rig.agent_run.v1` -> `0`
- `python scripts/rig.py monitor snapshot` -> `0`
- `python scripts/rig.py bundle session --task td-cleanup-005 --dry-run` -> `0`
- `python scripts/anigma_diagnose.py validate --task-id rig-background-agent-orchestration-bootstrap --command true` -> `0`

## Detected Agents

- `codex`: available and enabled
- `gemini`: available and enabled
- `claude`: missing executable
- `vibe`: available but disabled by default

## Missing Agents

- `claude`

## Disabled Agents

- `claude`
- `vibe`

## Generated Plan Path

- `.build/rig/agents/plans/td-cleanup-005-codex-plan.json`

## Plan Validation Result

- Status: `passed`
- Errors: none

## Dry-Run Launch Result

- Status: `dry_run`
- Resolved command: `codex exec .build/rig/agents/runs/1beae8a83a60/prompt.md`
- Run manifest: `.build/rig/agents/runs/1beae8a83a60/agent-run.json`
- External agent actually launched: `no`

## Schema Validation Result

- `rig.agent_plan.v1`: passed
- `rig.agent_run.v1`: passed

## Monitor / Bundle Evidence

- `monitor snapshot` wrote `.build/rig/monitor/state.json` and `.build/rig/monitor/index.html`
- `bundle session --dry-run` included:
  - `.build/rig/agents/plans/td-cleanup-005-codex-plan.json`
  - `.build/rig/agents/runs/1beae8a83a60/agent-run.json`
  - `.build/rig/agents/runs/1beae8a83a60/prompt.md`
  - `.build/rig/agents/runs/1beae8a83a60/events.jsonl`

## Advisory Statement

- The local LLM planner is advisory only.
- It did not execute subprocesses.
- Rig remained the safety gate and launch orchestrator.

## Production Source Changed

- No

## Git Mutation Occurred

- No

