import argparse
import json
import hashlib
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path

# Constants
REPO_ROOT = Path(os.environ.get("REPO_ROOT", Path.cwd()))
NOTION_API_URL = "https://api.notion.com/v1"

def get_markdown_hash(md_path):
    return hashlib.sha256(md_path.read_bytes()).hexdigest()

def notion_request(endpoint, method="GET", data=None):
    token = os.environ.get("NOTION_TOKEN")
    if not token:
        raise ValueError("NOTION_TOKEN environment variable not set")
    
    url = f"{NOTION_API_URL}/{endpoint}"
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Notion-Version", "2022-06-28")
    req.add_header("Content-Type", "application/json")
    
    if data:
        encoded_data = json.dumps(data).encode("utf-8")
        req.data = encoded_data
    
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"Notion API error: {e.read().decode('utf-8')}")
        raise

def map_md_to_blocks(md_content):
    blocks = []
    lines = md_content.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
            
        block = {"object": "block"}
        if line.startswith("# "):
            block["type"] = "heading_1"
            block["heading_1"] = {"rich_text": [{"type": "text", "text": {"content": line[2:]}}]}
        elif line.startswith("## "):
            block["type"] = "heading_2"
            block["heading_2"] = {"rich_text": [{"type": "text", "text": {"content": line[3:]}}]}
        elif line.startswith("### "):
            block["type"] = "heading_3"
            block["heading_3"] = {"rich_text": [{"type": "text", "text": {"content": line[4:]}}]}
        elif line.startswith("- "):
            block["type"] = "bulleted_list_item"
            block["bulleted_list_item"] = {"rich_text": [{"type": "text", "text": {"content": line[2:]}}]}
        elif line.startswith("1. "):
            block["type"] = "numbered_list_item"
            block["numbered_list_item"] = {"rich_text": [{"type": "text", "text": {"content": line[3:]}}]}
        elif line.startswith("---"):
            block["type"] = "divider"
            block["divider"] = {}
        elif line.startswith("```"):
            code_content = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_content.append(lines[i])
                i += 1
            block["type"] = "code"
            block["code"] = {"rich_text": [{"type": "text", "text": {"content": "\n".join(code_content)}}], "language": "plain text"}
        else:
            block["type"] = "paragraph"
            block["paragraph"] = {"rich_text": [{"type": "text", "text": {"content": line}}]}
        blocks.append(block)
        i += 1
    return blocks

def main():
    parser = argparse.ArgumentParser(description="Anigma Notion Publisher")
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--emit-json", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--database-id")
    parser.add_argument("--allow-stale", action="store_true")
    parser.add_argument("--replace-body", action="store_true")

    args = parser.parse_args()
    db_id = args.database_id or os.environ.get("NOTION_DATABASE_ID")

    json_path = REPO_ROOT / "Docs" / "td" / "artifacts" / args.task_id / "proof.json"
    md_path = REPO_ROOT / "Docs" / "proofs" / f"{args.task_id}.md"

    if not json_path.exists() or not md_path.exists():
        print(f"Required files missing: {json_path}, {md_path}")
        sys.exit(1)
    
    with open(json_path, "r") as f:
        data = json.load(f)

    md_hash = get_markdown_hash(md_path)
    
    # Metadata for Notion
    metadata = {
        "Name": {"title": [{"text": {"content": data.get("title", args.task_id)}}]},
        "task_id": {"rich_text": [{"text": {"content": args.task_id}}]},
        "status": {"select": {"name": data.get("status", "RESEARCH")}},
        "rendered_hash": {"rich_text": [{"text": {"content": md_hash}}]}
    }

    if args.emit_json:
        print(json.dumps({"metadata": metadata, "blocks": map_md_to_blocks(md_path.read_text())}, indent=2))
        return

    # Check/Publish Mode
    if args.publish or args.check:
        if not db_id or not os.environ.get("NOTION_TOKEN"):
            print("Error: NOTION_TOKEN and NOTION_DATABASE_ID required.")
            sys.exit(1)
            
        query = {"filter": {"property": "task_id", "rich_text": {"equals": args.task_id}}}
        pages = notion_request(f"databases/{db_id}/query", "POST", query)
        existing_page = pages["results"][0] if pages["results"] else None

        if args.check:
            if not existing_page:
                print("Row missing.")
                sys.exit(1)
            h_prop = existing_page["properties"].get("rendered_hash")
            if not h_prop or not h_prop["rich_text"] or h_prop["rich_text"][0]["text"]["content"] != md_hash:
                print("Hash mismatch.")
                sys.exit(1)
            print("Check passed.")
            return

        if args.publish:
            if existing_page:
                notion_request(f"pages/{existing_page['id']}", "PATCH", {"properties": metadata})
                print("Updated page properties.")
                # Append/Replace body logic goes here
            else:
                page = notion_request("pages", "POST", {
                    "parent": {"database_id": db_id},
                    "properties": metadata
                })
                print("Created page.")
    else:
        print("Dry run mode (default). Pass --publish to execute live.")
        print(f"Metadata: {json.dumps(metadata, indent=2)}")

if __name__ == "__main__":
    main()
