from __future__ import annotations

import json
from pathlib import Path

from rig_tools import mlx_local


def register(subparsers, helpers):
    parser = subparsers.add_parser("llm", help="Optional MLX local advisory summaries", description="Generate advisory-only summaries using local MLX models.")
    llm = parser.add_subparsers(dest="llm_cmd", required=True)

    status = llm.add_parser("status", help="Show MLX backend status")
    status.add_argument("--backend", default="mlx")
    status.set_defaults(handler=lambda args: _emit(mlx_local.status(args.backend)))

    smoke = llm.add_parser("smoke", help="Smoke-test MLX summary generation")
    smoke.add_argument("--backend", default="mlx")
    smoke.add_argument("--model")
    smoke.add_argument("--max-tokens", type=int, default=80, dest="max_tokens")
    smoke.set_defaults(handler=lambda args: _emit(mlx_local.smoke_generate_mlx_lm(args.model or mlx_local.SUMMARY_MODEL, mlx_local.build_prompt(task=None, kind="smoke", source_artifacts=[], context="Say hello in one short sentence."), args.max_tokens, 180)))

    summarize = llm.add_parser("summarize", help="Summarize a Rig artifact")
    summarize.add_argument("--backend", default="mlx")
    summarize.add_argument("--artifact", required=True)
    summarize.add_argument("--model")
    summarize.set_defaults(handler=lambda args: _emit(mlx_local.summarize_artifact(helpers.repo_root, artifact=Path(args.artifact), model=args.model)))

    summarize_session = llm.add_parser("summarize-session", help="Summarize a Rig session")
    summarize_session.add_argument("--backend", default="mlx")
    summarize_session.add_argument("--task", required=True)
    summarize_session.add_argument("--model")
    summarize_session.set_defaults(handler=lambda args: _emit(mlx_local.summarize_session(helpers.repo_root, task=args.task, model=args.model)))

    proof = llm.add_parser("compress-proof", help="Compress a proof into an advisory summary")
    proof.add_argument("--backend", default="mlx")
    proof.add_argument("--proof", required=True)
    proof.add_argument("--model")
    proof.set_defaults(handler=lambda args: _emit(mlx_local.compress_proof(helpers.repo_root, proof=Path(args.proof), model=args.model)))

    commit = llm.add_parser("draft-commit-summary", help="Draft an advisory commit summary")
    commit.add_argument("--backend", default="mlx")
    commit.add_argument("--task", required=True)
    commit.add_argument("--model")
    commit.set_defaults(handler=lambda args: _emit(mlx_local.draft_commit_summary(helpers.repo_root, task=args.task, model=args.model)))


def _emit(payload) -> int:
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0
