#!/bin/bash
#
# Anigma Agent Context Bootstrap
# Provides deterministic context packet for external coding agents
# Usage: ./scripts/anigma_agent_context.sh <task-id>
#

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <task-id>"
    echo "Example: $0 td-a84da2"
    exit 1
fi

TASK_ID="$1"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TD_REGISTRY="$PROJECT_ROOT/Docs/td/td-task-registry.yaml"

# Check if task exists in registry
echo "🔍 Looking up task: $TASK_ID"

if [ ! -f "$TD_REGISTRY" ]; then
    echo "❌ TD registry not found: $TD_REGISTRY"
    exit 1
fi

# Use Python to extract task info since parsing YAML in bash is fragile
TASK_INFO=$(python3 -c "
import yaml
import sys
from pathlib import Path

registry_path = Path('$TD_REGISTRY')
with open(registry_path, 'r') as f:
    registry = yaml.safe_load(f)

task_id = '$TASK_ID'
task = None
for t in registry.get('tasks', []):
    if t.get('id') == task_id:
        task = t
        break

if not task:
    print('NOT_FOUND')
    sys.exit(0)

# Find parent epic
epic = None
if task.get('parent'):
    for t in registry.get('tasks', []):
        if t.get('id') == task.get('parent'):
            epic = t
            break

# Find lane definition
lane_id = task.get('lane', '')
lane = None
for l in registry.get('lanes', {}).values():
    if l.get('id') == lane_id:
        lane = l
        break

# Output task info
print(f'TASK_ID:{task_id}')
print(f'TITLE:{task.get(\"title\", \"\")}')
print(f'PRIORITY:{task.get(\"priority\", \"P1\")}')
print(f'TYPE:{task.get(\"type\", \"task\")}')
print(f'STATUS:{task.get(\"status\", \"ready\")}')
if epic:
    print(f'EPIC_ID:{epic.get(\"id\", \"\")}')
    print(f'EPIC_TITLE:{epic.get(\"title\", \"\")}')
if lane:
    print(f'LANE_ID:{lane.get(\"id\", \"\")}')
    print(f'LANE_TITLE:{lane.get(\"title\", \"\")}')
    print(f'WORKTREE:{lane.get(\"worktree\", \"anigma/\")}')

# Output required reading
print('REQUIRED_READING_START')
print('$PROJECT_ROOT/README.md')
print('$PROJECT_ROOT/Docs/architecture/DOCTRINE_INDEX.md')
print('$PROJECT_ROOT/Docs/roadmap/ROADMAP_INDEX.md')
print('$PROJECT_ROOT/Docs/td/README.md')

# Output task-specific files
for doc in task.get('source_docs', []):
    print(f'$PROJECT_ROOT/{doc}')

print('REQUIRED_READING_END')

# Output validators
print('VALIDATORS_START')
if 'validator_commands' in task:
    for cmd in task.get('validator_commands', []):
        print(cmd)
else:
    # Default validators
    print('python3 scripts/validate_td_docs_sync.py')
    print('python3 scripts/validate_td_folder_system.py')
    print('python3 scripts/validate_tiers.py')
print('VALIDATORS_END')

# Output proof requirement
print('PROOF_REQUIREMENT_START')
if 'proof_required' in task:
    for proof in task.get('proof_required', []):
        print(proof)
else:
    print(f'Docs/proofs/{task_id}.md')
print('PROOF_REQUIREMENT_END')
" 2>/dev/null || echo "NOT_FOUND")

if [ "$TASK_INFO" = "NOT_FOUND" ]; then
    echo "❌ Task not found in registry: $TASK_ID"
    echo "Available tasks:"
    python3 -c "
import yaml
from pathlib import Path
registry_path = Path('$TD_REGISTRY')
with open(registry_path, 'r') as f:
    registry = yaml.safe_load(f)
for task in registry.get('tasks', []):
    print(f'  - {task.get(\"id\")}: {task.get(\"title\")}')
    "
    exit 1
fi

# Parse the task info and display nicely
echo "📋 Task Context for: $TASK_ID"
echo "================================"

# Extract fields from task info
TASK_TITLE=$(echo "$TASK_INFO" | grep "^TITLE:" | cut -d':' -f2-)
TASK_PRIORITY=$(echo "$TASK_INFO" | grep "^PRIORITY:" | cut -d':' -f2-)
TASK_TYPE=$(echo "$TASK_INFO" | grep "^TYPE:" | cut -d':' -f2-)
TASK_STATUS=$(echo "$TASK_INFO" | grep "^STATUS:" | cut -d':' -f2-)
EPIC_ID=$(echo "$TASK_INFO" | grep "^EPIC_ID:" | cut -d':' -f2-)
EPIC_TITLE=$(echo "$TASK_INFO" | grep "^EPIC_TITLE:" | cut -d':' -f2-)
LANE_ID=$(echo "$TASK_INFO" | grep "^LANE_ID:" | cut -d':' -f2-)
LANE_TITLE=$(echo "$TASK_INFO" | grep "^LANE_TITLE:" | cut -d':' -f2-)
WORKTREE=$(echo "$TASK_INFO" | grep "^WORKTREE:" | cut -d':' -f2-)

echo "Task: $TASK_ID - $TASK_TITLE"
echo "Priority: $TASK_PRIORITY | Type: $TASK_TYPE | Status: $TASK_STATUS"

if [ -n "$EPIC_ID" ]; then
    echo "Epic: $EPIC_ID - $EPIC_TITLE"
fi

if [ -n "$LANE_ID" ]; then
    echo "Lane: $LANE_ID - $LANE_TITLE"
    echo "Worktree: $WORKTREE"
fi

echo ""
echo "📚 Required Reading (in order):"
echo "--------------------------------"

# Extract required reading files
REQUIRED_READING=$(echo "$TASK_INFO" | sed -n '/REQUIRED_READING_START/,/REQUIRED_READING_END/p' | tail -n +2 | sed '$d')

while IFS= read -r file; do
    if [ -n "$file" ]; then
        relative="${file#$PROJECT_ROOT/}"
        echo "  • $relative"
    fi
done <<< "$REQUIRED_READING"

echo ""
echo "🔧 Validators:"
echo "----------------"

# Extract validators
VALIDATORS=$(echo "$TASK_INFO" | sed -n '/VALIDATORS_START/,/VALIDATORS_END/p' | tail -n +2 | sed '$d')

while IFS= read -r validator; do
    if [ -n "$validator" ]; then
        echo "  • $validator"
    fi
done <<< "$VALIDATORS"

echo ""
echo "📝 Proof Requirement:"
echo "---------------------"

# Extract proof requirement
PROOF_REQ=$(echo "$TASK_INFO" | sed -n '/PROOF_REQUIREMENT_START/,/PROOF_REQUIREMENT_END/p' | tail -n +2 | sed '$d')

while IFS= read -r proof; do
    if [ -n "$proof" ]; then
        relative="${proof#$PROJECT_ROOT/}"
        echo "  • $relative"
    fi
done <<< "$PROOF_REQ"

echo ""
echo "🎯 Agent Workflow:"
echo "------------------"
echo "1. Read all required documentation in order"
echo "2. Inspect source files referenced in docs"
echo "3. Create implementation plan"
echo "4. Make code changes"
echo "5. Run validators listed above"
echo "6. Write/update proof artifact"
echo "7. Report: changed files, validation results, proof path"

echo ""
echo "✅ Context packet generated successfully!"
