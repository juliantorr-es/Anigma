#!/usr/bin/env bash
# Scripts/ci/benchmark-capsules.sh
# Run capsule performance benchmarks and enforce marshalling budgets

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BASELINE_FILE="${BASELINE_FILE:-${PROJECT_ROOT}/Anigma/Benchmarks/baselines/native_benchmarks.json}"
RESULTS_DIR="${RESULTS_DIR:-${PROJECT_ROOT}/Benchmarks/results/performance-regression}"
CURRENT_JSON="${RESULTS_DIR}/current.json"
COMPARISON_JSON="${RESULTS_DIR}/comparison.json"
COMPARISON_TXT="${RESULTS_DIR}/comparison.txt"
CAPSULE_BENCH_SUITE="${CAPSULE_BENCH_SUITE:-all}"
TOLERANCE="${TOLERANCE:-0.10}"

mkdir -p "${RESULTS_DIR}"

echo "::group::Capsule Performance Benchmarks"
echo "Root: ${PROJECT_ROOT}"
echo "Baseline: ${BASELINE_FILE}"
echo "Results: ${RESULTS_DIR}"
echo ""

cd "${PROJECT_ROOT}"

if [ ! -f "${BASELINE_FILE}" ]; then
    echo "❌ Baseline file not found: ${BASELINE_FILE}"
    echo "::endgroup::"
    exit 1
fi

echo "Running capsule benchmark harness..."
(
    cd "${PROJECT_ROOT}/Vendor/lib"
    DYLD_LIBRARY_PATH="$PWD${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}" \
    LD_LIBRARY_PATH="$PWD${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    swift run --package-path "${PROJECT_ROOT}" anigma-capsule-bench --suite "${CAPSULE_BENCH_SUITE}" --pretty --output "${CURRENT_JSON}"
)

python3 - "${BASELINE_FILE}" "${CURRENT_JSON}" "${COMPARISON_JSON}" "${COMPARISON_TXT}" "${TOLERANCE}" "${CAPSULE_BENCH_SUITE}" <<'PY'
import json
import sys
from datetime import datetime

baseline_path, current_path, comparison_path, text_path, tolerance, suite = sys.argv[1:7]
tolerance = float(tolerance)

with open(baseline_path, "r", encoding="utf-8") as baseline_file:
    baseline_data = json.load(baseline_file)

with open(current_path, "r", encoding="utf-8") as current_file:
    current_data = json.load(current_file)

suite_prefixes = {
    "all": "",
    "hot-path": "text_chunking_ingest_normalize_hotpath",
    "vector-index": "vector_index_",
    "rank-fusion": "rank_fusion_",
    "text-chunking": "text_chunking_",
    "pdf": "pdf_text_extraction",
    "layout-engine": "layout_engine_",
}

prefix = suite_prefixes.get(suite)
if prefix is None:
    prefix = ""

def include_result(name):
    return not prefix or name.startswith(prefix)

baseline_results = {entry["name"]: entry for entry in baseline_data.get("results", []) if include_result(entry["name"])}
current_results = {entry["name"]: entry for entry in current_data.get("results", []) if include_result(entry["name"])}

report = {
    "metadata": {
        "baseline": baseline_path,
        "current": current_path,
        "tolerance": tolerance,
        "suite": suite,
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "baseline_results": len(baseline_results),
        "current_results": len(current_results),
    },
    "regressions": [],
    "improvements": [],
    "unchanged": [],
    "missing_baseline": [],
    "missing_current": [],
    "summaries": [],
}

def compare_metric(benchmark_name, metric_name, baseline_value, current_value):
    if baseline_value in (None, 0) or current_value is None:
        return

    change_ratio = (current_value - baseline_value) / baseline_value
    higher_is_better = metric_name == "opsPerSecond"
    change_percent = change_ratio * 100.0

    if higher_is_better:
        regression = change_ratio < -tolerance
        improvement = change_ratio > tolerance
    else:
        regression = change_ratio > tolerance
        improvement = change_ratio < -tolerance

    entry = {
        "benchmark": benchmark_name,
        "metric": metric_name,
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

def metric_summary(name, baseline_entry, current_entry):
    return {
        "benchmark": name,
        "throughput_before": baseline_entry.get("opsPerSecond"),
        "throughput_after": current_entry.get("opsPerSecond"),
        "wall_before": baseline_entry.get("wallTimeSeconds", baseline_entry.get("durationSeconds")),
        "wall_after": current_entry.get("wallTimeSeconds", current_entry.get("durationSeconds")),
        "latency_before": baseline_entry.get("durationSeconds"),
        "latency_after": current_entry.get("durationSeconds"),
        "allocation_before": baseline_entry.get("memoryBytes"),
        "allocation_after": current_entry.get("memoryBytes"),
        "allocation_count_before": baseline_entry.get("allocationCount"),
        "allocation_count_after": current_entry.get("allocationCount"),
        "cross_language_calls_before": baseline_entry.get("crossLanguageCallCount"),
        "cross_language_calls_after": current_entry.get("crossLanguageCallCount"),
        "bytes_copied_before": baseline_entry.get("bytesCopied"),
        "bytes_copied_after": current_entry.get("bytesCopied"),
        "rss_before": baseline_entry.get("rssBytes"),
        "rss_after": current_entry.get("rssBytes"),
    }

for name, baseline_entry in baseline_results.items():
    current_entry = current_results.get(name)
    if current_entry is None:
        report["missing_current"].append(name)
        continue

    report["summaries"].append(metric_summary(name, baseline_entry, current_entry))

    for metric_name in (
        "wallTimeSeconds",
        "durationSeconds",
        "opsPerSecond",
        "memoryBytes",
        "rssBytes",
        "allocationCount",
        "crossLanguageCallCount",
        "bytesCopied",
    ):
        compare_metric(
            name,
            metric_name,
            baseline_entry.get(metric_name, baseline_entry.get("durationSeconds") if metric_name == "wallTimeSeconds" else None),
            current_entry.get(metric_name, current_entry.get("durationSeconds") if metric_name == "wallTimeSeconds" else None),
        )

for name in current_results:
    if name not in baseline_results:
        report["missing_baseline"].append(name)

with open(comparison_path, "w", encoding="utf-8") as comparison_file:
    json.dump(report, comparison_file, indent=2, sort_keys=True)

with open(text_path, "w", encoding="utf-8") as text_file:
    text_file.write("Capsule Benchmark Regression Report\n")
    text_file.write("=" * 36 + "\n\n")
    text_file.write(f"Suite: {suite}\n")
    text_file.write(f"Tolerance: {tolerance * 100:.1f}%\n")
    text_file.write(f"Baseline results: {len(baseline_results)}\n")
    text_file.write(f"Current results: {len(current_results)}\n\n")

    if report["summaries"]:
        text_file.write("Before / After Trends:\n")
        for entry in report["summaries"]:
            text_file.write(
                f"  - {entry['benchmark']}: "
                f"throughput {entry['throughput_before']:.2f} → {entry['throughput_after']:.2f} ops/s, "
                f"wall {entry['wall_before']:.4f} → {entry['wall_after']:.4f}s, "
                f"latency {entry['latency_before']:.4f} → {entry['latency_after']:.4f}s, "
                f"alloc-bytes {entry['allocation_before']} → {entry['allocation_after']} bytes, "
                f"alloc-count {entry['allocation_count_before']} → {entry['allocation_count_after']}, "
                f"cross-lang calls {entry['cross_language_calls_before']} → {entry['cross_language_calls_after']}, "
                f"bytes-copied {entry['bytes_copied_before']} → {entry['bytes_copied_after']}, "
                f"rss {entry['rss_before']} → {entry['rss_after']}\n"
            )
        text_file.write("\n")

    if report["missing_baseline"]:
        text_file.write("Missing baseline benchmarks:\n")
        for name in report["missing_baseline"]:
            text_file.write(f"  - {name}\n")
        text_file.write("\n")

    if report["missing_current"]:
        text_file.write("Missing current benchmarks:\n")
        for name in report["missing_current"]:
            text_file.write(f"  - {name}\n")
        text_file.write("\n")

    if report["regressions"]:
        text_file.write("Regressions:\n")
        for entry in report["regressions"]:
            text_file.write(
                f"  - {entry['benchmark']} :: {entry['metric']} "
                f"{entry['change_percent']:.1f}% ({entry['direction']} better)\n"
            )
        text_file.write("\n")

    if report["improvements"]:
        text_file.write("Improvements:\n")
        for entry in report["improvements"]:
            text_file.write(
                f"  - {entry['benchmark']} :: {entry['metric']} "
                f"{entry['change_percent']:.1f}% ({entry['direction']} better)\n"
            )
        text_file.write("\n")

    if not report["regressions"] and not report["improvements"]:
        text_file.write("No significant changes detected.\n")

if report["missing_baseline"]:
    print("Warning: new benchmarks without baseline:", ", ".join(report["missing_baseline"]))

if report["missing_current"] or report["regressions"]:
    print("Regression comparison failed. See comparison report for details.")
    sys.exit(1)

print("Benchmark comparison complete. No regressions detected.")
PY

echo ""
echo "Validating marshalling budgets..."
if CAPSULE_BENCH_SUITE="${CAPSULE_BENCH_SUITE:-all}" \
   CAPSULE_BENCH_ITERATIONS="${CAPSULE_BENCH_ITERATIONS:-3}" \
   swift ./Scripts/check_marshalling_budgets.swift; then
    echo "✅ Marshalling budget validation passed"
else
    echo "❌ Marshalling budget validation failed"
    echo "::endgroup::"
    exit 1
fi

echo ""
echo "✅ Capsule benchmark suite completed"
echo "::endgroup::"
exit 0
