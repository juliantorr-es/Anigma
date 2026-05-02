#!/usr/bin/env python3

import json
from pathlib import Path

# Fix project config
project_config_path = Path("opencode.json")
if project_config_path.exists():
    with open(project_config_path, 'r') as f:
        config = json.load(f)
    
    # Remove unsupported keys
    if 'context' in config:
        del config['context']
    if 'agents' in config:
        del config['agents']
    if 'tools' in config:
        del config['tools']
    
    with open(project_config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"✅ Fixed project config: {project_config_path}")

# Fix global config
global_config_path = Path.home() / ".config" / "opencode" / "config.json"
if global_config_path.exists():
    with open(global_config_path, 'r') as f:
        config = json.load(f)
    
    # Remove unsupported keys
    if 'context' in config:
        del config['context']
    if 'agents' in config:
        del config['agents']
    if 'tools' in config:
        del config['tools']
    
    with open(global_config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"✅ Fixed global config: {global_config_path}")

print("\n🎉 OpenCode configuration fixed!")
print("📋 Try again with: opencode")