# OSLog Conversion: SwiftSyntax Approach

## 🎯 Overview

This document outlines how to use SwiftSyntax for precise, safe code transformations from `print()` to `OSLog`. SwiftSyntax provides full syntax tree parsing, making it ideal for complex refactoring tasks.

## 🚀 SwiftSyntax Approach

### Benefits over Regex

- **Type-safe**: Understands Swift syntax structure
- **Precise**: Only transforms intended code
- **Safe**: Won't break existing functionality
- **Maintainable**: Easier to update and extend

### Implementation Steps

#### 1. Add SwiftSyntax Dependency

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
```

#### 2. Create PrintStatementVisitor

```swift
import SwiftSyntax
import SwiftSyntaxBuilder

class PrintStatementVisitor: SyntaxRewriter {
    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        // Check if this is a print() call
        guard let calledExpression = node.calledExpression.as(IdentifierExprSyntax.self),
              calledExpression.identifier.text == "print" else {
            return super.visit(node)
        }
        
        // Transform print() to log.info()
        let newCall = node
            .withCalledExpression(IdentifierExprSyntax(identifier: .identifier("log.info")))
        
        return ExprSyntax(newCall)
    }
}
```

#### 3. Apply Transformation

```swift
let sourceFile = try SyntaxParser.parse(source: originalCode)
let visitor = PrintStatementVisitor(viewMode: .sourceAccurate)
let transformedFile = visitor.visit(sourceFile)

// Get the transformed code
let newCode = transformedFile.description
```

#### 4. Handle Complex Cases

```swift
// For string interpolation
if node.arguments.count > 0,
   case let .argumentList(argumentList) = node.arguments,
   argumentList.count > 0 {
    
    let firstArg = argumentList[0].expression
    // Analyze and transform interpolation
}
```

## 📋 Complete Example

```swift
import SwiftSyntax
import SwiftSyntaxBuilder

struct PrintToOSLogConverter {
    static func convert(source: String) -> String? {
        do {
            let sourceFile = try SyntaxParser.parse(source: source)
            let visitor = PrintStatementVisitor(viewMode: .sourceAccurate)
            let transformed = visitor.visit(sourceFile)
            return transformed.description
        } catch {
            print("Conversion error: \(error)")
            return nil
        }
    }
}

// Usage
let originalCode = """
func test() {
    print("Hello, world!")
    print("Value: \(x)")
}
"""

if let converted = PrintToOSLogConverter.convert(source: originalCode) {
    print("Converted successfully:")
    print(converted)
}
```

## 🔧 Advanced Features

### Privacy Annotations

```swift
// Detect variables in string interpolation
if let stringLiteral = firstArg.as(StringLiteralExprSyntax.self) {
    let hasInterpolation = stringLiteral.segments.contains {
        $0.as(ExpressionSegmentSyntax.self) != nil
    }
    
    if hasInterpolation {
        // Add privacy annotations
    }
}
```

### Log Levels

```swift
// Analyze message content for log level
func determineLogLevel(from message: String) -> String {
    if message.localizedCaseInsensitiveContains("error") ||
       message.localizedCaseInsensitiveContains("failed") {
        return "error"
    } else if message.localizedCaseInsensitiveContains("warning") {
        return "warning"
    }
    return "info"
}
```

## 📚 Resources

- [SwiftSyntax GitHub](https://github.com/apple/swift-syntax)
- [SwiftSyntax Documentation](https://swiftpackageindex.com/apple/swift-syntax/main/documentation/swiftsyntax)
- [WWDC: Build SwiftMacros](https://developer.apple.com/videos/play/wwdc2022/110358/)

## 🎯 When to Use SwiftSyntax vs Regex

### Use SwiftSyntax when:
- Precision is critical
- Code structure matters
- Working with complex interpolation
- Need to preserve comments/formatting

### Use Regex when:
- Quick bulk transformations
- Simple pattern replacements
- Prototyping/concept validation
- Working with non-Swift files

## 🔄 Hybrid Approach

For large codebases like Anigma, consider:

1. **Bulk conversion** with enhanced regex (current script)
2. **Critical files** with SwiftSyntax (manual review)
3. **Test suite** to validate transformations
4. **Incremental adoption** of SwiftSyntax

This provides the best balance of speed and safety.