from __future__ import annotations
import argparse

def register(subparsers, helpers):
    parser = subparsers.add_parser("audit", help="Audit operations", description="Advisory and gate audits.")
    audit_sub = parser.add_subparsers(dest="audit_cmd", required=True)

    dead = audit_sub.add_parser("dead-code", help="Dead-code audit")
    dead.add_argument("--mode", default="advisory")
    dead.add_argument("--baseline")
    dead.add_argument("--include-tests", action="store_true")
    dead.add_argument("--no-proof", action="store_true")
    dead.add_argument("--json-out")
    dead.set_defaults(handler=lambda args: helpers.delegate(
        "anigma_dead_code_audit.py",
        [f"--mode={args.mode}", *( [f"--baseline={args.baseline}"] if args.baseline else [] ), *(["--include-tests"] if args.include_tests else []), *(["--no-proof"] if args.no_proof else []), *( [f"--json-out={args.json_out}"] if args.json_out else [] )],
        args.quiet,
    ))

    exe = audit_sub.add_parser("executable-consolidation", help="Executable consolidation audit")
    exe.add_argument("--mode", default="advisory")
    exe.add_argument("--focus")
    exe.add_argument("--baseline")
    exe.add_argument("--use-atlas", action="store_true")
    exe.add_argument("--atlas-dir")
    exe.add_argument("--no-proof", action="store_true")
    exe.set_defaults(handler=lambda args: helpers.delegate(
        "anigma_executable_consolidation_audit.py",
        [f"--mode={args.mode}", *( [f"--focus={args.focus}"] if args.focus else [] ), *( [f"--baseline={args.baseline}"] if args.baseline else [] ), *(["--use-atlas"] if args.use_atlas else []), *( [f"--atlas-dir={args.atlas_dir}"] if args.atlas_dir else [] ), *(["--no-proof"] if args.no_proof else [])],
        args.quiet,
    ))

    state = audit_sub.add_parser("state-flow", help="State flow and cohesion audit")
    state.add_argument("--mode", default="advisory")
    state.add_argument("--scope", choices=["repo", "anigma", "target"], default="repo")
    state.add_argument("--target")
    state.add_argument("--focus")
    state.add_argument("--exclude-external-research", action="store_true")
    state.add_argument("--include-tests", action="store_true")
    state.add_argument("--json-out")
    state.add_argument("--proof-out")
    state.set_defaults(handler=lambda args: helpers.delegate(
        "anigma_state_flow_audit.py",
        [f"--mode={args.mode}", f"--scope={args.scope}", *( [f"--target={args.target}"] if args.target else [] ), *( [f"--focus={args.focus}"] if args.focus else [] ), *(["--exclude-external-research"] if args.exclude_external_research else []), *(["--include-tests"] if args.include_tests else []), *( [f"--json-out={args.json_out}"] if args.json_out else [] ), *( [f"--proof-out={args.proof_out}"] if args.proof_out else [] )],
        args.quiet,
    ))

    zero_copy = audit_sub.add_parser("zero-copy", help="Zero-copy audit", description="Planned only if scripts/anigma_zero_copy_flow_audit.py exists; otherwise not implemented yet.")
    zero_copy.set_defaults(handler=lambda args: helpers.zero_copy(args))
