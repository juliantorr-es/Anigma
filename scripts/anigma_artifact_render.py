import argparse
import json
import subprocess
import sys
from pathlib import Path

# Constants
REPO_ROOT = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode().strip())
SCHEMA_PATH = REPO_ROOT / "Docs" / "schemas"

def validate_json(data, schema_name):
    # Basic structural validation for MVP
    # In full implementation, use jsonschema library
    if "schema" not in data:
        raise ValueError("Missing schema field")
    return True

import argparse
import json
import subprocess
import sys
from pathlib import Path

# Constants
REPO_ROOT = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode().strip())
SCHEMA_PATH = REPO_ROOT / "Docs" / "schemas"

def render_frontmatter(data):
    fm = data.get("frontmatter", {})
    if not fm:
        return ""
    
    lines = ["---"]
    lines.append(f"task_id: {data.get('taskId', 'N/A')}")
    lines.append(f"status: {data.get('status', 'N/A')}")
    lines.append(f"artifact_type: {data.get('artifactType', 'N/A')}")
    
    tags = fm.get("tags", [])
    if tags:
        lines.append("tags:")
        for t in tags:
            lines.append(f"  - {t}")
            
    lines.append("---")
    return "\n".join(lines) + "\n\n"

def render_diagrams(data):
    diagrams = data.get("diagrams", [])
    if not diagrams:
        return ""
    
    lines = ["", "## Diagrams"]
    for d in diagrams:
        lines.append(f"### {d.get('title', 'Diagram')}")
        lines.append("```mermaid")
        lines.append(d.get("content", ""))
        lines.append("```")
    return "\n".join(lines)

def render_proof(data):
    lines = [
        render_frontmatter(data),
        f"<!-- GENERATED FROM {data.get('canonicalPath', 'N/A')}. Do not edit by hand. -->",
        f"<!-- Canonical artifact: {data.get('canonicalPath', 'N/A')} -->",
        f"<!-- Renderer: Scripts/anigma_artifact_render.py -->",
        f"",
        f"# {data.get('title', 'Untitled Proof')}",
        f"",
        f"**Status**: {data.get('status', 'N/A')}",
        f"**Task ID**: {data.get('taskId', 'N/A')}",
        f"",
        f"## Summary",
        f"{data.get('summary', '_Not recorded._')}",
        f"",
        render_diagrams(data),
        f"",
        f"## Changed Files",
        f"| Path | Risk | Reason |",
        f"|---|---|---|",
    ]
    
    files = data.get("changedFiles", [])
    if files:
        for f in files:
            lines.append(f"| `{f.get('path', 'N/A')}` | {f.get('risk', 'N/A')} | {f.get('reason', 'N/A')} |")
    else:
        lines.append("_Not recorded._")
        
    lines.extend(["", "## Validation Results", "| Command | Build Status | Exit Code |", "|---|---|---|"])
    val_results = data.get("validationResults", [])
    if val_results:
        for v in val_results:
            lines.append(f"| `{v.get('command', 'N/A')}` | {v.get('buildStatus', 'N/A')} | {v.get('exitCode', 'N/A')} |")
    else:
        lines.append("_Not recorded._")
        
    lines.extend(["", "## Decisions"])
    decisions = data.get("decisions", [])
    if decisions:
        for d in decisions:
            lines.append(f"- **{d.get('decision', 'N/A')}**: {d.get('rationale', 'N/A')}")
    else:
        lines.append("_Not recorded._")

    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Anigma Artifact Renderer")
    subparsers = parser.add_subparsers(dest="mode")

    render = subparsers.add_parser("render-proof")
    render.add_argument("--input", required=True)
    render.add_argument("--output", required=True)

    args = parser.parse_args()

    if args.mode == "render-proof":
        input_path = Path(args.input).resolve()
        with open(input_path, "r") as f:
            data = json.load(f)
        
        data["canonicalPath"] = str(input_path.relative_to(REPO_ROOT))
        
        md = render_proof(data)
        
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            f.write(md)
        print(f"Rendered: {output_path}")

if __name__ == "__main__":
    main()
