//
//  ASTFacade.swift
//  AnigmaASTServices
//
//  Clean façade over SwiftSyntax to prevent leakage into Harmonia build chain.
//  Provides only the essential AST operations needed by doctrine scouts.
//

import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Public Façade Types

/// Simple AST node representation that doesn't expose SwiftSyntax types
public struct ASTNode {
    public let type: String
    public let text: String
    public let lineNumber: Int
    public let columnNumber: Int
}

/// Simple source file representation
public struct ParsedSource {
    public let filePath: String
    public let source: String
    public let ast: SourceFileSyntax
}

// MARK: - Public Façade API

/// Clean AST parsing interface - no SwiftSyntax leakage
public struct ASTParser {

    /// Parse source code and return a parsed source object
    public static func parse(source: String, filePath: String) throws -> ParsedSource {
        let ast = Parser.parse(source: source)
        return ParsedSource(filePath: filePath, source: source, ast: ast)
    }

    /// Get line number for a syntax node
    public static func lineNumber(for node: SyntaxProtocol, in source: String) -> Int {
        let tree = Parser.parse(source: source)
        let location = node.startLocation(
            converter: SourceLocationConverter(fileName: "", tree: tree))
        return location.line
    }

    /// Get column number for a syntax node
    public static func columnNumber(for node: SyntaxProtocol, in source: String) -> Int {
        let tree = Parser.parse(source: source)
        let location = node.startLocation(
            converter: SourceLocationConverter(fileName: "", tree: tree))
        return location.column
    }
}

// MARK: - Visitor Protocol

/// Protocol for AST visitors without exposing SwiftSyntax
public protocol ASTVisitor {
    func visit(parsedSource: ParsedSource) -> [ASTNode]
}

// MARK: - Specialized Visitors

/// Visitor for detecting security patterns in code
public class SecurityPatternVisitor: SyntaxVisitor {
    private var violations: [ASTNode] = []
    private let patterns: [String]

    public init(patterns: [String]) {
        self.patterns = patterns
        super.init(viewMode: .fixedUp)
    }

    public override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        let text = node.representedLiteralValue

        for pattern in patterns {
            if let text = text, text.localizedCaseInsensitiveContains(pattern) {
                let violation = ASTNode(
                    type: "StringLiteral",
                    text: text,
                    lineNumber: node.startLocation(
                        converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                    ).line,
                    columnNumber: node.startLocation(
                        converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                    ).column
                )
                violations.append(violation)
            }
        }

        return .visitChildren
    }

    public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if let binding = node.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
            let text = identifier.identifier.text

            for pattern in patterns {
                if text.localizedCaseInsensitiveContains(pattern) {
                    let violation = ASTNode(
                        type: "VariableDeclaration",
                        text: text,
                        lineNumber: node.startLocation(
                            converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                        ).line,
                        columnNumber: node.startLocation(
                            converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                        ).column
                    )
                    violations.append(violation)
                }
            }
        }

        return .visitChildren
    }

    public func getViolations() -> [ASTNode] {
        return violations
    }
}

/// Visitor for detecting authentication patterns
public class AuthenticationPatternVisitor: SyntaxVisitor {
    private var violations: [ASTNode] = []

    public init() {
        super.init(viewMode: .fixedUp)
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let functionName =
            node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.description
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Check for insecure authentication patterns
        let insecurePatterns = ["md5", "sha1", "base64", "eval"]
        if insecurePatterns.contains(functionName.lowercased()) {
            let violation = ASTNode(
                type: "FunctionCall",
                text: functionName,
                lineNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).line,
                columnNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).column
            )
            violations.append(violation)
        }

        return .visitChildren
    }

    public override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        let operatorText = node.operator.description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for insecure comparison patterns
        if operatorText == "==" && node.leftOperand.description.contains("password") {
            let violation = ASTNode(
                type: "InfixOperator",
                text: operatorText,
                lineNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).line,
                columnNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).column
            )
            violations.append(violation)
        }

        return .visitChildren
    }

    public func getViolations() -> [ASTNode] {
        return violations
    }
}

/// Visitor for complexity analysis
public class ComplexityVisitor: SyntaxVisitor {
    private var loopDepth = 0
    private var maxLoopDepth = 0
    private var violations: [ASTNode] = []

    public init() {
        super.init(viewMode: .fixedUp)
    }

    public override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        loopDepth += 1
        maxLoopDepth = max(maxLoopDepth, loopDepth)

        if loopDepth > 3 {
            let violation = ASTNode(
                type: "ForLoop",
                text: "Deep nesting detected",
                lineNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).line,
                columnNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).column
            )
            violations.append(violation)
        }

        let result = SyntaxVisitorContinueKind.visitChildren
        loopDepth -= 1
        return result
    }

    public override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        loopDepth += 1
        maxLoopDepth = max(maxLoopDepth, loopDepth)

        if loopDepth > 3 {
            let violation = ASTNode(
                type: "WhileLoop",
                text: "Deep nesting detected",
                lineNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).line,
                columnNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).column
            )
            violations.append(violation)
        }

        let result = SyntaxVisitorContinueKind.visitChildren
        loopDepth -= 1
        return result
    }

    public func getMaxLoopDepth() -> Int {
        return maxLoopDepth
    }

    public func getViolations() -> [ASTNode] {
        return violations
    }
}

/// Visitor for concurrency analysis
public class ConcurrencyVisitor: SyntaxVisitor {
    private var violations: [ASTNode] = []

    public init() {
        super.init(viewMode: .fixedUp)
    }

    public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for non-thread-safe patterns
        let attributes = node.attributes
        for attribute in attributes {
            if attribute.as(AttributeSyntax.self)?.attributeName.description.trimmingCharacters(
                in: .whitespacesAndNewlines) == "@MainActor" {
                // This is good - MainActor ensures thread safety
                continue
            }
        }

        let typeText = node.bindings.first?.typeAnnotation?.type.description ?? ""
        if typeText.contains("var") && !typeText.contains("@MainActor") {
            let violation = ASTNode(
                type: "VariableDeclaration",
                text: "Potential thread safety issue",
                lineNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).line,
                columnNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).column
            )
            violations.append(violation)
        }

        return .visitChildren
    }

    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check for async/await patterns
        if node.modifiers.contains(where: { $0.name.text == "async" }) {
            // Good - using async
        } else {
            // Check if function might need async
            let bodyText = node.body?.description ?? ""
            if bodyText.contains("URLSession") || bodyText.contains("Data") {
                let violation = ASTNode(
                    type: "FunctionDeclaration",
                    text: "Function might need async",
                    lineNumber: node.startLocation(
                        converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                    ).line,
                    columnNumber: node.startLocation(
                        converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                    ).column
                )
                violations.append(violation)
            }
        }

        return .visitChildren
    }

    public func getViolations() -> [ASTNode] {
        return violations
    }
}

/// Visitor for architecture analysis
public class ArchitectureVisitor: SyntaxVisitor {
    private var violations: [ASTNode] = []

    public init() {
        super.init(viewMode: .fixedUp)
    }

    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let members = node.memberBlock.members

        // Count methods and properties
        let methodCount = members.filter { $0.decl.is(FunctionDeclSyntax.self) }.count
        let propertyCount = members.filter { $0.decl.is(VariableDeclSyntax.self) }.count

        // Check for god object anti-pattern
        if methodCount > 20 || propertyCount > 15 {
            let violation = ASTNode(
                type: "ClassDeclaration",
                text: "Class too large - consider splitting",
                lineNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).line,
                columnNumber: node.startLocation(
                    converter: SourceLocationConverter(fileName: "", tree: Parser.parse(source: ""))
                ).column
            )
            violations.append(violation)
        }

        return .visitChildren
    }

    public func getViolations() -> [ASTNode] {
        return violations
    }
}
