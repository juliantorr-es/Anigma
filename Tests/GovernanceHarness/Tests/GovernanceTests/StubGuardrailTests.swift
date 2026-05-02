//
//  StubGuardrailTests.swift
//  GovernanceHarness - Stub Detection Guardrails
//
//  Regression guards that prevent silent stubs from being added to the codebase.
//  Silent stubs are implementation placeholders that return success-like values
//  (nil, [], 0, false, true) without logging warnings or throwing errors.
//
//  This test fails loudly when:
//  1. New silent stub patterns are detected (returns with "placeholder"/"stub" comments but no warning)
//  2. Loud stubs exist without STUB_TRACK markers for inventory
//

import XCTest
import Foundation

/// Guardrail test that prevents silent stub regressions.
///
/// **Purpose**: Ensure all stubs are loud (warn before return/throw) and tracked (have STUB_TRACK markers).
///
/// **What is a silent stub?**
/// - Returns nil/[]/0/false/true with comment like "Placeholder" or "Stub"
/// - Does NOT print a warning before returning
/// - Makes code appear to work when it doesn't
///
/// **What is a loud stub?**
/// - Prints "⚠️  STUB INVOKED: ModuleName.functionName()" before return/throw
/// - Should have STUB_TRACK marker for inventory tracking
/// - Makes stub invocation immediately visible in logs
///
/// **How it works**:
/// - Scans Swift files for stub patterns
/// - Detects silent stubs (commented placeholders without warnings)
/// - Detects loud stubs without tracking markers
/// - Fails the test with specific file:line locations for remediation
///
final class StubGuardrailTests: XCTestCase {
    
    private let repoRoot = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()  // GovernanceTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // GovernanceHarness
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // Anigma_clean
    
    /// Test that detects silent stub patterns and fails with specific locations.
    func testNoSilentStubs() throws {
        let violations = try scanForSilentStubs()
        
        if !violations.isEmpty {
            let report = violations.map { v in
                """
                
                ❌ SILENT STUB DETECTED:
                   File: \(v.file)
                   Line: \(v.line)
                   Pattern: \(v.pattern)
                   Code: \(v.snippet)
                   
                   FIX: Add warning before return:
                   print("⚠️  STUB INVOKED: ModuleName.functionName()")
                   print("   [Explain why this is a stub and what it returns]")
                """
            }.joined(separator: "\n")
            
            XCTFail("""
                
                ==========================================
                STUB GUARDRAIL VIOLATION
                ==========================================
                
                Found \(violations.count) silent stub(s).
                
                Silent stubs return placeholder values without logging warnings.
                This makes code appear to work when it doesn't.
                
                \(report)
                
                ==========================================
                See STUB_INVENTORY_QUICK_REF.md for stub patterns.
                ==========================================
                """)
        }
    }
    
    /// Test that loud stubs have STUB_TRACK markers for inventory.
    func testLoudStubsAreTracked() throws {
        let loudStubs = try scanForLoudStubs()
        let trackedStubs = try scanForStubTrackMarkers()
        
        // Find loud stubs that don't have corresponding STUB_TRACK markers
        var untracked: [StubLocation] = []
        
        for stub in loudStubs {
            // Check if there's a STUB_TRACK marker in the same file within 5 lines
            let hasTracker = trackedStubs.contains { tracker in
                tracker.file == stub.file && tracker.line < stub.line && (stub.line - tracker.line) <= 5
            }
            
            if !hasTracker {
                untracked.append(stub)
            }
        }
        
        if !untracked.isEmpty {
            let report = untracked.map { stub in
                """
                
                ⚠️  UNTRACKED LOUD STUB:
                   File: \(stub.file)
                   Line: \(stub.line)
                   Code: \(stub.snippet)
                   
                   FIX: Add STUB_TRACK marker above the stub:
                   // STUB_TRACK: stub-id – Brief description
                """
            }.joined(separator: "\n")
            
            XCTFail("""
                
                ==========================================
                STUB TRACKING VIOLATION
                ==========================================
                
                Found \(untracked.count) loud stub(s) without STUB_TRACK markers.
                
                All loud stubs should be tracked in the inventory.
                
                \(report)
                
                ==========================================
                Tracked stubs can be monitored and prioritized for implementation.
                ==========================================
                """)
        }
    }

    /// Protects detector coverage for string/dictionary placeholder returns.
    func testInlineSilentStubPatternDetectsStringAndDictionaryPlaceholders() {
        XCTAssertEqual(
            inlineSilentStubPattern(in: "return \"\"  // Placeholder"),
            "return empty string with placeholder comment"
        )
        XCTAssertEqual(
            inlineSilentStubPattern(in: "return [:] // Stub value"),
            "return [:] with placeholder comment"
        )
    }

    /// Protects detector coverage for Data/UUID placeholder returns.
    func testInlineSilentStubPatternDetectsDataAndUUIDPlaceholders() {
        XCTAssertEqual(
            inlineSilentStubPattern(in: "return Data() // Not implemented"),
            "return Data() with placeholder comment"
        )
        XCTAssertEqual(
            inlineSilentStubPattern(in: "return UUID() // Unimplemented"),
            "return UUID() with placeholder comment"
        )
    }
    
    // MARK: - Scanning Implementation
    
    private func scanForSilentStubs() throws -> [StubViolation] {
        var violations: [StubViolation] = []
        let sourceRoot = repoRoot.appendingPathComponent("anigma")
        
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else {
            throw XCTSkip("Source root not found at \(sourceRoot.path)")
        }
        
        let swiftFiles = try collectSwiftFiles(in: sourceRoot)
        
        for fileURL in swiftFiles {
            guard isProductionSource(fileURL) else {
                continue
            }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                let lineNumber = index + 1
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if let patternName = inlineSilentStubPattern(in: trimmed) {
                    if !hasRecentStubWarning(lines, lineIndex: index) {
                        appendViolation(
                            &violations,
                            sourceRoot: sourceRoot,
                            fileURL: fileURL,
                            line: lineNumber,
                            pattern: patternName,
                            snippet: trimmed
                        )
                    }
                    continue
                }

                guard let signal = suspiciousCommentSignal(in: trimmed) else {
                    continue
                }

                for lookahead in 1...5 {
                    let candidateIndex = index + lookahead
                    guard candidateIndex < lines.count else { break }

                    let candidate = lines[candidateIndex].trimmingCharacters(in: .whitespaces)
                    guard !candidate.isEmpty, !candidate.hasPrefix("//"), !candidate.hasPrefix("/*"), !candidate.hasPrefix("*") else {
                        continue
                    }

                    guard isSuspiciousPlaceholderImplementation(candidate, signal: signal) else {
                        continue
                    }

                    if !hasRecentStubWarning(lines, lineIndex: index) && !hasRecentStubWarning(lines, lineIndex: candidateIndex) {
                        appendViolation(
                            &violations,
                            sourceRoot: sourceRoot,
                            fileURL: fileURL,
                            line: lineNumber,
                            pattern: signal == .strong ? "comment-linked placeholder implementation" : "comment-linked TODO placeholder",
                            snippet: "\(trimmed) -> \(candidate)"
                        )
                    }
                    break
                }
            }
        }
        
        return violations
    }
    
    private func scanForLoudStubs() throws -> [StubLocation] {
        var stubs: [StubLocation] = []
        let sourceRoot = repoRoot.appendingPathComponent("anigma")
        
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else {
            return []
        }
        
        let swiftFiles = try collectSwiftFiles(in: sourceRoot)
        
        for fileURL in swiftFiles {
            guard isProductionSource(fileURL) else {
                continue
            }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                // Look for loud stub markers
                if line.contains("⚠️") && line.contains("STUB INVOKED") {
                    let relativePath = fileURL.path.replacingOccurrences(of: sourceRoot.path + "/", with: "")
                    stubs.append(StubLocation(
                        file: relativePath,
                        line: index + 1,
                        snippet: line.trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }
        
        return stubs
    }
    
    private func scanForStubTrackMarkers() throws -> [StubLocation] {
        var markers: [StubLocation] = []
        let sourceRoot = repoRoot.appendingPathComponent("anigma")
        
        guard FileManager.default.fileExists(atPath: sourceRoot.path) else {
            return []
        }
        
        let swiftFiles = try collectSwiftFiles(in: sourceRoot)
        
        for fileURL in swiftFiles {
            guard isProductionSource(fileURL) else {
                continue
            }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                if line.contains("STUB_TRACK:") {
                    let relativePath = fileURL.path.replacingOccurrences(of: sourceRoot.path + "/", with: "")
                    markers.append(StubLocation(
                        file: relativePath,
                        line: index + 1,
                        snippet: line.trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }
        
        return markers
    }
    
    private func collectSwiftFiles(in directory: URL) throws -> [URL] {
        var files: [URL] = []
        
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "swift" {
                    files.append(fileURL)
                }
            }
        }
        
        return files
    }

    private func isProductionSource(_ fileURL: URL) -> Bool {
        let path = fileURL.path

        guard path.hasSuffix(".swift") else { return false }
        guard !path.hasSuffix("Package.swift") else { return false }
        guard !path.contains("/Tests/") else { return false }
        guard !path.contains("/Tools/Vendor/") else { return false }
        guard !path.contains("/.build/") else { return false }
        guard !path.contains("/Docs/") else { return false }
        guard !path.contains("/.github/") else { return false }
        guard !path.contains(".backup") else { return false }

        return path.contains("/Sources/")
            || path.contains("/Packages/")
            || path.contains("/App/")
            || path.contains("/CLI/")
            || path.contains("/RuntimeCore/")
            || path.contains("/PlatformAdapters/")
    }

    private func inlineSilentStubPattern(in line: String) -> String? {
        let silentPatterns: [(pattern: String, regex: NSRegularExpression)] = [
            ("return nil with placeholder comment", try! NSRegularExpression(pattern: "return\\s+nil.*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return [] with placeholder comment", try! NSRegularExpression(pattern: "return\\s+\\[\\].*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return 0 with placeholder comment", try! NSRegularExpression(pattern: "return\\s+0(\\.0)?\\b.*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return false with placeholder comment", try! NSRegularExpression(pattern: "return\\s+false.*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return true with placeholder comment", try! NSRegularExpression(pattern: "return\\s+true.*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return empty string with placeholder comment", try! NSRegularExpression(pattern: "return\\s+\"\".*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return [:] with placeholder comment", try! NSRegularExpression(pattern: "return\\s+\\[:\\].*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return Data() with placeholder comment", try! NSRegularExpression(pattern: "return\\s+Data\\(\\).*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("return UUID() with placeholder comment", try! NSRegularExpression(pattern: "return\\s+UUID\\(\\).*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: [])),
            ("generic variable return with placeholder comment", try! NSRegularExpression(pattern: "return\\s+[a-z][a-zA-Z0-9]*\\s*//.*([Pp]laceholder|[Ss]tub|[Nn]ot.*implemented|[Uu]nimplemented)", options: []))
        ]

        for (patternName, regex) in silentPatterns {
            let range = NSRange(line.startIndex..., in: line)
            if regex.firstMatch(in: line, options: [], range: range) != nil {
                return patternName
            }
        }

        return nil
    }

    private enum CommentSignal {
        case strong
        case todo
    }

    private func suspiciousCommentSignal(in line: String) -> CommentSignal? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        if lowercased.contains("stub")
            || lowercased.contains("placeholder")
            || lowercased.contains("not implemented")
            || lowercased.contains("unimplemented") {
            return .strong
        }

        if lowercased.contains("todo") {
            return .todo
        }

        return nil
    }

    private func isSuspiciousPlaceholderImplementation(_ line: String, signal: CommentSignal) -> Bool {
        switch signal {
        case .strong:
            return line.hasPrefix("return ")
                || line.hasPrefix("throw ")
                || isPlaceholderAssignment(line)
        case .todo:
            return (line.hasPrefix("return ") && isPlaceholderReturn(line))
                || isPlaceholderAssignment(line)
        }
    }

    private func isPlaceholderReturn(_ line: String) -> Bool {
        let normalized = line.replacingOccurrences(of: " ", with: "")
        return normalized.contains("??")
            || normalized.contains("=nil")
            || normalized.contains("=[]")
            || normalized.contains("=false")
            || normalized.contains("=true")
            || normalized.contains("=0")
            || normalized.contains("=0.0")
            || normalized.contains("=\"")
            || normalized.contains("=Data()")
            || normalized.contains("=UUID()")
            || normalized.contains("=[:]")
            || normalized.contains("placeholder")
            || normalized.contains("stub")
    }

    private func isPlaceholderAssignment(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains(" = ") else { return false }
        guard !trimmed.contains("func ") && !trimmed.contains("init(") else { return false }

        let rhs = trimmed.components(separatedBy: "=").dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
        return rhs.hasPrefix("nil")
            || rhs.hasPrefix("[]")
            || rhs.hasPrefix("false")
            || rhs.hasPrefix("true")
            || rhs.hasPrefix("0")
            || rhs.hasPrefix("\"")
            || rhs.hasPrefix("Data()")
            || rhs.hasPrefix("UUID()")
            || rhs.hasPrefix("[:]")
    }

    private func hasRecentStubWarning(_ lines: [String], lineIndex: Int) -> Bool {
        let lowerBound = max(0, lineIndex - 5)
        return (lowerBound..<lineIndex).contains { checkIndex in
            let checkLine = lines[checkIndex]
            return checkLine.contains("⚠️") && checkLine.contains("STUB")
        }
    }

    private func appendViolation(
        _ violations: inout [StubViolation],
        sourceRoot: URL,
        fileURL: URL,
        line: Int,
        pattern: String,
        snippet: String
    ) {
        let relativePath = fileURL.path.replacingOccurrences(of: sourceRoot.path + "/", with: "")
        violations.append(StubViolation(
            file: relativePath,
            line: line,
            pattern: pattern,
            snippet: snippet
        ))
    }
    
    // MARK: - Models
    
    private struct StubViolation {
        let file: String
        let line: Int
        let pattern: String
        let snippet: String
    }
    
    private struct StubLocation {
        let file: String
        let line: Int
        let snippet: String
    }
}
