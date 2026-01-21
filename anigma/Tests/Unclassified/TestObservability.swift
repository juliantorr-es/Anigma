#!/usr/bin/env swift

import Foundation

print("🧪 Testing Harness Observability")

// Create a test database
let testDBPath = "/tmp/test_observability.sqlite"
let fileManager = FileManager.default

// Clean up
try? fileManager.removeItem(atPath: testDBPath)

print("1. Database path: \(testDBPath)")
print("2. ToolUsageLog table should track:")
print("   - toolName (e.g., 'code_question', 'write_file')")
print("   - success (true/false)")
print("   - durationMs (optional)")
print("   - featureId (optional)")
print("   - context (optional)")

print("\n3. In a real run, we should see patterns like:")
print("   Healthy: code_question → code_search → write_file → run_tests")
print("   Unhealthy: write_file (no analysis) → test_failure")
print("   Procrastination: code_search ×10 → no edits")

print("\n4. Query examples (via GRDB):")
print("   SELECT toolName, COUNT(*) as calls, AVG(durationMs) as avg_ms")
print("   FROM tool_usage_logs")
print("   WHERE projectId = ?")
print("   GROUP BY toolName")
print("   ORDER BY calls DESC")

print("\n5. Feature correlation:")
print("   SELECT f.name as feature, t.toolName, COUNT(*) as tool_calls")
print("   FROM feature_test_cases f")
print("   LEFT JOIN tool_usage_logs t ON f.id = t.featureId")
print("   WHERE f.projectId = ?")
print("   GROUP BY f.name, t.toolName")

print("\n🎯 Observability setup complete")
print("\nNext: After real harness run, check:")
print("   - Database file exists")
print("   - ToolUsageLog table has entries")
print("   - Patterns match expectations")
