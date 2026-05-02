#!/usr/bin/env python3

"""
SwiftSyntax-based OSLog Converter
Prioritizes safety and precision for critical backend files
"""

import os
import subprocess
import tempfile
from pathlib import Path

def create_swiftsyntax_converter():
    """Create a Swift package with SwiftSyntax converter"""
    
    # Create a temporary directory for the converter package
    converter_dir = Path("anigma/OSLogSwiftSyntaxConverter")
    converter_dir.mkdir(exist_ok=True)
    
    # Create Package.swift
    package_swift = converter_dir / "Package.swift"
    package_swift.write_text("""
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OSLogSwiftSyntaxConverter",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "oslog-converter", targets: ["OSLogConverter"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OSLogConverter",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        )
    ]
)
""")

    # Create main converter file
    converter_file = converter_dir / "Sources" / "OSLogConverter" / "main.swift"
    converter_file.parent.mkdir(parents=True, exist_ok=True)
    
    converter_file.write_text("""
import Foundation
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
""")
    
    return converter_dir

def build_swiftsyntax_converter():
    """Build the SwiftSyntax converter using Swift Package Manager"""
    converter_dir = create_swiftsyntax_converter()
    
    print("🛠️ Building SwiftSyntax converter...")
    
    try:
        # Build the converter
        result = subprocess.run(
            ["swift", "build", "--configuration", "release"],
            cwd=converter_dir,
            capture_output=True,
            text=True,
            timeout=300
        )
        
        if result.returncode == 0:
            print("✅ SwiftSyntax converter built successfully!")
            return converter_dir / ".build" / "release" / "oslog-converter"
        else:
            print("❌ Build failed:")
            print(result.stderr)
            return None
            
    except subprocess.TimeoutExpired:
        print("❌ Build timed out")
        return None
    except Exception as e:
        print(f"❌ Build error: {e}")
        return None

def convert_with_swiftsyntax(converter_path: Path, input_file: Path, output_file: Path) -> bool:
    """Convert a single file using SwiftSyntax"""
    try:
        result = subprocess.run(
            [str(converter_path), str(input_file), str(output_file)],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        return result.returncode == 0
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        return False

def identify_critical_files() -> list[Path]:
    """Identify files that should use SwiftSyntax conversion"""
    critical_files = []
    
    # Security modules
    security_dir = Path("anigma/Packages/HarmoniaModule/Security")
    if security_dir.exists():
        critical_files.extend(
            security_dir.glob("*.swift")
        )
    
    # Core runtime modules
    runtime_dirs = [
        "anigma/Packages/HarmoniaModule/Spine",
        "anigma/Packages/HarmoniaModule/Planning",
        "anigma/Packages/HarmoniaModule/Doctrine",
    ]
    
    for dir_path in runtime_dirs:
        dir = Path(dir_path)
        if dir.exists():
            critical_files.extend(
                dir.glob("*.swift")
            )
    
    return critical_files

def main():
    print("🚀 Starting SwiftSyntax-based OSLog conversion")
    print("=" * 60)
    
    # Step 1: Build the converter
    converter_path = build_swiftsyntax_converter()
    
    if not converter_path or not converter_path.exists():
        print("❌ Failed to build SwiftSyntax converter")
        print("Falling back to regex-based approach...")
        return False
    
    # Step 2: Identify critical files
    critical_files = identify_critical_files()
    print(f"📊 Found {len(critical_files)} critical files for SwiftSyntax conversion")
    
    # Step 3: Convert critical files
    success_count = 0
    for file_path in critical_files:
        print(f"🔧 Processing {file_path.name}...")
        
        # Create backup
        backup_path = file_path.with_suffix(file_path.suffix + ".backup")
        try:
            file_path.rename(backup_path)
        except Exception as e:
            print(f"⚠️ Could not create backup: {e}")
            continue
        
        # Convert with SwiftSyntax
        if convert_with_swiftsyntax(converter_path, backup_path, file_path):
            print(f"✅ Converted {file_path.name}")
            success_count += 1
            
            # Clean up backup
            try:
                backup_path.unlink()
            except:
                pass
        else:
            print(f"❌ Failed to convert {file_path.name}")
            # Restore original
            try:
                backup_path.rename(file_path)
            except:
                pass
    
    print("\n" + "=" * 60)
    print(f"✅ SwiftSyntax conversion complete!")
    print(f"📋 Files converted: {success_count}/{len(critical_files)}")
    print(f"🎯 Success rate: {success_count/len(critical_files)*100:.1f}%")
    
    return True

if __name__ == "__main__":
    main()