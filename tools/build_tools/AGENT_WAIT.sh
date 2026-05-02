#!/bin/bash

echo "🕐 Waiting for agents to complete..."
echo ""
echo "Agent 1: finish-outlineum-spec-paths"
echo "Agent 2: harmonia-migration-phase2-plan"
echo ""
echo "Monitoring... (refresh every 30 seconds)"

while true; do
  echo ""
  echo "--- $(date '+%H:%M:%S') ---"
  
  # Check agents via copilot CLI if available, or just indicate we're waiting
  sleep 30
  
  # You can poll status here, but agents send notifications when complete
done
