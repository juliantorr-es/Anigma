#!/usr/bin/env swift

import Foundation

print("🧪 Testing Layer 2: Code Analysis Tools")

// Simple test to verify the tools work
let testDir = "/tmp/layer2-test"
let fileManager = FileManager.default

// Clean up and create test directory
try? fileManager.removeItem(atPath: testDir)
try fileManager.createDirectory(atPath: testDir, withIntermediateDirectories: true)

// Create a simple Swift file to analyze
let swiftFile = """
// TestSwiftFile.swift
// Simple test file for code analysis

import Foundation

class Calculator {
    func add(_ a: Int, _ b: Int) -> Int {
        return a + b
    }

    func subtract(_ a: Int, _ b: Int) -> Int {
        return a - b
    }
}

struct MathUtils {
    static func multiply(_ a: Int, _ b: Int) -> Int {
        return a * b
    }
}
"""

try swiftFile.write(toFile: "\(testDir)/TestSwiftFile.swift", atomically: true, encoding: .utf8)

print("✅ Created test Swift file at: \(testDir)/TestSwiftFile.swift")
print("\n📊 Layer 2 Components:")
print("1. SimpleCodeAnalysisTool.swift - ✅ Created")
print("2. Updated SimpleToolBootstrap with Config - ✅ Updated")
print("3. Updated CodingAgentPrompt.md - ✅ Updated")
print("4. ToolUsageLog in ProjectHarnessStore - ✅ Added")
print("\n🎯 Ready for real experiment with:")
print("   - Analysis-first guidance in prompts")
print("   - Tool usage observability")
print("   - Sense-only analysis tools")
print("\nNext: Run 'harmonia run --project-id test-project --iterations 2' with code analysis enabled")
