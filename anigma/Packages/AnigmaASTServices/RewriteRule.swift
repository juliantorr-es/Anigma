//
//  RewriteRule.swift
//  AnigmaASTServices
//
//  Protocol for idempotent code transformation rules.
//  Inspired by SwiftRewriter's rule architecture with governance integration.
//
//  Key design:
//  - Idempotent: applying rule twice has same effect as once
//  - Governed: activation by trust tier (bronze, silver, gold, platinum)
//  - Testable: includes examples for validation
//  - Composable: rules can be chained in pipelines
//

import Foundation
import SwiftSyntax
import SwiftParser
import AnigmaPrimitives

/// Result of applying a rewrite rule.
public struct RewriteResult: Sendable {
    public let modified: Bool
    public let newSource: String
    public let diagnostics: [String]
    public let appliedChanges: [SourceChange]

    public init(
        modified: Bool,
        newSource: String,
        diagnostics: [String] = [],
        appliedChanges: [SourceChange] = []
    ) {
        self.modified = modified
        self.newSource = newSource
        self.diagnostics = diagnostics
        self.appliedChanges = appliedChanges
    }

    public static var unchanged: RewriteResult {
        RewriteResult(modified: false, newSource: "", diagnostics: [], appliedChanges: [])
    }
}

/// Describes a specific change made to source code.
public struct SourceChange: Sendable {
    public let filePath: String
    public let startLine: Int
    public let startColumn: Int
    public let endLine: Int
    public let endColumn: Int
    public let oldText: String
    public let newText: String
    public let ruleName: String

    public init(
        filePath: String,
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int,
        oldText: String,
        newText: String,
        ruleName: String
    ) {
        self.filePath = filePath
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = endLine
        self.endColumn = endColumn
        self.oldText = oldText
        self.newText = newText
        self.ruleName = ruleName
    }
}

/// Example input/output pair for rule validation.
public struct RuleExample: Sendable {
    public let name: String
    public let input: String
    public let expectedOutput: String
    public let description: String

    public init(
        name: String,
        input: String,
        expectedOutput: String,
        description: String
    ) {
        self.name = name
        self.input = input
        self.expectedOutput = expectedOutput
        self.description = description
    }
}

/// Protocol for idempotent code transformation rules.
public protocol RewriteRule: Sendable {
    /// Unique identifier for the rule.
    var name: String { get }

    /// Description of what the rule does.
    var description: String { get }

    /// Minimum trust tier required to activate this rule.
    var requiredTrustTier: TrustTier { get }

    /// Examples for testing and documentation.
    var examples: [RuleExample] { get }

    /// Check if rule should be applied to given file.
    func shouldApply(to filePath: String, source: String) -> Bool

    /// Apply rule to source code.
    func apply(to source: String, filePath: String) throws -> RewriteResult
}

/// Protocol for rules that depend on AST anchors.
public protocol AstAnchoredRule: RewriteRule {
    func apply(
        to source: String,
        filePath: String,
        anchor: AstAnchor,
        ast: SourceFileSyntax,
        converter: SourceLocationConverter
    ) throws -> RewriteResult
}

// MARK: - Default Implementations

public extension RewriteRule {
    /// Default implementation: always apply unless overridden.
    func shouldApply(to filePath: String, source: String) -> Bool {
        true
    }

    /// Validate examples to ensure rule works correctly.
    func validateExamples() throws {
        for example in examples {
            let result = try apply(to: example.input, filePath: "example.swift")

            guard result.modified else {
                throw RuleValidationError.exampleNotApplied(
                    rule: name,
                    example: example.name
                )
            }

            let normalizedResult = result.newSource.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedExpected = example.expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines)

            if normalizedResult != normalizedExpected {
                throw RuleValidationError.exampleMismatch(
                    rule: name,
                    example: example.name,
                    got: normalizedResult,
                    expected: normalizedExpected
                )
            }
        }
    }
}

// MARK: - Concrete Rule Implementations

/// Base class for AST-based rewrite rules.
open class SyntaxRewriteRule: RewriteRule, @unchecked Sendable {
    public let name: String
    public let description: String
    public let requiredTrustTier: TrustTier
    public let examples: [RuleExample]

    public init(
        name: String,
        description: String,
        requiredTrustTier: TrustTier,
        examples: [RuleExample] = []
    ) {
        self.name = name
        self.description = description
        self.requiredTrustTier = requiredTrustTier
        self.examples = examples
    }

    open func shouldApply(to filePath: String, source: String) -> Bool {
        // Default: apply to all Swift files
        return filePath.hasSuffix(".swift")
    }

    open func apply(to source: String, filePath: String) throws -> RewriteResult {
        let ast = Parser.parse(source: source)
        let rewriter = createRewriter()
        let modifiedAst = rewriter.visit(ast)

        if ast.description == modifiedAst.description {
            return RewriteResult.unchanged
        }

        let changes = collectChanges(from: rewriter)
        return RewriteResult(
            modified: true,
            newSource: modifiedAst.description,
            diagnostics: [],
            appliedChanges: changes
        )
    }

    /// Override to provide custom SyntaxRewriter.
    open func createRewriter() -> SyntaxRewriter {
        fatalError("Subclasses must implement createRewriter()")
    }

    /// Override to collect specific changes from rewriter.
    open func collectChanges(from rewriter: SyntaxRewriter) -> [SourceChange] {
        // Default: no detailed change tracking
        return []
    }
}

/// Base class for regex-based rewrite rules (for gradual migration).
open class RegexRewriteRule: RewriteRule, @unchecked Sendable {
    public let name: String
    public let description: String
    public let requiredTrustTier: TrustTier
    public let examples: [RuleExample]

    private let patterns: [(regex: NSRegularExpression, replacement: String)]

    public init(
        name: String,
        description: String,
        requiredTrustTier: TrustTier,
        patterns: [(pattern: String, replacement: String)],
        examples: [RuleExample] = []
    ) throws {
        self.name = name
        self.description = description
        self.requiredTrustTier = requiredTrustTier
        self.examples = examples

        self.patterns = try patterns.map { pattern, replacement in
            let regex = try NSRegularExpression(
                pattern: pattern,
                options: [.anchorsMatchLines, .dotMatchesLineSeparators]
            )
            return (regex, replacement)
        }
    }

    open func shouldApply(to filePath: String, source: String) -> Bool {
        return filePath.hasSuffix(".swift")
    }

    open func apply(to source: String, filePath: String) throws -> RewriteResult {
        var modified = false
        var currentSource = source
        var changes: [SourceChange] = []

        for (regex, replacement) in patterns {
            let matches = regex.matches(
                in: currentSource,
                range: NSRange(currentSource.startIndex..., in: currentSource)
            )

            if matches.isEmpty {
                continue
            }

            modified = true

            // Apply replacements in reverse order to preserve indices
            for match in matches.reversed() {
                guard let range = Range(match.range, in: currentSource) else {
                    continue
                }

                let oldText = String(currentSource[range])
                let newText = regex.replacementString(
                    for: match,
                    in: currentSource,
                    offset: 0,
                    template: replacement
                )

                // Calculate line/column (simplified)
                let lines = currentSource.prefix(upTo: range.lowerBound).components(separatedBy: .newlines)
                let startLine = lines.count
                let startColumn = lines.last?.count ?? 0 + 1

                let change = SourceChange(
                    filePath: filePath,
                    startLine: startLine,
                    startColumn: startColumn,
                    endLine: startLine, // Simplified
                    endColumn: startColumn + oldText.count,
                    oldText: oldText,
                    newText: newText,
                    ruleName: name
                )
                changes.append(change)

                currentSource.replaceSubrange(range, with: newText)
            }
        }

        if !modified {
            return RewriteResult.unchanged
        }

        return RewriteResult(
            modified: true,
            newSource: currentSource,
            diagnostics: [],
            appliedChanges: changes
        )
    }
}

// MARK: - Errors

public enum RuleValidationError: Error, LocalizedError {
    case exampleNotApplied(rule: String, example: String)
    case exampleMismatch(rule: String, example: String, got: String, expected: String)

    public var errorDescription: String? {
        switch self {
        case .exampleNotApplied(let rule, let example):
            return "Rule '\(rule)' did not apply to example '\(example)'"
        case .exampleMismatch(let rule, let example, let got, let expected):
            return """
            Rule '\(rule)' example '\(example)' mismatch:
            Expected: \(expected)
            Got: \(got)
            """
        }
    }
}

public enum RuleApplicationError: Error, LocalizedError {
    case parseError(rule: String, file: String, underlying: Error)
    case transformationError(rule: String, file: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .parseError(let rule, let file, let underlying):
            return "Rule '\(rule)' failed to parse file '\(file)': \(underlying)"
        case .transformationError(let rule, let file, let underlying):
            return "Rule '\(rule)' failed to transform file '\(file)': \(underlying)"
        }
    }
}
