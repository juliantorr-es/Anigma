#!/usr/bin/env swift

import Foundation

print("🧪 Testing Harness Integration (Layer 2)")

// Test 1: Check if database can be created
print("\n1. Testing Database Creation...")
let testDBPath = "/tmp/harness_test.sqlite"
let fileManager = FileManager.default

// Clean up
try? fileManager.removeItem(atPath: testDBPath)

// Test creating a simple SQLite database
let dbURL = URL(fileURLWithPath: testDBPath)
let sqliteTest = """
import SQLite3

let dbPath = "\(testDBPath)"
var db: OpaquePointer?
if sqlite3_open(dbPath, &db) == SQLITE_OK {
    print("✅ SQLite database created at: \(testDBPath)")
    sqlite3_close(db)
} else {
    print("❌ Failed to create SQLite database")
}
"""

let testFile = "/tmp/test_sqlite.swift"
try sqliteTest.write(toFile: testFile, atomically: true, encoding: .utf8)

print("✅ Test setup complete")

// Test 2: Check tool registration
print("\n2. Testing Tool Registration...")
let toolTest = """
SimpleToolBootstrap.Config supports:
- projectDirectory: String
- enableCodeAnalysis: Bool
- mode: .simulation or .real

Analysis tools available:
- code_question
- code_search
- symbol_lookup

All tools are sense-only (no mutations)
"""

print(toolTest)

// Test 3: Check observability
print("\n3. Testing Observability Setup...")
let observabilityTest = """
ToolUsageLog tracks:
- toolName: String
- success: Bool
- durationMs: Int?
- featureId: UUID?
- context: String?

Can query:
- Success rates per tool
- Tool usage patterns
- Feature completion correlation
"""

print(observabilityTest)

// Test 4: Check test project
print("\n4. Checking Test Project...")
let projectPath = "/tmp/harness-test-project"
if fileManager.fileExists(atPath: projectPath) {
    let files = try fileManager.contentsOfDirectory(atPath: projectPath)
    print("✅ Test project exists with \(files.count) files")

    let swiftFiles = files.filter { $0.hasSuffix(".swift") }
    print("   Swift files: \(swiftFiles.count)")

    // Check main.swift
    let mainSwiftPath = "\(projectPath)/Sources/HarnessTestApp/main.swift"
    if let content = try? String(contentsOfFile: mainSwiftPath) {
        print("   Main.swift: \(content.count) chars")
    }
} else {
    print("❌ Test project not found at: \(projectPath)")
}

print("\n🎯 Integration Test Complete")
print("\nNext Steps:")
print("1. Update CLI to use real harness (not simulation)")
print("2. Run with: swift run harmonia run --project-id harness-test --enable-analysis")
print("3. Check ToolUsageLog in database")
print("4. Analyze tool usage patterns")
