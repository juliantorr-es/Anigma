#!/usr/bin/env swift
// swift-tools-version: 6.0
// Validate capsule marshalling discipline

import Foundation

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

// Patterns to detect violations
let patterns = [
    ("String\\.init\\(", "String initialization (use C string)"),
    ("String\\.\\+", "String concatenation (avoid in hot paths)"),
    ("JSONEncoder", "JSONEncoder usage (use binary serialization)"),
    ("JSONDecoder", "JSONDecoder usage (use binary serialization)"),
]

var violations: [(String, String, Int)] = []

func enumerateSwiftFiles(in directory: URL) throws {
    guard let enumerator = fileManager.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else { return }
    
    for case let fileURL as URL in enumerator {
        guard try fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
              fileURL.pathExtension == "swift" else { continue }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        for (idx, line) in lines.enumerated() {
            for (pattern, message) in patterns {
                if line.range(of: pattern, options: .regularExpression) != nil {
                    violations.append((fileURL.path, message, idx + 1))
                }
            }
        }
    }
}

print("🔍 Validating capsule marshalling discipline...")

let directories = [
    projectRoot.appendingPathComponent("Packages/CapsuleCore/Sources"),
    projectRoot.appendingPathComponent("Packages/AnigmaNativeShims/Sources"),
    projectRoot.appendingPathComponent("Sources/ContextumModule"),
]

for dir in directories {
    if fileManager.fileExists(atPath: dir.path) {
        try enumerateSwiftFiles(in: dir)
    }
}

if violations.isEmpty {
    print("✅ No capsule marshalling violations detected.")
    exit(0)
} else {
    print("❌ Found \(violations.count) capsule marshalling violation(s):")
    for (file, message, line) in violations {
        print("   \(file):\(line) - \(message)")
    }
    exit(1)
}