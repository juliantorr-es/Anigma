#!/usr/bin/env python3
"""
Analyze benchmark results and generate reports
"""

import json
import re
import sys
import argparse
from pathlib import Path
from statistics import mean, stdev
from typing import Dict, List, Tuple


class BenchmarkParser:
    """Parse benchmark output"""

    @staticmethod
    def parse_results(filepath: str) -> Dict:
        """Parse benchmark results from output file"""
        with open(filepath, "r") as f:
            content = f.read()

        results = {}
        current_section = None

        for line in content.split("\n"):
            line = line.strip()

            # Detect section headers
            if "Results:" in line:
                current_section = line.replace(" Results:", "").strip()
                results[current_section] = {}

            # Parse metric lines
            if current_section and ":" in line:
                parts = line.split(":")
                if len(parts) == 2:
                    key = parts[0].strip()
                    value_str = parts[1].strip()

                    # Extract numeric value
                    match = re.search(r"([\d.]+)", value_str)
                    if match:
                        try:
                            value = float(match.group(1))
                            results[current_section][key] = value
                        except ValueError:
                            pass

        return results


class BenchmarkAnalyzer:
    """Analyze benchmark results"""

    def __init__(self, results: Dict):
        self.results = results

    def get_summary(self) -> Dict:
        """Generate summary statistics"""
        summary = {
            "total_benchmarks": len(self.results),
            "sections": list(self.results.keys()),
            "metrics_per_section": {},
        }

        for section, metrics in self.results.items():
            summary["metrics_per_section"][section] = len(metrics)

        return summary

    def detect_regressions(self, baseline: Dict, threshold: float = 0.10) -> Dict:
        """Detect performance regressions"""
        regressions = {}

        for section, metrics in self.results.items():
            if section not in baseline:
                continue

            baseline_metrics = baseline[section]
            regressions[section] = []

            for metric, current_value in metrics.items():
                if metric not in baseline_metrics:
                    continue

                baseline_value = baseline_metrics[metric]
                if baseline_value == 0:
                    continue

                change = (current_value - baseline_value) / baseline_value

                if change > threshold:
                    regressions[section].append(
                        {
                            "metric": metric,
                            "baseline": baseline_value,
                            "current": current_value,
                            "change_percent": change * 100,
                        }
                    )

        return regressions

    def get_trending(self) -> Dict:
        """Identify performance trends"""
        trends = {}

        for section, metrics in self.results.items():
            # Look for throughput metrics
            if any("Throughput" in k for k in metrics.keys()):
                throughput_metrics = {
                    k: v for k, v in metrics.items() if "Throughput" in k
                }
                trends[section] = throughput_metrics

        return trends


def generate_json_report(results: Dict, output_path: str):
    """Generate JSON report"""
    report = {
        "metadata": {"format": "benchmark_results_v1", "source": "anigma_benchmarks"},
        "results": results,
    }

    with open(output_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"JSON report written to: {output_path}")


def generate_text_report(results: Dict, output_path: str):
    """Generate text report"""
    with open(output_path, "w") as f:
        f.write("ANIGMA NATIVE BENCHMARKS - ANALYSIS REPORT\n")
        f.write("=" * 80 + "\n\n")

        # Summary
        f.write(f"Total Benchmark Sections: {len(results)}\n\n")

        # Detailed results
        for section, metrics in results.items():
            f.write(f"\n{section}\n")
            f.write("-" * 40 + "\n")

            for metric, value in metrics.items():
                f.write(f"  {metric}: {value:.4f}\n")

    print(f"Text report written to: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Analyze benchmark results")
    parser.add_argument("--results", required=True, help="Benchmark results file")
    parser.add_argument("--baseline", help="Baseline results for regression detection")
    parser.add_argument(
        "--output", default="analysis_report.json", help="Output report path"
    )
    parser.add_argument(
        "--threshold", type=float, default=0.10, help="Regression threshold (0-1)"
    )

    args = parser.parse_args()

    # Parse results
    print(f"Parsing benchmark results from: {args.results}")
    benchmark_parser = BenchmarkParser()
    results = benchmark_parser.parse_results(args.results)

    # Analyze
    analyzer = BenchmarkAnalyzer(results)
    summary = analyzer.get_summary()

    print(f"\nFound {summary['total_benchmarks']} benchmark sections")
    for section in summary["sections"]:
        print(f"  - {section}")

    # Check for regressions
    if args.baseline:
        print(f"\nDetecting regressions against baseline: {args.baseline}")
        baseline = benchmark_parser.parse_results(args.baseline)
        regressions = analyzer.detect_regressions(baseline, args.threshold)

        if any(regressions.values()):
            print("\nWARNING: Performance regressions detected!")
            for section, issues in regressions.items():
                if issues:
                    print(f"\n{section}:")
                    for issue in issues:
                        print(
                            f"  {issue['metric']}: {issue['change_percent']:.1f}% slower"
                        )
        else:
            print("\nNo regressions detected!")

    # Generate reports
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    generate_json_report(results, args.output)

    text_output = args.output.replace(".json", ".txt")
    generate_text_report(results, text_output)

    print("\nAnalysis complete!")


if __name__ == "__main__":
    main()
