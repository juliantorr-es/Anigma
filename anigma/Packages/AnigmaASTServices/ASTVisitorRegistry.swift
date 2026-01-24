//
//  ASTVisitorRegistry.swift
//  AnigmaASTServices
//
//  Registry for AST analysis rules.
//

import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Analysis Rule Protocol

/// Protocol for AST analysis rules
public protocol ASTAnalysisRule: Sendable {
    /// Unique identifier for the rule
    var id: String { get }
    /// Display name
    var name: String { get }
    /// Description
    var description: String { get }
    /// Severity level (error, warning, info)
    var severity: String { get }
    
    /// Visit parsed source and return findings
    func visit(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding]
}

// MARK: - Built-in Rules

/// Security pattern rule
public struct SecurityPatternRule: ASTAnalysisRule {
    public let id = "security"
    public let name = "Security Patterns"
    public let description = "Detects security anti-patterns and potential vulnerabilities"
    public let severity = "error"
    
    private let patterns: [String]
    
    public init(patterns: [String] = [
        "api_key", "api-key", "secret_key", "secret-key", 
        "password", "token", "credential", "private_key"
    ]) {
        self.patterns = patterns
    }
    
    public func visit(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
        var findings: [ASTFinding] = []
        
        let lines = source.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let lowerLine = line.lowercased()
            
            for pattern in patterns {
                if lowerLine.contains(pattern) {
                    findings.append(ASTFinding(
                        type: "security",
                        ruleId: "sec-pattern-001",
                        severity: severity,
                        message: "Potential hardcoded secret keyword '\(pattern)'",
                        filePath: filePath,
                        lineNumber: lineNumber,
                        columnNumber: nil,
                        context: line.trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }
        
        return findings
    }
}

/// Code quality rule
public struct QualityRule: ASTAnalysisRule {
    public let id = "quality"
    public let name = "Code Quality"
    public let description = "Detects code quality issues and style violations"
    public let severity = "warning"
    
    public init() {}
    
    public func visit(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
        var findings: [ASTFinding] = []
        
        let lines = source.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }
            
            // Check for force unwrapping
            if line.contains("!") && !line.contains("!=") && !line.contains("!==") {
                findings.append(ASTFinding(
                    type: "quality",
                    ruleId: "quality-002",
                    severity: severity,
                    message: "Force unwrapping detected",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: nil,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }
            
            // Check for long lines
            if line.count > 120 {
                findings.append(ASTFinding(
                    type: "quality",
                    ruleId: "quality-003",
                    severity: "info",
                    message: "Line exceeds 120 characters",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: nil,
                    context: String(line.prefix(120)) + "..."
                ))
            }
            
            // Check for TODO/FIXME comments
            if lowercased(line).contains("todo") || lowercased(line).contains("fixme") {
                findings.append(ASTFinding(
                    type: "quality",
                    ruleId: "quality-004",
                    severity: "info",
                    message: "TODO/FIXME comment found",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: nil,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }
        }
        
        return findings
    }
    
    private func lowercased(_ string: String) -> String {
        return string.lowercased()
    }
}

/// Concurrency rule
public struct ConcurrencyRule: ASTAnalysisRule {
    public let id = "concurrency"
    public let name = "Concurrency"
    public let description = "Detects concurrency issues and missing @MainActor annotations"
    public let severity = "warning"
    
    public init() {}
    
    public func visit(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
        var findings: [ASTFinding] = []
        
        let lines = source.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }
            
            // Check for DispatchQueue usage without MainActor
            if (line.contains("DispatchQueue") || line.contains("Task")) && 
               !line.contains("@MainActor") && 
               !trimmedLine.hasPrefix("//") {
                findings.append(ASTFinding(
                    type: "concurrency",
                    ruleId: "concurrency-001",
                    severity: severity,
                    message: "Potential concurrency issue - consider @MainActor annotation",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: nil,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }
            
            // Check for @State without @MainActor in SwiftUI
            if line.contains("@State") && !line.contains("@MainActor") && line.contains("var") {
                findings.append(ASTFinding(
                    type: "concurrency",
                    ruleId: "concurrency-002",
                    severity: "warning",
                    message: "@State property should be accessed on main thread",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: nil,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }
        }
        
        return findings
    }
}

/// Architecture rule
public struct ArchitectureRule: ASTAnalysisRule {
    public let id = "architecture"
    public let name = "Architecture"
    public let description = "Detects architectural anti-patterns and design issues"
    public let severity = "warning"
    
    public init() {}
    
    public func visit(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
        var findings: [ASTFinding] = []
        
        let lines = source.components(separatedBy: .newlines)
        var inClass = false
        var classStartLine = 0
        var memberCount = 0
        var className = ""
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("class ") || trimmedLine.hasPrefix("struct ") {
                if inClass && memberCount > 20 {
                    findings.append(ASTFinding(
                        type: "architecture",
                        ruleId: "architecture-001",
                        severity: severity,
                        message: "\(className) too large (\(memberCount) members) - consider splitting",
                        filePath: filePath,
                        lineNumber: classStartLine,
                        columnNumber: nil,
                        context: lines[classStartLine - 1].trimmingCharacters(in: .whitespaces)
                    ))
                }
                
                inClass = true
                classStartLine = lineNumber
                memberCount = 0
                className = extractClassName(from: line)
            } else if inClass && (trimmedLine.hasPrefix("func ") || trimmedLine.hasPrefix("var ") || trimmedLine.hasPrefix("let ")) {
                memberCount += 1
            } else if trimmedLine.hasPrefix("}") && inClass {
                if memberCount > 20 {
                    findings.append(ASTFinding(
                        type: "architecture",
                        ruleId: "architecture-001",
                        severity: severity,
                        message: "\(className) too large (\(memberCount) members) - consider splitting",
                        filePath: filePath,
                        lineNumber: classStartLine,
                        columnNumber: nil,
                        context: lines[classStartLine - 1].trimmingCharacters(in: .whitespaces)
                    ))
                }
                inClass = false
            }
        }
        
        return findings
    }
    
    private func extractClassName(from line: String) -> String {
        let components = line.components(separatedBy: CharacterSet.whitespaces)
        guard components.count >= 2 else { return "Unknown" }
        
        // Get the word after "class" or "struct"
        for (index, component) in components.enumerated() {
            if component == "class" || component == "struct", index + 1 < components.count {
                let name = components[index + 1]
                // Remove any colons or other punctuation
                return name.components(separatedBy: CharacterSet.punctuationCharacters.union(CharacterSet.whitespaces)).first ?? name
            }
        }
        
        return "Unknown"
    }
}

// MARK: - Visitor Registry

/// Registry for AST analysis rules
public class ASTRuleRegistry {
    public static let shared = ASTRuleRegistry()
    
    private var rules: [String: ASTAnalysisRule] = [:]
    
    private init() {
        registerDefaultRules()
    }
    
    /// Register a rule
    public func register(_ rule: ASTAnalysisRule) {
        rules[rule.id] = rule
    }
    
    /// Get rule by ID
    public func rule(for id: String) -> ASTAnalysisRule? {
        return rules[id]
    }
    
    /// Get all registered rules
    public func allRules() -> [ASTAnalysisRule] {
        return Array(rules.values)
    }
    
    /// Get rules for IDs
    public func rules(for ids: [String]) -> [ASTAnalysisRule] {
        return ids.compactMap { rules[$0] }
    }
    
    /// Run rules on source
    public func runRules(_ ruleIds: [String], ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
        var findings: [ASTFinding] = []
        
        for rule in rules(for: ruleIds) {
            findings.append(contentsOf: rule.visit(ast: ast, filePath: filePath, source: source))
        }
        
        return findings
    }
    
    private func registerDefaultRules() {
        register(SecurityPatternRule())
        register(QualityRule())
        register(ConcurrencyRule())
        register(ArchitectureRule())
    }
}
