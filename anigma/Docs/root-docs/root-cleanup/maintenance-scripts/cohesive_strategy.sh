#!/bin/bash

echo "Reverting cascaded tasks from in_progress to open..."

# 22 tasks
TASKS=(
  td-40a6ce td-504146 td-6a8ba1 td-767f43 # Database
  td-763a08 td-bc72c4 td-003af2 td-dd97e2 # Ingest/Privacy
  td-c71ebd td-765514 td-85cd14 td-1952e5 td-b78d09 td-bd56aa td-b1353d td-3163d7 # Long-Run
  td-8b3106 td-007e7d td-cdbe70 td-4fe29e td-edf5b6 td-e2bc99 td-b1f7ad td-80dca0 td-6e31ad td-2a4cf2 td-c10ef2 td-81d9f7 # Backend Gates
  td-a0f014 td-590192 td-a99725 td-11e206 # Plugins
  td-0729fd # Personal Context Epic
)

for task in "${TASKS[@]}"; do
  td unstart "$task" > /dev/null 2>&1
done

echo "Setting up sequential dependency chain (Cohesive Strategy)..."

# Phase 1 -> Phase 2: Static Plugins depend on Executable Rebuild Track (td-2c38e1)
td dep add td-a0f014 td-2c38e1
# Phase 2 -> Phase 3: Database Consolidation depends on Static Plugins
td dep add td-40a6ce td-a0f014
# Phase 3 -> Phase 4: Personal Context depends on Database Consolidation
td dep add td-0729fd td-40a6ce
# Phase 4 -> Phase 5: Long-Run Agent Architecture depends on Personal Context
td dep add td-c71ebd td-0729fd
# Phase 5 -> Phase 6: Final Backend Blind Spots depends on Long-Run Architecture
td dep add td-8b3106 td-c71ebd

echo "Done."
