#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCHMARK_DIR="$ROOT_DIR/Packages/NativeBenchmarks"

BASELINE_FILE="${BASELINE_FILE:-$ROOT_DIR/Benchmarks/baselines/native_benchmarks.json}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/Benchmarks/results}"
TOLERANCE="${TOLERANCE:-0.10}"

CURRENT_OUTPUT="$OUTPUT_DIR/benchmark_output.txt"
CURRENT_JSON="$OUTPUT_DIR/current.json"
COMPARISON_JSON="$OUTPUT_DIR/comparison.json"
COMPARISON_TXT="$OUTPUT_DIR/comparison.txt"

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$BASELINE_FILE" ]; then
  echo "Baseline file not found: $BASELINE_FILE"
  exit 1
fi

"$BENCHMARK_DIR/scripts/build.sh"
"$BENCHMARK_DIR/build/bin/anigma_benchmarks" > "$CURRENT_OUTPUT"

python3 "$BENCHMARK_DIR/scripts/analyze_results.py" \
  --results "$CURRENT_OUTPUT" \
  --output "$CURRENT_JSON"

python3 - "$BASELINE_FILE" "$CURRENT_JSON" "$COMPARISON_JSON" "$COMPARISON_TXT" "$TOLERANCE" <<'PY'
import json
import sys
from datetime import datetime

baseline_path, current_path, comparison_path, text_path, tolerance = sys.argv[1:6]
tolerance = float(tolerance)

with open(baseline_path, "r") as baseline_file:
    baseline_data = json.load(baseline_file)

with open(current_path, "r") as current_file:
    current_data = json.load(current_file)

baseline_results = baseline_data.get("results", {})
current_results = current_data.get("results", {})

report = {
    "metadata": {
        "baseline": baseline_path,
        "current": current_path,
        "tolerance": tolerance,
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "baseline_sections": len(baseline_results),
        "current_sections": len(current_results),
    },
    "regressions": [],
    "improvements": [],
    "unchanged": [],
    "missing_baseline": [],
    "missing_current": [],
}

def is_throughput(metric_name: str) -> bool:
    return "throughput" in metric_name.lower()

def classify_metric(section, metric, baseline_value, current_value):
    if baseline_value == 0:
        return None

    change_ratio = (current_value - baseline_value) / baseline_value
    change_percent = change_ratio * 100.0
    higher_is_better = is_throughput(metric)

    if higher_is_better:
        regression = change_ratio < -tolerance
        improvement = change_ratio > tolerance
    else:
        regression = change_ratio > tolerance
        improvement = change_ratio < -tolerance

    entry = {
        "section": section,
        "metric": metric,
        "baseline": baseline_value,
        "current": current_value,
        "change_percent": change_percent,
        "direction": "higher" if higher_is_better else "lower",
    }

    if regression:
        report["regressions"].append(entry)
    elif improvement:
        report["improvements"].append(entry)
    else:
        report["unchanged"].append(entry)

if not baseline_results:
    report["missing_baseline"].append("baseline_empty")
else:
    for section, current_metrics in current_results.items():
        baseline_metrics = baseline_results.get(section)
        if baseline_metrics is None:
            report["missing_baseline"].append(section)
            continue

        for metric, current_value in current_metrics.items():
            if metric not in baseline_metrics:
                continue
            baseline_value = baseline_metrics[metric]
            classify_metric(section, metric, baseline_value, current_value)

    for section in baseline_results.keys():
        if section not in current_results:
            report["missing_current"].append(section)

with open(comparison_path, "w") as comparison_file:
    json.dump(report, comparison_file, indent=2)

with open(text_path, "w") as text_file:
    text_file.write("Benchmark Regression Report\n")
    text_file.write("=" * 32 + "\n\n")
    text_file.write(f"Tolerance: {tolerance * 100:.1f}%\n")
    text_file.write(f"Baseline sections: {len(baseline_results)}\n")
    text_file.write(f"Current sections: {len(current_results)}\n\n")

    if report["missing_baseline"]:
        text_file.write("Missing baseline sections:\n")
        for section in report["missing_baseline"]:
            text_file.write(f"  - {section}\n")
        text_file.write("\n")

    if report["missing_current"]:
        text_file.write("Missing current sections:\n")
        for section in report["missing_current"]:
            text_file.write(f"  - {section}\n")
        text_file.write("\n")

    if report["regressions"]:
        text_file.write("Regressions:\n")
        for entry in report["regressions"]:
            text_file.write(
                f"  - {entry['section']} :: {entry['metric']} "
                f"{entry['change_percent']:.1f}% ({entry['direction']} better)\n"
            )
        text_file.write("\n")

    if report["improvements"]:
        text_file.write("Improvements:\n")
        for entry in report["improvements"]:
            text_file.write(
                f"  - {entry['section']} :: {entry['metric']} "
                f"{entry['change_percent']:.1f}% ({entry['direction']} better)\n"
            )
        text_file.write("\n")

    if not report["regressions"] and not report["improvements"]:
        text_file.write("No significant changes detected.\n")

if report["regressions"]:
    print("Regression(s) detected. See comparison report for details.")
    sys.exit(1)

print("Benchmark comparison complete. No regressions detected.")
PY
