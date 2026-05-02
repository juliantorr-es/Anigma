//
//  AddSendableToValueTypesRule.swift
//  AnigmaASTServices
//
//  [Brief description of file purpose]
//

import Foundation
import SwiftSyntax
import AnigmaPrimitives

public final class AddSendableToValueTypesRule: SyntaxRewriteRule, AstAnchoredRule, @unchecked Sendable {
    public init() {
        super.init(
            name: "add-sendable-to-value-types",
            description: "Adds : Sendable to the nominal declaration identified by an AstAnchor",
            requiredTrustTier: .gold
        )
    }

    public func apply(
        to source: String,
        filePath: String,
        anchor: AstAnchor,
        ast: SourceFileSyntax,
        converter: SourceLocationConverter
    ) throws -> RewriteResult {
        guard locateTargetDecl(using: anchor, in: ast) != nil else {
            return .unchanged
        }

        let rewriter = TargetedSendableRewriter(
            targetStart: AbsolutePosition(utf8Offset: anchor.startOffset),
            targetEnd: AbsolutePosition(utf8Offset: anchor.endOffset),
            filePath: filePath,
            converter: converter
        )

        let modifiedAst = rewriter.visit(ast)
        if ast.description == modifiedAst.description {
            return .unchanged
        }

        return RewriteResult(
            modified: true,
            newSource: modifiedAst.description,
            diagnostics: [],
            appliedChanges: rewriter.changes
        )
    }

    private func locateTargetDecl(using anchor: AstAnchor, in ast: SourceFileSyntax) -> DeclSyntax? {
        let locator = DeclLocator(
            start: AbsolutePosition(utf8Offset: anchor.startOffset),
            end: AbsolutePosition(utf8Offset: anchor.endOffset)
        )
        _ = locator.visit(ast)
        return locator.bestMatch
    }
}

private final class DeclLocator: SyntaxAnyVisitor {
    let start: AbsolutePosition
    let end: AbsolutePosition
    var bestMatch: DeclSyntax?

    init(start: AbsolutePosition, end: AbsolutePosition) {
        self.start = start
        self.end = end
        super.init(viewMode: .sourceAccurate)
    }

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        guard let decl = node.as(DeclSyntax.self) else {
            return .visitChildren
        }

        if decl.position <= start && decl.endPosition >= end {
            bestMatch = decl
            return .visitChildren
        }

        if end < decl.position || start > decl.endPosition {
            return .skipChildren
        }

        return .visitChildren
    }
}

private final class TargetedSendableRewriter: SyntaxRewriter {
    private let targetStart: AbsolutePosition
    private let targetEnd: AbsolutePosition
    private let filePath: String
    private let converter: SourceLocationConverter
    private(set) var changes: [SourceChange] = []

    init(
        targetStart: AbsolutePosition,
        targetEnd: AbsolutePosition,
        filePath: String,
        converter: SourceLocationConverter
    ) {
        self.targetStart = targetStart
        self.targetEnd = targetEnd
        self.filePath = filePath
        self.converter = converter
    }

    private func isTarget(_ node: Syntax) -> Bool {
        node.position == targetStart && node.endPosition == targetEnd
    }

    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        guard isTarget(Syntax(node)) else {
            return super.visit(node)
        }
        return applySendable(to: DeclSyntax(node))
    }

    override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        guard isTarget(Syntax(node)) else {
            return super.visit(node)
        }
        return applySendable(to: DeclSyntax(node))
    }

    private func applySendable(to node: DeclSyntax) -> DeclSyntax {
        guard !hasSendable(node) else {
            return node
        }

        let oldText = node.description
        let newNode: DeclSyntax

        if var structNode = node.as(StructDeclSyntax.self) {
            structNode = structNode.with(
                \.inheritanceClause,
                updatedInheritanceClause(existing: structNode.inheritanceClause)
            )
            newNode = DeclSyntax(structNode)
        } else if var classNode = node.as(ClassDeclSyntax.self) {
            classNode = classNode.with(
                \.inheritanceClause,
                updatedInheritanceClause(existing: classNode.inheritanceClause)
            )
            newNode = DeclSyntax(classNode)
        } else {
            return node
        }

        recordChange(oldText: oldText, newNode: newNode)
        return newNode
    }

    private func updatedInheritanceClause(existing: InheritanceClauseSyntax?) -> InheritanceClauseSyntax {
        if var clause = existing {
            clause = clause.with(
                \.inheritedTypes,
                clause.inheritedTypes + [sendableInheritedType()]
            )
            return clause
        }
        return InheritanceClauseSyntax(
            colon: .colonToken(trailingTrivia: .space),
            inheritedTypes: InheritedTypeListSyntax([
                sendableInheritedType()
            ])
        )
    }

    private func sendableInheritedType() -> InheritedTypeSyntax {
        InheritedTypeSyntax(type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Sendable"))))
    }

    private func hasSendable(_ node: DeclSyntax) -> Bool {
        guard let clause = inheritanceClause(of: node) else {
            return false
        }
        return clause.inheritedTypes.contains { inherited in
            let text = inherited.type.description.trimmingCharacters(in: .whitespaces)
            return text == "Sendable" || text.hasSuffix(".Sendable")
        }
    }

    private func inheritanceClause(of node: DeclSyntax) -> InheritanceClauseSyntax? {
        if let structNode = node.as(StructDeclSyntax.self) {
            return structNode.inheritanceClause
        }
        if let classNode = node.as(ClassDeclSyntax.self) {
            return classNode.inheritanceClause
        }
        return nil
    }

    private func recordChange(oldText: String, newNode: DeclSyntax) {
        let range = newNode.sourceRange(converter: converter)
        let start = range.start
        let end = range.end
        let change = SourceChange(
            filePath: filePath,
            startLine: start.line,
            startColumn: start.column,
            endLine: end.line,
            endColumn: end.column,
            oldText: oldText.trimmingCharacters(in: .whitespacesAndNewlines),
            newText: newNode.description.trimmingCharacters(in: .whitespacesAndNewlines),
            ruleName: "add-sendable-to-value-types"
        )
        changes.append(change)
    }
}
