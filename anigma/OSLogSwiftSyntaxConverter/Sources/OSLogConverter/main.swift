import SwiftSyntax
import SwiftParser

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
            
            // Simple transformation: just replace print with log.info
            let transformed = sourceFile.walk { node in
                if let functionCall = node.as(FunctionCallExprSyntax.self),
                   let identifier = functionCall.calledExpression.as(IdentifierExprSyntax.self),
                   identifier.identifier.text == "print" {
                    return FunctionCallExprSyntax(
                        calledExpression: IdentifierExprSyntax(identifier: .identifier("log")),
                        leftParen: .leftParenToken(),
                        arguments: functionCall.arguments,
                        rightParen: .rightParenToken()
                    )
                }
                return node
            }
            
            try transformed.description.write(to: outputURL, atomically: true, encoding: .utf8)
            print("✅ Successfully converted \(inputPath)")
            
        } catch {
            print("❌ Error converting \(inputPath): \(error)")
            exit(1)
        }
    }
}
