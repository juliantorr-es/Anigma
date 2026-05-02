//
//  DoctrinalScouts.swift
//  HarmoniaModule
//
//  Scouts that check for doctrine violations in code.
//  Turns "college-level wisdom" into concrete findings.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore

// MARK: - Code Quality Scout

/// Scout that detects code quality issues.
public struct CodeQualityScout: DoctrinalScout {
    public let domain: DoctrineDomain = .quality

    public init() {}

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }

        let source = try String(contentsOfFile: path, encoding: .utf8)
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        // Simple string-based analysis for now
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }

            // Check for common code quality issues
            violations.append(contentsOf: checkLineQuality(line: trimmedLine, filePath: path, lineNumber: lineNumber))
        }

        return violations
    }

    private func checkLineQuality(line: String, filePath: String, lineNumber: Int) -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lowerLine = line.lowercased()

        // Check for TODO/FIXME comments in production code
        if lowerLine.contains("todo:") || lowerLine.contains("fixme:") {
            violations.append(DoctrineViolation(
                ruleId: "quality-001",
                severity: .warning,
                message: "TODO/FIXME comment found in production code",
                filePath: filePath,
                lineNumber: lineNumber,
                context: line
            ))
        }

        // Check for force unwrapping
        if line.contains("!") {
            violations.append(DoctrineViolation(
                ruleId: "quality-002",
                severity: .warning,
                message: "Force unwrapping detected - consider optional binding",
                filePath: filePath,
                lineNumber: lineNumber,
                context: line
            ))
        }

        // Check for long lines
        if line.count > 120 {
            violations.append(DoctrineViolation(
                ruleId: "quality-003",
                severity: .info,
                message: "Line exceeds 120 characters",
                filePath: filePath,
                lineNumber: lineNumber,
                context: String(line.prefix(120)) + "..."
            ))
        }

        return violations
    }
}

// MARK: - Security Scout (Simplified)

/// Scout that detects basic security issues.
public struct BasicSecurityScout: DoctrinalScout {
    public let domain: DoctrineDomain = .security

    public init() {}

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }

        let source = try String(contentsOfFile: path, encoding: .utf8)
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }

            violations.append(contentsOf: checkBasicSecurity(line: trimmedLine, filePath: path, lineNumber: lineNumber))
        }

        return violations
    }

    private func checkBasicSecurity(line: String, filePath: String, lineNumber: Int) -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lowerLine = line.lowercased()

        // Check for hardcoded secrets
        let secretPatterns = ["password", "secret", "token", "key", "api_key"]
        for pattern in secretPatterns {
            if lowerLine.contains(pattern) {
                violations.append(DoctrineViolation(
                    ruleId: "sec-basic-001",
                    severity: .error,
                    message: "Potential hardcoded secret detected",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    context: line
                ))
            }
        }

        // Check for insecure protocols
        if lowerLine.contains("http://") && !lowerLine.contains("https://") {
            violations.append(DoctrineViolation(
                ruleId: "sec-basic-002",
                severity: .error,
                message: "Insecure HTTP protocol detected",
                filePath: filePath,
                lineNumber: lineNumber,
                context: line
            ))
        }

        return violations
    }
}

// MARK: - Architecture Scout

/// Scout that detects architectural issues.
public struct ArchitectureScout: DoctrinalScout {
    public let domain: DoctrineDomain = .architecture

    public init() {}

    public func scan(fileAt path: String) async throws -> [DoctrineViolation] {
        guard path.hasSuffix(".swift") else { return [] }

        let source = try String(contentsOfFile: path, encoding: .utf8)
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        var classCount = 0
        var methodCount = 0
        var fileLength = 0

        for (index, line) in lines.enumerated() {
            _ = index + 1  // lineNumber unused
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            fileLength += line.count

            // Count classes and methods
            if trimmedLine.hasPrefix("class ") {
                classCount += 1
            }
            if trimmedLine.contains("func ") {
                methodCount += 1
            }
        }

        // Check file size
        if fileLength > 5000 { // Large file threshold
            violations.append(DoctrineViolation(
                ruleId: "arch-001",
                severity: .warning,
                message: "File is large (\(fileLength) chars) - consider splitting",
                filePath: path,
                lineNumber: 1,
                context: "File has \(classCount) classes and \(methodCount) methods"
            ))
        }

        // Check class count
        if classCount > 5 {
            violations.append(DoctrineViolation(
                ruleId: "arch-002",
                severity: .info,
                message: "Multiple classes in single file (\(classCount))",
                filePath: path,
                lineNumber: 1,
                context: "Consider separating into multiple files"
            ))
        }

        return violations
    }
}
