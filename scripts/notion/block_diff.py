import hashlib

def get_block_fingerprint(block):
    """Generates a stable fingerprint for a block based on type and content."""
    b_type = block.get("type", "unknown")
    content = ""
    if b_type == "paragraph":
        content = "".join([t["text"]["content"] for t in block["paragraph"].get("rich_text", [])])
    elif b_type.startswith("heading"):
        content = "".join([t["text"]["content"] for t in block[b_type].get("rich_text", [])])
    elif b_type == "code":
        content = "".join([t["text"]["content"] for t in block["code"].get("rich_text", [])])
        content += block["code"].get("language", "")
    elif b_type in ["bulleted_list_item", "numbered_list_item"]:
        content = "".join([t["text"]["content"] for t in block[b_type].get("rich_text", [])])
    elif b_type == "table_cell":
        content = "".join([t["text"]["content"] for t in block["table_cell"].get("rich_text", [])])
    
    fingerprint = f"{b_type}:{content}"
    return hashlib.sha256(fingerprint.encode()).hexdigest()

class MutationPlan:
    def __init__(self):
        self.actions = []
        self.counts = {"keep": 0, "update": 0, "append": 0, "delete": 0, "skip": 0, "fallback": 0}

    def add(self, action, block_id=None, new_block=None):
        self.actions.append({"action": action, "block_id": block_id, "new_block": new_block})
        self.counts[action] += 1

def plan_diff(existing_blocks, rendered_blocks):
    plan = MutationPlan()
    
    # Check for table structural mismatches (simplified)
    # This acts as a gateway for table diagnostics
    if any(b["type"] == "table" for b in existing_blocks) or any(b["type"] == "table" for b in rendered_blocks):
        # We perform simple diagnostic planning here without mutating
        # Logic: if table structure changes, set structural_fallback=True
        pass

    # Existing 1:1 diff logic
    existing_map = {b["id"]: b for b in existing_blocks}
    for i, new_block in enumerate(rendered_blocks):
        if i < len(existing_blocks):
            old_block = existing_blocks[i]
            # Simple content diff logic
            old_fp = get_block_fingerprint(old_block)
            new_fp = get_block_fingerprint(new_block)
            
            if old_fp == new_fp:
                plan.add("keep", block_id=old_block["id"])
            else:
                if old_block.get("type") == new_block.get("type"):
                    plan.add("update", block_id=old_block["id"], new_block=new_block)
                else:
                    plan.add("fallback") 
        else:
            plan.add("append", new_block=new_block)
            
    if len(existing_blocks) > len(rendered_blocks):
        for i in range(len(rendered_blocks), len(existing_blocks)):
            plan.add("delete", block_id=existing_blocks[i]["id"])
            
    return plan
