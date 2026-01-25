//
//  SendableConformanceRule.swift
//  HarmoniaModule
//
//  AST-based rule for adding Sendable conformance to structs and classes.
//  Replaces the regex-based implementation in Swift6MigrationEngine.
//

@preconcurrency import Foundation
import AnigmaASTServicesCore
import AnigmaPrimitives
import SwiftSyntax
import SwiftParser

/// AST-based rule for adding Sendable conformance.
public final class SendableConformanceRule: SyntaxRewriteRule, @unchecked Sendable {

    public init() {
        super.init(
            name: "SendableConformance",
            description: "Adds : Sendable conformance to structs and classes that need it",
            requiredTrustTier: .gold,
            examples: [
                RuleExample(
                    name: "struct without inheritance",
                    input: """
                    struct User {
                        let name: String
                        let age: Int
                    }
                    """,
                    expectedOutput: """
                    struct User: Sendable {
                        let name: String
                        let age: Int
                    }
                    """,
                    description: "Adds : Sendable to struct without existing inheritance"
                ),
                RuleExample(
                    name: "struct with existing inheritance",
                    input: """
                    struct User: Codable {
                        let name: String
                        let age: Int
                    }
                    """,
                    expectedOutput: """
                    struct User: Codable, Sendable {
                        let name: String
                        let age: Int
                    }
                    """,
                    description: "Adds Sendable to existing inheritance list"
                ),
                RuleExample(
                    name: "class with where clause",
                    input: """
                    class Container<T> where T: Equatable {
                        let value: T
                    }
                    """,
                    expectedOutput: """
                    class Container<T>: Sendable where T: Equatable {
                        let value: T
                    }
                    """,
                    description: "Adds Sendable before where clause"
                ),
                RuleExample(
                    name: "already has Sendable",
                    input: """
                    struct User: Sendable {
                        let name: String
                    }
                    """,
                    expectedOutput: """
                    struct User: Sendable {
                        let name: String
                    }
                    """,
                    description: "No change when already has Sendable"
                ),
                RuleExample(
                    name: "actor (already Sendable)",
                    input: """
                    actor Counter {
                        private var value = 0
                    }
                    """,
                    expectedOutput: """
                    actor Counter {
                        private var value = 0
                    }
                    """,
                    description: "No change for actors (already Sendable)"
                )
            ]
        )
    }

    public override func shouldApply(to filePath: String, source: String) -> Bool {
        // Only apply to Swift files
        guard filePath.hasSuffix(".swift") else { return false }

        // Check if file contains struct or class declarations
        // This is a fast prefilter before AST parsing
        return source.contains("struct ") || source.contains("class ")
    }

    public override func createRewriter() -> SyntaxRewriter {
        SendableConformanceRewriter()
    }

    public override func collectChanges(from rewriter: SyntaxRewriter) -> [SourceChange] {
        guard let sendableRewriter = rewriter as? SendableConformanceRewriter else {
            return []
        }
        return sendableRewriter.changes
    }
}

/// SyntaxRewriter that adds Sendable conformance.
private class SendableConformanceRewriter: SyntaxRewriter {
    var changes: [SourceChange] = []
    private var filePath: String = ""
    private var converter: SourceLocationConverter?

    func setFilePath(_ path: String) {
        self.filePath = path
    }

    func setConverter(_ converter: SourceLocationConverter) {
        self.converter = converter
    }

    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        processStructDecl(node)
    }

    override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        processClassDecl(node)
    }

    private func processStructDecl(_ node: StructDeclSyntax) -> DeclSyntax {
        processDeclGroup(node)
    }

    private func processClassDecl(_ node: ClassDeclSyntax) -> DeclSyntax {
        processDeclGroup(node)
    }

    private func processDeclGroup(_ node: some DeclGroupSyntax) -> DeclSyntax {
        // Check if already has Sendable conformance
        let inheritedTypes = node.inheritanceClause?.inheritedTypes

        if let inheritedTypes = inheritedTypes,
           inheritedTypes.contains(where: { inheritedType in
                let typeName = inheritedType.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                return typeName == "Sendable" || typeName.hasSuffix(".Sendable")
            }) {
            // Already has Sendable, no change needed
            return super.visit(DeclSyntax(node))
        }

        // Create modified node with Sendable conformance
        let modifiedNode: DeclSyntax

        if let existingInheritance = node.inheritanceClause {
            // Add Sendable to existing inheritance list
            let newInheritedTypes = existingInheritance.inheritedTypes + [
                InheritedTypeSyntax(type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Sendable"))))
            ]

            let newInheritanceClause = InheritanceClauseSyntax(
                colon: existingInheritance.colon,
                inheritedTypes: newInheritedTypes
            )

            if let structNode = node.as(StructDeclSyntax.self) {
                modifiedNode = DeclSyntax(structNode.with(\.inheritanceClause, newInheritanceClause))
            } else if let classNode = node.as(ClassDeclSyntax.self) {
                modifiedNode = DeclSyntax(classNode.with(\.inheritanceClause, newInheritanceClause))
            } else {
                return super.visit(DeclSyntax(node))
            }
        } else {
            // Create new inheritance clause with Sendable
            let inheritanceClause = InheritanceClauseSyntax(
                colon: .colonToken(trailingTrivia: .space),
                inheritedTypes: [
                    InheritedTypeSyntax(type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Sendable"))))
                ]
            )

            if let structNode = node.as(StructDeclSyntax.self) {
                modifiedNode = DeclSyntax(structNode.with(\.inheritanceClause, inheritanceClause))
            } else if let classNode = node.as(ClassDeclSyntax.self) {
                modifiedNode = DeclSyntax(classNode.with(\.inheritanceClause, inheritanceClause))
            } else {
                return super.visit(DeclSyntax(node))
            }
        }

        // Record the change if we have location info
        if let converter = converter {
            let range = node.sourceRange(converter: converter)
            let start = range.start
            let end = range.end

            let change = SourceChange(
                filePath: filePath,
                startLine: start.line,
                startColumn: start.column,
                endLine: end.line,
                endColumn: end.column,
                oldText: node.description.trimmingCharacters(in: .whitespacesAndNewlines),
                newText: modifiedNode.description.trimmingCharacters(in: .whitespacesAndNewlines),
                ruleName: "SendableConformance"
            )
            changes.append(change)
        }

        return super.visit(modifiedNode)
    }
}

// MARK: - Helper Extensions

private extension InheritedTypeListSyntax {
    func contains(where predicate: (InheritedTypeSyntax) -> Bool) -> Bool {
        for element in self {
            if predicate(element) {
                return true
            }
        }
        return false
    }
}
