from __future__ import annotations


PROFILES = {
    "local-fast": "local-fast",
    "cleanup-review": "cleanup-review",
    "backend-regularization": "backend-regularization",
    "daemon-runtime": "daemon-runtime",
}


def register(subparsers, helpers):
    parser = subparsers.add_parser("doctor", help="Prebuilt workflow bundles", description="Opinionated profile runners for local validation.")
    doc_sub = parser.add_subparsers(dest="doctor_cmd", required=True)
    for name, profile in PROFILES.items():
        sub = doc_sub.add_parser(name, help=f"Run {profile} profile")
        sub.add_argument("--task", default="rig-cli-bootstrap")
        sub.add_argument("--target")
        sub.set_defaults(handler=lambda args, profile=profile: helpers.delegate(
            "anigma_pipeline.py",
            [f"run", f"--profile={profile}", f"--task={args.task}", *( [f"--target={args.target}"] if args.target else [] )],
            args.quiet,
        ))

