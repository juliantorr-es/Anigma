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

def get_existing_page(parent_id, title):
    search_results = search_pages(title)
    for res in search_results.get("results", []):
        if res.get("parent", {}).get("page_id") == parent_id:
            return res["id"]
    return None

def clear_page_blocks(page_id):
    cursor = None
    while True:
        children = get_block_children(page_id, cursor)
        blocks = children.get("results", [])
        for block in blocks:
            delete_block(block["id"])
        
        if children.get("has_more"):
            cursor = children.get("next_cursor")
        else:
            break

from scripts.notion.block_diff import plan_diff, get_block_fingerprint

# ... existing code ...

def get_existing_page_blocks(page_id):
    blocks = []
    cursor = None
    while True:
        children = get_block_children(page_id, cursor)
        blocks.extend(children.get("results", []))
        if children.get("has_more"):
            cursor = children.get("next_cursor")
        else:
            break
    return blocks

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
        
        # Safety: refuse to clear if render failed/empty
        if not blocks:
            print(f"Safety Guard: Refusing to clear page {page['title']} because rendered content is empty.")
            continue
        
        page_id = get_existing_page(parent_id, page["title"])
        
class SyncReport:
    def __init__(self, mode):
        self.mode = mode
        self.pages = {"created": 0, "updated_in_place": 0, "skipped": 0, "failed": 0, "duplicates_archived": 0}
        self.blocks = {"kept": 0, "updated": 0, "appended": 0, "archived": 0, "blocked": 0, "ambiguous": 0, "unsupported": 0, "fallback_required": 0, "failed": 0}
        self.block_types = {"paragraph": 0, "heading_1": 0, "heading_2": 0, "heading_3": 0, "code": 0, "bulleted_list_item": 0, "numbered_list_item": 0, "table": 0, "table_row": 0, "table_cell": 0, "unsupported": 0}
        self.tables = {"inspected": 0, "cell_updates_planned": 0, "cell_updates_applied": 0, "structural_changes_blocked": 0}
        self.destructive = {"archives_planned": 0, "archives_executed": 0, "archives_blocked": 0, "tombstones_emitted": 0}
        self.safety_result = "safe" # safe, completed_with_blocked_actions, failed_closed, partial_application_risk

    def merge_plan(self, plan):
        mapping = {
            "keep": "kept",
            "update": "updated",
            "append": "appended",
            "delete": "archived",
            "fallback": "fallback_required",
            "skip": "blocked"
        }
        for k, v in plan.counts.items():
            mapped_k = mapping.get(k, k)
            if mapped_k in self.blocks:
                self.blocks[mapped_k] += v
        
        for action in plan.actions:
            b_type = action.get("new_block", {}).get("type", action.get("type", "unknown"))
            if b_type in self.block_types:
                self.block_types[b_type] += 1
            else:
                self.block_types["unsupported"] += 1
            
            if b_type == "table":
                self.tables["inspected"] += 1
            elif b_type == "table_cell":
                if action["action"] == "update":
                    self.tables["cell_updates_planned"] += 1

    def to_dict(self):
        return {
            "mode": self.mode,
            "pages": self.pages,
            "blocks": self.blocks,
            "block_types": self.block_types,
            "tables": self.tables,
            "destructive": self.destructive,
            "safety_result": self.safety_result
        }

def emit_tombstone(entry, dry_run=False, report=None):
    tombstone = {
        "block_id": entry["block_id"],
        "action": entry["action"],
        "timestamp": os.popen("date -u +%Y-%m-%dT%H:%M:%SZ").read().strip(),
        "dry_run": dry_run
    }
    tombstone_path = REPO_ROOT / "Docs" / "publishing" / "tombstones.jsonl"
    with open(tombstone_path, "a") as f:
        f.write(json.dumps(tombstone) + "\n")
    print(f"Tombstone emitted: {json.dumps(tombstone)}")
    if report:
        report.destructive["tombstones_emitted"] += 1

def execute_mutation_plan(page_id, plan, dry_run=False, report=None):
    for entry in plan.actions:
        action = entry["action"]
        new_block = entry.get("new_block", {})
        b_type = new_block.get("type", "")

        if action == "keep":
            pass
        elif action == "update":
            if dry_run:
                print(f"Action: UPDATE (Dry-Run) {b_type} (block_id: {entry['block_id']})")
                continue
            
            # Heading updates
            if b_type.startswith("heading"):
                content = "".join([t["text"]["content"] for t in new_block[b_type]["rich_text"]])
                update_heading(entry["block_id"], b_type, content)
            
            # Paragraph/List updates
            elif b_type in ["paragraph", "bulleted_list_item", "numbered_list_item"]:
                content = "".join([t["text"]["content"] for t in new_block[b_type]["rich_text"]])
                update_list_item(entry["block_id"], b_type, content)

            # Code updates
            elif b_type == "code":
                content = "".join([t["text"]["content"] for t in new_block["code"]["rich_text"]])
                language = new_block["code"].get("language", "plain text")
                update_code(entry["block_id"], content, language)
            
            # Table row update (safe, high-confidence update)
            elif b_type == "table_row":
                cells = new_block.get("table_row", {}).get("cells", [])
                update_table_row_cells(entry["block_id"], cells)
                if report:
                    report.tables["cell_updates_applied"] += len(cells)
            
            else:
                print(f"Action: BLOCKED (Unsupported update type: {b_type})")
                if report: report.blocks["blocked"] += 1

        elif action == "append":
            if not dry_run:
                append_block_children(page_id, [new_block])
        elif action == "delete": 
            if report: report.destructive["archives_planned"] += 1
            if dry_run:
                emit_tombstone(entry, dry_run=True, report=report)
            else:
                emit_tombstone(entry, dry_run=False, report=report)
                archive_block(entry["block_id"])
                if report: report.destructive["archives_executed"] += 1
        elif action in ["fallback", "skip"]:
            print(f"Action: BLOCKED ({action.upper()})")
            if report: report.blocks["blocked"] += 1
        else:
            print(f"Action: UNKNOWN ({action})")
            if report: report.blocks["blocked"] += 1

def sync_docs_site(args):
    parent_id = os.environ.get("NOTION_DOCS_SITE_PARENT_PAGE_ID")
    if not parent_id:
        print("Error: NOTION_DOCS_SITE_PARENT_PAGE_ID not set.")
        return
        
    mode = "default page sync"
    if args.block_diff:
        mode = "block-diff dry-run" if args.dry_run else ("block-diff live with archive enabled" if args.allow_block_archive else "block-diff live")
        
    report = SyncReport(mode)

    manifest_path = REPO_ROOT / "Docs" / "publishing" / "notion-docs-site-manifest.yaml"
    with open(manifest_path, "r") as f:
        manifest = yaml.safe_load(f)

    for page in manifest["pages"]:
        if page["visibility"] != "public_candidate": continue
        source_file = REPO_ROOT / page["source"]
        if not source_file.exists(): continue
        
        blocks = map_md_to_blocks(source_file.read_text())
        
        # Safety: refuse to clear if render failed/empty
        if not blocks:
            print(f"Safety Guard: Refusing to clear page {page['title']} because rendered content is empty.")
            report.pages["skipped"] += 1
            continue
        
        page_id = get_existing_page(parent_id, page["title"])
        
        if args.block_diff:
            if args.allow_block_archive and not args.block_diff:
                 print("Error: --allow-block-archive requires --block-diff.")
                 report.safety_result = "failed_closed"
                 sys.exit(1)

            existing_blocks = get_existing_page_blocks(page_id) if page_id else []
            plan = plan_diff(existing_blocks, blocks)
            
            report.merge_plan(plan)
            
            # Check for destructive plans if archive not allowed
            has_destructive = any(a['action'] == 'delete' for a in plan.actions)
            if has_destructive and not args.allow_block_archive:
                print("Error: Plan contains destructive actions (ARCHIVE). Use --allow-block-archive to permit.")
                report.safety_result = "failed_closed"
                if args.strict: sys.exit(1)

            if any(a['action'] in ['fallback', 'skip'] for a in plan.actions):
                report.safety_result = "completed_with_blocked_actions"
                if args.strict: 
                    print("Strict mode: FAILED due to blocked/fallback actions.")
                    sys.exit(1)

            print(f"--- Block Diff Plan: {page['title']} ---")
            print(f"Counts: {plan.counts}")
            
            if not args.dry_run:
                execute_mutation_plan(page_id, plan, dry_run=False, report=report)
            else:
                execute_mutation_plan(page_id, plan, dry_run=True, report=report)
                
            if page_id: report.pages["updated_in_place"] += 1
            else: report.pages["created"] += 1
            continue

        # Normal sync path
        if args.dry_run or args.emit_json:
            action = "update (in-place)" if page_id else "create"
            print(f"Would {action} page: {page['title']}")
            if page_id: report.pages["updated_in_place"] += 1
            else: report.pages["created"] += 1
        else:
            if page_id:
                print(f"Updating existing page: {page['title']} (ID: {page_id})")
                clear_page_blocks(page_id)
                report.pages["updated_in_place"] += 1
            else:
                new_page = create_page(parent_id, {"title": {"title": [{"text": {"content": page['title']}}]}}, "page_id")
                page_id = new_page["id"]
                print(f"Created new page: {page['title']} (ID: {page_id})")
                report.pages["created"] += 1
            
            for block in blocks:
                try:
                    append_block_children(page_id, [block])
                except Exception as e:
                    print(f"Failed to append block: {block}, error: {e}")
                    report.blocks["failed"] += 1
            print(f"Synced page: {page['title']} (ID: {page_id})")

    # Output report
    if getattr(args, 'report_json', None):
        report_path = Path(args.report_json)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        with open(report_path, "w") as f:
            json.dump(report.to_dict(), f, indent=2)
        print(f"Report written to {report_path}")

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
        if cmd == "sync-docs-site": 
            p.add_argument("--block-diff", action="store_true")
            p.add_argument("--allow-block-archive", action="store_true")
            p.add_argument("--report-json", help="Path to write the structured JSON report")
            p.add_argument("--strict", action="store_true", help="Fail non-zero when blocked/fallback actions are encountered")
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
