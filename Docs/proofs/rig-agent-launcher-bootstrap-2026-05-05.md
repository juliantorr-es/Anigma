# Rig Agent Launcher Bootstrap

## Root Cause

Rig had advisory local-LLM planning and a set of non-interactive external agents, but it did not yet have a narrow allowlisted launcher that could:
- draft a plan from Rig evidence,
- validate the plan before launch,
- launch known agents without `shell=True`,
- persist run artifacts and events,
- surface agent runs in monitor and session bundles.

## Files Created

- [`scripts/rig_cli/commands_agent.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_cli/commands_agent.py)
- [`scripts/rig_tools/agent_launcher.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/agent_launcher.py)
- [`scripts/rig_tools/agent_plan.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/rig_tools/agent_plan.py)
- [`scripts/test_agent_launcher.py`](/Users/user/Developer/GitHub/Anigma_clean/scripts/test_agent_launcher.py)
- [`Docs/dev/rig/AGENTS.md`](/Users/user/Developer/GitHub/Anigma_clean/Docs/dev/rig/AGENTS.md)
- [`Docs/schemas/rig.agent_plan.v1.schema.json`](/Users/user/Developer/GitHub/Anigma_clean/Docs/schemas/rig.agent_plan.v1.schema.json)
- [`Docs/schemas/rig.agent_run.v1.schema.json`](/Users/user/Developer/GitHub/Anigma_clean/Docs/schemas/rig.agent_run.v1.schema.json)
- [`Docs/dev/rig/agent-registry.yaml`](/Users/user/Developer/GitHub/Anigma_clean/Docs/dev/rig/agent-registry.yaml)
- [`Docs/proofs/rig-agent-launcher-bootstrap-2026-05-05.md`](/Users/user/Developer/GitHub/Anigma_clean/Docs/proofs/rig-agent-launcher-bootstrap-2026-05-05.md)

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
- `python scripts/anigma_diagnose.py validate --task-id rig-agent-launcher-bootstrap --command true`
- `python scripts/rig.py monitor snapshot`
- `python scripts/rig.py bundle session --task td-cleanup-005 --dry-run`
- `python scripts/rig.py schema validate --family rig.agent_run.v1`

## Exit Codes

- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_agent_launcher.py` -> `0`
- `python scripts/test_agent_launcher.py` -> `0`
- `python scripts/rig.py agent status` -> `0`
- `python scripts/rig.py agent plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit` -> `0`
- `python scripts/rig.py agent validate-plan --plan .build/rig/agents/plans/td-cleanup-005-codex-plan.json` -> `0`
- `python scripts/rig.py agent launch --from-plan .build/rig/agents/plans/td-cleanup-005-codex-plan.json --dry-run` -> `0`
- `python scripts/rig.py schema validate --artifact .build/rig/agents/plans/td-cleanup-005-codex-plan.json` -> `0`
- `python scripts/rig.py schema validate --family rig.agent_plan.v1` -> `0`
- `python scripts/anigma_diagnose.py validate --task-id rig-agent-launcher-bootstrap --command true` -> `0`
- `python scripts/rig.py monitor snapshot` -> `0`
- `python scripts/rig.py bundle session --task td-cleanup-005 --dry-run` -> `0`
- `python scripts/rig.py schema validate --family rig.agent_run.v1` -> `0`

## Detected Agents

- `codex`: available and enabled
- `gemini`: available and enabled
- `claude`: missing executable
- `vibe`: available but disabled by default

## Generated Plan

- Plan path: `.build/rig/agents/plans/td-cleanup-005-codex-plan.json`
- Plan markdown: `.build/rig/agents/plans/td-cleanup-005-codex-plan.md`
- Plan status: `passed`
- Plan validation: `passed`
- Local LLM planner status: advisory only

## Dry-Run Launch Result

- Run id: `432162281afd`
- Dry-run status: `dry_run`
- Resolved command: `codex exec .build/rig/agents/runs/432162281afd/prompt.md`
- Run manifest: `.build/rig/agents/runs/432162281afd/agent-run.json`
- External agent actually launched: `no`

## Schema Validation Result

- `rig.agent_plan.v1`: passed
- `rig.agent_run.v1`: passed

## Monitor / Bundle Evidence

- `monitor snapshot` wrote:
  - `.build/rig/monitor/state.json`
  - `.build/rig/monitor/index.html`
- The session bundle dry-run included agent artifacts:
  - `.build/rig/agents/plans/td-cleanup-005-codex-plan.json`
  - `.build/rig/agents/runs/432162281afd/agent-run.json`
  - `.build/rig/agents/runs/432162281afd/prompt.md`

## Safety Notes

- No arbitrary shell command execution was enabled.
- No `shell=True` was used.
- No Git mutation occurred.
- Agent output is not authoritative until Rig validation passes.

## Production Source Changed

- No

## Git Mutation Occurred

- No

