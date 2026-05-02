
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

@main
struct OSLogConverter {
    static func main() {
        guard CommandLine.arguments.count > 1 else {
            print("Usage: oslog-converter <input-file> <output-file>")
            exit(1)
        }
        
        let inputPath = CommandLine.arguments[1]
        let outputPath = CommandLine.arguments[2]
        
        do {
            let inputURL = URL(fileURLWithPath: inputPath)
            let outputURL = URL(fileURLWithPath: outputPath)
            
            let source = try String(contentsOf: inputURL, encoding: .utf8)
            
            let sourceFile = try SyntaxParser.parse(source: source)
            let visitor = PrintStatementVisitor(viewMode: .sourceAccurate)
            let transformed = visitor.visit(sourceFile)
            
            try transformed.description.write(to: outputURL, atomically: true, encoding: .utf8)
            print("✅ Successfully converted \(inputPath)")
            
        } catch {
            print("❌ Error converting \(inputPath): \(error)")
            exit(1)
        }
    }
}

class PrintStatementVisitor: SyntaxRewriter {
    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        // Only transform print() calls
        guard let calledExpression = node.calledExpression.as(IdentifierExprSyntax.self),
              calledExpression.identifier.text == "print" else {
            return super.visit(node)
        }
        
        // Determine log level based on message content
        let logLevel = determineLogLevel(from: node)
        
        // Extract metadata from string interpolation
        let metadata = extractMetadata(from: node)
        
        // Build the new OSLog call
        return buildOSLogCall(level: logLevel, from: node, metadata: metadata)
    }
    
    private func determineLogLevel(from node: FunctionCallExprSyntax) -> String {
        // Check if this is an error message
        if let firstArg = node.arguments.first?.expression.as(StringLiteralExprSyntax.self),
           firstArg.segments.contains(where: { segment in
               if let text = segment.as(TextSegmentSyntax.self)?.content.text {
                   return text.localizedCaseInsensitiveContains("error") ||
                          text.localizedCaseInsensitiveContains("failed") ||
                          text.localizedCaseInsensitiveContains("exception")
               }
               return false
           }) {
            return "error"
        }
        
        // Check for warnings
        if let firstArg = node.arguments.first?.expression.as(StringLiteralExprSyntax.self),
           firstArg.segments.contains(where: { segment in
               if let text = segment.as(TextSegmentSyntax.self)?.content.text {
                   return text.localizedCaseInsensitiveContains("warning") ||
                          text.localizedCaseInsensitiveContains("warn")
               }
               return false
           }) {
            return "warning"
        }
        
        return "info"
    }
    
    private func extractMetadata(from node: FunctionCallExprSyntax) -> [String: ExprSyntax] {
        var metadata = [String: ExprSyntax]()
        
        // Analyze first argument for string interpolation
        if let firstArg = node.arguments.first?.expression.as(StringLiteralExprSyntax.self) {
            for (index, segment) in firstArg.segments.enumerated() {
                if let exprSegment = segment.as(ExpressionSegmentSyntax.self),
                   let expr = exprSegment.expression.as(IdentifierExprSyntax.self) {
                    
                    let varName = expr.identifier.text
                    let metadataKey = "var\(index)"
                    metadata[metadataKey] = expr
                }
            }
        }
        
        return metadata
    }
    
    private func buildOSLogCall(level: String, from printCall: FunctionCallExprSyntax, metadata: [String: ExprSyntax]) -> ExprSyntax {
        // Get the original message
        guard let firstArg = printCall.arguments.first?.expression.as(StringLiteralExprSyntax.self) else {
            // Fallback to simple conversion
            return ExprSyntax(FunctionCallExprSyntax(
                calledExpression: IdentifierExprSyntax(identifier: .identifier("log.info")),
                leftParen: .leftParenToken(),
                arguments: printCall.arguments,
                rightParen: .rightParenToken()
            ))
        }
        
        // Reconstruct the message without interpolation
        let messageSegments = firstArg.segments.filter { segment in
            segment.as(ExpressionSegmentSyntax.self) == nil
        }
        
        let message = StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: .init(messageSegments),
            closingQuote: .stringQuoteToken()
        )
        
        // Build the log call
        let logCall = FunctionCallExprSyntax(
            calledExpression: IdentifierExprSyntax(identifier: .identifier("log.\(level)")),
            leftParen: .leftParenToken(),
            arguments: [
                LabelledExprSyntax(
                    label: nil,
                    expression: ExprSyntax(message)
                )
            ],
            rightParen: .rightParenToken()
        )
        
        return ExprSyntax(logCall)
    }
}
