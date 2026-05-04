import argparse
import json
import hashlib
import sys
import os
import yaml
from pathlib import Path
from notion.client import query_database, create_page, update_page, append_block_children, create_database, update_database, get_database, search_pages, retrieve_page, get_block

REPO_ROOT = Path.cwd()

SCHEMAS = {
    "Anigma Tasks": {
        "Name": {"title": {}},
        "task_id": {"rich_text": {}},
        "status": {"select": {"options": [{"name": "RESEARCH", "color": "blue"}, {"name": "IMPLEMENTING", "color": "yellow"}, {"name": "IN_REVIEW", "color": "purple"}, {"name": "DONE", "color": "green"}]}},
        "priority": {"select": {"options": [{"name": "P0", "color": "red"}, {"name": "P1", "color": "yellow"}]}},
        "artifact_type": {"select": {"options": [{"name": "Code", "color": "purple"}]}},
        "source_path": {"rich_text": {}},
        "proof_path": {"rich_text": {}},
        "rendered_hash": {"rich_text": {}},
        "stale": {"checkbox": {}},
        "last_published_at": {"date": {}}
    },
    "Anigma Proofs": {
        "Name": {"title": {}},
        "proof_id": {"rich_text": {}},
        "task_id": {"rich_text": {}},
        "artifact_type": {"select": {"options": [{"name": "Code", "color": "purple"}]}},
        "source_path": {"rich_text": {}},
        "proof_path": {"rich_text": {}},
        "rendered_hash": {"rich_text": {}},
        "stale": {"checkbox": {}},
        "last_published_at": {"date": {}}
    },
    "Anigma Reports": {
        "Name": {"title": {}},
        "report_id": {"rich_text": {}},
        "report_type": {"select": {"options": [{"name": "alignment-matrix", "color": "blue"}]}},
        "p0_count": {"number": {"format": "number"}},
        "p1_count": {"number": {"format": "number"}},
        "p2_count": {"number": {"format": "number"}},
        "info_count": {"number": {"format": "number"}},
        "pass": {"checkbox": {}},
        "report_path": {"rich_text": {}},
        "rendered_hash": {"rich_text": {}},
        "last_published_at": {"date": {}}
    },
    "Anigma Relationships": {
        "Name": {"title": {}},
        "edge_id": {"rich_text": {}},
        "source": {"rich_text": {}},
        "target": {"rich_text": {}},
        "relationship": {"select": {"options": [{"name": "imports", "color": "blue"}]}},
        "severity": {"select": {"options": [{"name": "P0", "color": "red"}, {"name": "P1", "color": "yellow"}]}},
        "status": {"select": {"options": [{"name": "ACTIVE", "color": "green"}]}},
        "source_path": {"rich_text": {}},
        "rendered_hash": {"rich_text": {}},
        "last_published_at": {"date": {}}
    },
    "Anigma Diagrams": {
        "Name": {"title": {}},
        "diagram_id": {"rich_text": {}},
        "diagram_type": {"select": {"options": [{"name": "mermaid", "color": "blue"}, {"name": "svg", "color": "purple"}]}},
        "source_path": {"rich_text": {}},
        "rendered_path": {"rich_text": {}},
        "related_report": {"rich_text": {}},
        "related_task": {"rich_text": {}},
        "rendered_hash": {"rich_text": {}},
        "stale": {"checkbox": {}},
        "last_published_at": {"date": {}}
    }
}

def find_parent(args):
    results = search_pages(args.title)
    found = [p for p in results.get("results", []) if p.get("object") == "page"]
    
    if not found:
        print(f"No page found with title '{args.title}'. Please create it manually and share with Anigma integration.")
        return
    
    for p in found:
        print(f"Found page: {p['id']}")

def bootstrap_schema(args):
    parent_id = os.environ.get("NOTION_COCKPIT_PARENT_PAGE_ID")
    if not parent_id:
        print("Error: NOTION_COCKPIT_PARENT_PAGE_ID not set.")
        return
    
    try:
        parent = retrieve_page(parent_id)
        if parent.get("object") != "page":
            print(f"Invalid parent: expected page_id, got {parent.get('object', 'unknown')}.")
            return
    except Exception as e:
        print(f"Error validating parent: {e}")
        return

    for name, schema in SCHEMAS.items():
        db_id = os.environ.get(f"NOTION_{name.upper().replace(' ', '_')}_DATABASE_ID")
        if args.dry_run or args.emit_json:
            print(f"Would bootstrap {name}: {schema}")
        elif db_id:
            update_database(db_id, schema)
            print(f"Updated {name}")
        else:
            new_db = create_database(parent_id, name, schema)
            print(f"Created {name}: {new_db['id']}")

def inspect_schema(args):
    db_id = os.environ.get(f"NOTION_{args.database.upper()}_DATABASE_ID")
    db = get_database(db_id)
    print(json.dumps(db['properties'], indent=2))
    (REPO_ROOT / "Docs" / "td" / "index" / f"notion-schema-{args.database}.json").write_text(json.dumps(db['properties'], indent=2))

def upsert_entry(db_id, prop_name, stable_id, properties):
    existing = query_database(db_id, {"property": prop_name, "rich_text": {"equals": stable_id}})
    if existing["results"]:
        page_id = existing["results"][0]["id"]
        update_page(page_id, properties)
        return page_id, "updated"
    else:
        full_props = properties.copy()
        full_props[prop_name] = {"rich_text": [{"text": {"content": stable_id}}]}
        new_page = create_page(db_id, full_props, "database_id")
        return new_page["id"], "created"

def sync_task(args):
    db_id = os.environ.get("NOTION_TASKS_DATABASE_ID")
    index_path = REPO_ROOT / "Docs" / "td" / "index" / "tasks.jsonl"
    if not index_path.exists(): return
    with open(index_path, "r") as f:
        for line in f:
            task = json.loads(line)
            if getattr(args, 'task_id', None) and task["task_id"] != args.task_id: continue
            
            props = {
                "Name": {"title": [{"text": {"content": task["name"]}}]},
                "status": {"select": {"name": task["status"]}},
                "priority": {"select": {"name": task["priority"]}},
                "artifact_type": {"select": {"name": "Code"}}
            }
            
            if args.dry_run or args.emit_json:
                print(f"Dry-run/Emit task {task['task_id']}: {task}")
            else:
                pid, action = upsert_entry(db_id, "task_id", task["task_id"], props)
                print(f"Task {task['task_id']} {action}: {pid}")

def sync_proof(args):
    db_id = os.environ.get("NOTION_PROOFS_DATABASE_ID")
    index_path = REPO_ROOT / "Docs" / "td" / "index" / "proofs.jsonl"
    if not index_path.exists(): return
    with open(index_path, "r") as f:
        for line in f:
            proof = json.loads(line)
            if hasattr(args, 'proof_id') and args.proof_id and proof["proof_id"] != args.proof_id: continue
            
            md_path = REPO_ROOT / "Docs" / "proofs" / f"{proof['proof_id']}.md"
            props = {
                "Name": {"title": [{"text": {"content": proof["name"]}}]},
                "rendered_hash": {"rich_text": [{"text": {"content": proof.get("rendered_hash", "n/a")}}]}
            }
            
            if args.dry_run or args.emit_json:
                print(f"Dry-run/Emit proof {proof['proof_id']}")
            else:
                pid, action = upsert_entry(db_id, "proof_id", proof["proof_id"], props)
                if action == "created":
                    blocks = map_md_to_blocks(md_path.read_text())
                    append_block_children(pid, blocks)
                print(f"Proof {proof['proof_id']} {action}: {pid}")

def sync_report(args):
    db_id = os.environ.get("NOTION_REPORTS_DATABASE_ID")
    index_path = REPO_ROOT / "Docs" / "td" / "index" / "reports.jsonl"
    if not index_path.exists(): return
    with open(index_path, "r") as f:
        for line in f:
            rep = json.loads(line)
            if hasattr(args, 'type') and args.type and rep["report_type"] != args.type: continue
            
            props = {
                "Name": {"title": [{"text": {"content": rep["name"]}}]},
                "report_id": {"rich_text": [{"text": {"content": rep["report_id"]}}]},
                "report_type": {"select": {"name": rep["report_type"]}},
                "p0_count": {"number": rep["p0"]},
                "p1_count": {"number": rep["p1"]},
                "p2_count": {"number": rep["p2"]},
                "info_count": {"number": rep["info"]},
                "pass": {"checkbox": rep["pass"]}
            }
            
            if args.dry_run or args.emit_json:
                print(f"Dry-run/Emit report {rep['report_id']}")
            else:
                pid, action = upsert_entry(db_id, "report_id", rep["report_id"], props)
                print(f"Report {rep['report_id']} {action}: {pid}")

def sync_relationships(args):
    db_id = os.environ.get("NOTION_RELATIONSHIPS_DATABASE_ID")
    index_path = REPO_ROOT / "Docs" / "td" / "index" / "relationships.jsonl"
    if not index_path.exists(): return
    with open(index_path, "r") as f:
        for line in f:
            rel = json.loads(line)
            props = {
                "Name": {"title": [{"text": {"content": rel["edge_id"]}}]},
                "edge_id": {"rich_text": [{"text": {"content": rel["edge_id"]}}]},
                "source": {"rich_text": [{"text": {"content": rel["from"]}}]},
                "target": {"rich_text": [{"text": {"content": rel["to"]}}]},
                "relationship": {"select": {"name": rel["relationship"]}},
                "severity": {"select": {"name": rel["severity"]}}
            }
            
            if args.dry_run or args.emit_json:
                print(f"Dry-run/Emit rel {rel['edge_id']}")
            else:
                pid, action = upsert_entry(db_id, "edge_id", rel["edge_id"], props)
                print(f"Rel {rel['edge_id']} {action}: {pid}")

def sync_diagrams(args):
    db_id = os.environ.get("NOTION_DIAGRAMS_DATABASE_ID")
    index_path = REPO_ROOT / "Docs" / "td" / "index" / "diagrams.jsonl"
    if not index_path.exists(): return
    with open(index_path, "r") as f:
        for line in f:
            dia = json.loads(line)
            props = {
                "Name": {"title": [{"text": {"content": dia["name"]}}]},
                "diagram_id": {"rich_text": [{"text": {"content": dia["diagram_id"]}}]},
                "diagram_type": {"select": {"name": dia["diagram_type"]}}
            }
            if args.dry_run or args.emit_json:
                print(f"Dry-run/Emit diagram {dia['diagram_id']}")
            else:
                pid, action = upsert_entry(db_id, "diagram_id", dia["diagram_id"], props)
                print(f"Diagram {dia['diagram_id']} {action}: {pid}")

def sync_docs_site(args):
    parent_id = os.environ.get("NOTION_DOCS_SITE_PARENT_PAGE_ID")
    if not parent_id:
        print("Error: NOTION_DOCS_SITE_PARENT_PAGE_ID not set.")
        return

    manifest_path = REPO_ROOT / "Docs" / "publishing" / "notion-docs-site-manifest.yaml"
    with open(manifest_path, "r") as f:
        manifest = yaml.safe_load(f)

    for page in manifest["pages"]:
        if page["visibility"] != "public_candidate": continue
        source_file = REPO_ROOT / page["source"]
        if not source_file.exists(): continue
        
        blocks = map_md_to_blocks(source_file.read_text())
        
        if args.dry_run or args.emit_json:
            print(f"Would sync page: {page['title']}")
        else:
            new_page = create_page(parent_id, {"title": {"title": [{"text": {"content": page['title']}}]}}, "page_id")
            for block in blocks:
                try:
                    append_block_children(new_page["id"], [block])
                except Exception as e:
                    print(f"Failed to append block: {block}, error: {e}")
            print(f"Synced page: {page['title']} (ID: {new_page['id']})")

def sync_all(args):
    sync_task(args)
    sync_proof(args)
    sync_report(args)
    sync_relationships(args)
    sync_diagrams(args)

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
            lang = line[3:].strip() or "plain text"
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_content.append(lines[i])
                i += 1
            block["type"] = "code"
            block["code"] = {"rich_text": [{"type": "text", "text": {"content": "\n".join(code_content)}}], "language": lang}
        else:
            block["type"] = "paragraph"
            block["paragraph"] = {"rich_text": [{"type": "text", "text": {"content": line}}]}
        blocks.append(block)
        i += 1
    return blocks

def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")
    
    for cmd in ["sync-task", "sync-proof", "sync-report", "sync-relationships", "sync-all", "bootstrap-schema", "inspect-schema", "find-parent", "sync-docs-site", "sync-diagrams"]:
        p = subparsers.add_parser(cmd)
        p.add_argument("--publish", action="store_true")
        p.add_argument("--dry-run", action="store_true")
        p.add_argument("--emit-json", action="store_true")
        if cmd == "sync-task": p.add_argument("--task-id")
        if cmd == "sync-proof": p.add_argument("--proof-id")
        if cmd == "sync-report": p.add_argument("--type")
        if cmd == "inspect-schema": p.add_argument("--database", required=True)
        if cmd == "find-parent": p.add_argument("--title", required=True)
        
    args = parser.parse_args()
    
    if not args.publish and not args.emit_json and args.command not in ["inspect-schema", "bootstrap-schema", "find-parent"]:
        args.dry_run = True

    if args.command == "sync-task": sync_task(args)
    elif args.command == "sync-proof": sync_proof(args)
    elif args.command == "sync-report": sync_report(args)
    elif args.command == "sync-relationships": sync_relationships(args)
    elif args.command == "sync-all": sync_all(args)
    elif args.command == "bootstrap-schema": bootstrap_schema(args)
    elif args.command == "inspect-schema": inspect_schema(args)
    elif args.command == "find-parent": find_parent(args)
    elif args.command == "sync-docs-site": sync_docs_site(args)
    elif args.command == "sync-diagrams": sync_diagrams(args)
    else: parser.print_help()

if __name__ == "__main__":
    main()
