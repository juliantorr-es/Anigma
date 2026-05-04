import argparse
import json
import os
import sys
import subprocess
from pathlib import Path

REPO_ROOT = Path.cwd()
MANIFEST_PATH = REPO_ROOT / "Docs" / "publishing" / "diagrams.jsonl"
DERIVED_DIR = REPO_ROOT / "Docs" / "diagrams" / "derived"
SOURCE_DIR = REPO_ROOT / "Docs" / "diagrams" / "source"

def find_mmdc():
    # Check PATH
    mmdc_path = subprocess.run(["which", "mmdc"], capture_output=True, text=True).stdout.strip()
    if mmdc_path:
        return mmdc_path
    # Check local node_modules
    local_mmdc = REPO_ROOT / "node_modules" / ".bin" / "mmdc"
    if local_mmdc.exists():
        return str(local_mmdc)
    return None

def validate_manifest():
    if not MANIFEST_PATH.exists():
        print(f"Error: Manifest not found at {MANIFEST_PATH}")
        sys.exit(1)
    
    seen_outputs = set()
    seen_svg_outputs = set()
    manifest_entries = []
    
    with open(MANIFEST_PATH, "r") as f:
        for line_num, line in enumerate(f, 1):
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                print(f"Error: Malformed JSONL at line {line_num}")
                sys.exit(1)
            
            for field in ["source_path", "rendered_path", "diagram_id"]:
                if field not in entry:
                    print(f"Error: Missing field '{field}' at line {line_num}")
                    sys.exit(1)
            
            src = REPO_ROOT / entry["source_path"]
            out = REPO_ROOT / entry["rendered_path"]
            svg_out = REPO_ROOT / entry.get("svg_output", out.with_suffix(".svg"))
            
            if not src.exists():
                print(f"Error: Source file {src} does not exist (line {line_num})")
                sys.exit(1)
                
            if not str(out).startswith(str(DERIVED_DIR)):
                print(f"Error: Output path {out} is not under {DERIVED_DIR} (line {line_num})")
                sys.exit(1)

            if not str(svg_out).startswith(str(DERIVED_DIR)):
                print(f"Error: SVG output path {svg_out} is not under {DERIVED_DIR} (line {line_num})")
                sys.exit(1)
                
            if out in seen_outputs:
                print(f"Error: Duplicate output path {out} (line {line_num})")
                sys.exit(1)
            if svg_out in seen_svg_outputs:
                print(f"Error: Duplicate SVG output path {svg_out} (line {line_num})")
                sys.exit(1)
            
            seen_outputs.add(out)
            seen_svg_outputs.add(svg_out)
            manifest_entries.append(entry)
            
    return manifest_entries

def render(args):
    entries = validate_manifest()
    mmdc = find_mmdc()
    
    for entry in entries:
        src_path = REPO_ROOT / entry["source_path"]
        out_path = REPO_ROOT / entry["rendered_path"]
        svg_out = REPO_ROOT / entry.get("svg_output", out_path.with_suffix(".svg"))
        
        out_path.parent.mkdir(parents=True, exist_ok=True)
        svg_out.parent.mkdir(parents=True, exist_ok=True)
        
        if not args.markdown_only:
            if mmdc:
                try:
                    subprocess.run([mmdc, "-i", str(src_path), "-o", str(svg_out)], check=True, capture_output=True, text=True)
                    print(f"Rendered SVG: {svg_out}")
                except subprocess.CalledProcessError as e:
                    print(f"Error rendering SVG for {entry['diagram_id']}: {e.stderr}")
                    if args.strict_svg:
                        sys.exit(1)
            else:
                msg = f"Warning: Mermaid CLI (mmdc) not found. Skipping SVG rendering for {entry['diagram_id']}"
                if args.svg and args.strict_svg:
                    print(f"Error: {msg}")
                    sys.exit(1)
                else:
                    print(msg)
        
        if not args.svg or args.markdown_only:
            content = src_path.read_text()
            md_content = f"""<!-- GENERATED FILE: DO NOT EDIT DIRECTLY. -->
<!-- Canonical source: {entry['source_path']} -->
# {entry['name']}
Source: `{entry['source_path']}`

```mermaid
{content}
```
"""
            out_path.write_text(md_content)
            print(f"Rendered Markdown: {out_path}")
        else:
            print(f"Validated: {entry['diagram_id']}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--svg", action="store_true")
    parser.add_argument("--strict-svg", action="store_true")
    parser.add_argument("--markdown-only", action="store_true")
    args = parser.parse_args()
    
    if args.check:
        validate_manifest()
        print("Manifest validated successfully.")
    else:
        render(args)

if __name__ == "__main__":
    main()
