#!/usr/bin/env swift

import Foundation

print("🧪 Testing Behavioral Metrics & Invariants")

print("\n1. BehavioralHealthMetrics defines:")
print("   - analysisRatio: analysis_calls / (analysis + edit + test)")
print("   - firstEditLatency: analysis calls before first edit")
print("   - toolDiversity: distinct tools used")
print("   - healthScore: 0.0 (gremlin) to 1.0 (junior engineer)")
print("   - isHealthy: based on invariant checks")

print("\n2. BehavioralInvariants (junior engineer pattern):")
print("   - maxFilesPerSession: 5")
print("   - maxEditsBeforeTests: 3")
print("   - requireAnalysisBeforeEdits: true")
print("   - minAnalysisRatio: 0.2")
print("   - maxFirstEditLatency: 5")
print("   - minToolDiversity: 3")

print("\n3. InvariantViolation types:")
print("   - edit_without_analysis: edits with 0 analysis (critical)")
print("   - too_many_edits_before_tests: >3 edits before tests")
print("   - low_analysis_ratio: <0.2 analysis ratio")
print("   - high_first_edit_latency: >5 analysis calls before edit")
print("   - low_tool_diversity: <3 tools for active session")
print("   - no_tests_after_edits: edits but 0 tests")

print("\n4. ToolUsageInspector can:")
print("   - checkSessionInvariants(sessionIndex)")
print("   - checkProjectInvariants(projectId)")
print("   - getHealthReport(projectId)")
print("   - exportBehavioralCSV(projectId)")
print("   - runABComparison(projectIdA, projectIdB)")

print("\n5. Example healthy session pattern:")
print("   Session 1: code_question → code_search → write_file → run_tests")
print("   Metrics: analysisRatio=0.5, firstEditLatency=2, toolDiversity=3")
print("   Health: ✅ Healthy (junior engineer behavior)")

print("\n6. Example gremlin session pattern:")
print("   Session 2: write_file ×5 → test_failure")
print("   Metrics: analysisRatio=0.0, firstEditLatency=0, toolDiversity=2")
print("   Violations: edit_without_analysis, no_tests_after_edits")
print("   Health: ❌ Critical (gremlin behavior)")

print("\n🎯 Ready to interrogate harness behavior")
print("\nNext: Run real harness, then use:")
print("   harmonia stats --project-id <id>")
print("   harmonia smell-check --project-id <id>")
print("   harmonia export-csv --project-id <id>")
