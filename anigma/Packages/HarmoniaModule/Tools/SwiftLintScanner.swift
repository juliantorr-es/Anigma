//
//  SwiftLintScanner.swift
//  HarmoniaModule
//
//  Created by Anigma Agent on 2026-01-12.
//

@preconcurrency import Foundation

/// Scans SwiftLint violations and generates refactoring tasks.
public class SwiftLintScanner {
    private let repoRoot: URL
    private var violations: [Violation] = []
    
    public struct Violation: Codable, Sendable {
        public let file: String
        public let line: Int
        public let character: Int?
        public let severity: String
        public let type: String?
        public let rule_id: String
        public let reason: String
    }
    
    // Fix templates for each rule
    private static let fixPrompts: [String: String] = [
        "function_parameter_count": """
            Fix this SwiftLint violation by extracting parameters into a configuration struct.
            
            **Strategy:**
            1. Create a new struct (e.g., `{FunctionName}Config`) with all parameters as properties
            2. Add an initializer with default values where appropriate
            3. Update the function to accept the config struct instead
            4. Update all call sites to use the new struct
            """,
        
        "large_tuple": """
            Fix this SwiftLint violation by converting the large tuple to a named struct.
            
            **Strategy:**
            1. Create a struct with named properties for each tuple element
            2. Replace tuple type with the new struct type
            3. Update access patterns from .0, .1 to .propertyName
            """,
        
        "force_unwrapping": """
            Fix this SwiftLint violation by using safe optional handling.
            
            **Strategy:**
            1. Use `guard let` or `if let` for conditional unwrapping
            2. Use `??` nil coalescing with a default value
            3. Use optional chaining `?.` where appropriate
            4. Consider throwing an error if the value must exist
            """,
        
        "force_cast": """
            Fix this SwiftLint violation by using safe casting.
            
            **Strategy:**
            1. Use `as?` with guard/if let for conditional casting
            2. Handle the failure case explicitly
            3. Consider generic constraints to avoid casting
            """,
        
        "force_try": """
            Fix this SwiftLint violation by properly handling errors.
            
            **Strategy:**
            1. Propagate the error with `try` in a throwing function
            2. Use `do-catch` to handle specific errors
            3. Use `try?` only if you truly want to ignore the error
            """,
            
        "file_length": """
            This file exceeds the recommended length. Consider splitting it.
            
            **Strategy:**
            1. Identify logical groupings of types/functions
            2. Extract related code into separate files
            3. Use extensions in separate files for protocol conformances
            4. Consider creating a subdirectory for related files
            """,
            
        "function_body_length": """
            This function is too long. Consider extracting helper methods.
            
            **Strategy:**
            1. Identify logical blocks within the function
            2. Extract each block into a private helper method
            3. Use descriptive names that explain the intent
            4. Consider breaking into multiple smaller functions
            """,
            
        "cyclomatic_complexity": """
            This function is too complex. Simplify the control flow.
            
            **Strategy:**
            1. Extract conditional logic into separate methods
            2. Use guard statements for early returns
            3. Replace nested if-else with switch or pattern matching
            4. Consider the Strategy pattern for complex branching
            """,
            
        "for_where": """
            Add a where clause to filter in the loop declaration.
            
            **Strategy:**
            Replace `if` inside the loop with a `where` clause.
            """,
            
        "identifier_name": """
            Rename this identifier to follow Swift naming conventions.
            
            **Swift Naming Conventions:**
            - Types: UpperCamelCase (e.g., `UserProfile`)
            - Variables/Functions: lowerCamelCase (e.g., `userName`)
            - Constants: lowerCamelCase (e.g., `maxRetryCount`)
            - Avoid abbreviations unless extremely common
            - Boolean properties: use `is`, `has`, `should` prefixes
            """,
            
        "nesting": """
            Reduce the nesting depth of this code.
            
            **Strategy:**
            1. Use guard statements for early exits
            2. Extract nested logic into separate functions
            3. Use flatMap/compactMap instead of nested optionals
            4. Consider the Result type for error handling
            """
    ]
    
    // Priority mapping
    private static let rulePriority: [String: Int] = [
        "function_parameter_count": 1,
        "large_tuple": 1,
        "file_length": 1,
        "force_unwrapping": 1,
        "force_cast": 1,
        "force_try": 1,
        "cyclomatic_complexity": 1,
        
        "identifier_name": 2,
        "nesting": 2,
        "for_where": 2,
        "multiline_arguments": 2,
        "closure_body_length": 2,
        
        "explicit_type_interface": 4,
        "explicit_acl": 4
    ]
    
    public init(repoRoot: URL) {
        self.repoRoot = repoRoot
    }
    
    public func scanViolations(rules: [String]? = nil, limit: Int = 1000) throws -> [Violation] {
        print("🔍 Scanning SwiftLint violations...")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["swiftlint", "lint", "--reporter", "json"]
        task.currentDirectoryURL = repoRoot
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        try task.run()
        // Wait not needed if we just read output? Wait for exit.
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if data.isEmpty {
            self.violations = []
            return []
        }
        
        let decoder = JSONDecoder()
        var violations = try decoder.decode([Violation].self, from: data)
        
        // Filter
        if let rules = rules {
            violations = violations.filter { rules.contains($0.rule_id) }
        }
        
        // Limit
        violations = Array(violations.prefix(limit))
        
        self.violations = violations
        print("  Found \(violations.count) violations")
        
        return violations
    }
    
    public func generateRefactoringTasks(sessionId: String) async -> [RefactoringTask] {
        var tasks: [RefactoringTask] = []
        var seen = Set<String>()
        
        for (index, v) in violations.enumerated() {
            let key = "\(v.file):\(v.line):\(v.rule_id)"
            if seen.contains(key) { continue }
            seen.insert(key)
            
            let context = getCodeContext(file: v.file, line: v.line)
            let fixPrompt = Self.fixPrompts[v.rule_id] ?? "Fix this \(v.rule_id) violation following Swift best practices."
            let priority = Self.rulePriority[v.rule_id] ?? 3
            
            let task = RefactoringTask(
                id: "swiftlint_\(sessionId)_\(String(format: "%04d", index))",
                type: "swiftlint_\(v.rule_id)",
                file: v.file,
                line: v.line,
                description: "[P\(priority)] \(v.rule_id): \(v.reason)",
                originalCode: context,
                proposedCode: "",
                metadata: [
                    "rule_id": v.rule_id,
                    "severity": v.severity,
                    "reason": v.reason,
                    "fix_strategy": fixPrompt,
                    "priority": String(priority)
                ]
            )
            tasks.append(task)
        }
        
        // Sort by priority (asc)
        tasks.sort {
            let p1 = Int($0.metadata["priority"] ?? "99") ?? 99
            let p2 = Int($1.metadata["priority"] ?? "99") ?? 99
            if p1 != p2 { return p1 < p2 }
            return $0.file < $1.file
        }
        
        return tasks
    }
    
    private func getCodeContext(file: String, line: Int, contextLines: Int = 10) -> String {
        let fileURL: URL
        if file.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: file)
        } else {
            fileURL = repoRoot.appendingPathComponent(file)
        }
        
        guard let content = try? String(contentsOf: fileURL) else { return "" }
        let lines = content.components(separatedBy: .newlines)
        
        let start = max(0, line - contextLines - 1)
        let end = min(lines.count, line + contextLines)
        
        var context = ""
        for i in start..<end {
            let marker = (i == line - 1) ? ">>> " : "    "
            context += "\(marker)\(i + 1): \(lines[i])\n"
        }
        
        return context
    }
}
