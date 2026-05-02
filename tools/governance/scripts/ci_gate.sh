#!/bin/bash
set -e

# Ledger-ready JSON output file
REPORT="governance_audit.json"

echo "Anigma Governance Gate Execution..."

# 1. Run the primary gate (aggregate tool)
# We use the internal anigma_ci_all tool if available
if command -v anigma_ci_all &> /dev/null; then
    echo "Executing anigma_ci_all..."
    anigma_ci_all > "$REPORT"
else
    echo "anigma_ci_all not found in PATH, running individual gates..."
    
    SWIFT6_RES=$(anigma_swift6_check 2>/dev/null || echo "{\"status\": \"failed\", \"error\": \"tool missing\"}")
    TYPE_AUTH_RES=$(anigma_type_authority_check 2>/dev/null || echo "{\"status\": \"failed\", \"error\": \"tool missing\"}")
    DEPS_RES=$(anigma_deps_check 2>/dev/null || echo "{\"status\": \"failed\", \"error\": \"tool missing\"}")
    
    echo "Running Build Hygiene Check..."
    ./scripts/validate_build_hygiene.sh > build_hygiene_log.txt 2>&1
    if [ $? -eq 0 ]; then
        HYGIENE_RES="{\"status\": \"passed\"}"
    else
        HYGIENE_RES="{\"status\": \"failed\", \"error\": \"Violations found, see build_hygiene_report.txt\"}"
    fi

    cat <<EOF > "$REPORT"
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "gates": {
    "swift6": $SWIFT6_RES,
    "type_authority": $TYPE_AUTH_RES,
    "dependencies": $DEPS_RES,
    "build_hygiene": $HYGIENE_RES
  },
  "governance_status": "audited"
}
EOF
fi

BENCHMARK_STATUS="skipped"
BENCHMARK_PATH=""
BENCHMARK_ERROR=""

if [ -x "./Scripts/run_benchmarks.sh" ]; then
    echo "Running benchmark harness..."
    if ./Scripts/run_benchmarks.sh > benchmark_harness_log.txt 2>&1; then
        BENCHMARK_STATUS="completed"
        BENCHMARK_PATH="Anigma/Benchmarks/BenchmarkHarness/results/benchmark_results.json"
    else
        BENCHMARK_STATUS="failed"
        BENCHMARK_ERROR="Benchmark harness execution failed"
    fi
else
    echo "Benchmark harness script not found, skipping."
fi

if [ -f "$REPORT" ] && command -v python3 &> /dev/null; then
    python3 - <<PY
import json

path = "$REPORT"
with open(path, "r") as handle:
    data = json.load(handle)

gate = {"status": "$BENCHMARK_STATUS"}
if "$BENCHMARK_PATH":
    gate["result_path"] = "$BENCHMARK_PATH"
if "$BENCHMARK_ERROR":
    gate["error"] = "$BENCHMARK_ERROR"

data.setdefault("gates", {})["benchmarks"] = gate

with open(path, "w") as handle:
    json.dump(data, handle, indent=2)
PY
fi

echo "Gate Summary:"
cat "$REPORT"
