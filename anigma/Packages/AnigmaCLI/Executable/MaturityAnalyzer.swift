//
//  MaturityAnalyzer.swift
//  AnigmaCLIExecutable
//
//  Provides a realistic maturity assessment by scanning the codebase, parsing build logs,
//  and producing actionable suggestions.
//

import Foundation
import AnigmaCLIDatabase

public struct MaturityAssessor {
    private let database: CLIDatabaseActor
    private let workspacePath: URL
    private let buildLogPath: URL?

    public init(
        database: CLIDatabaseActor,
        workspacePath: URL,
        buildLogPath: URL? = nil
    ) {
        self.database = database
        self.workspacePath = workspacePath
        self.buildLogPath = buildLogPath
    }

    public struct MaturityReport {
        public let overallScore: Int
        public let categories: [MaturityCategory]
        public let suggestions: [MaturitySuggestion]
    }

    public struct MaturityCategory {
        public let name: String
        public let score: Int
    }

    public struct MaturitySuggestion {
        public let priority: String
        public let title: String
        public let description: String
    }

    public func assess() async throws -> MaturityReport {
        _ = database
        let metrics = try CodeScanner(workspace: workspacePath).scan()
        let buildFindings = BuildLogAnalyzer.parse(logAt: buildLogPath)

        let securityScore = clamp(
            60,
            value: 92 - metrics.todoCount * 2 - buildFindings.errorCount * 5,
            upper: 95
        )
        let qualityScore = clamp(
            55,
            value: 90 - buildFindings.warningCount * 2 - metrics.todoCount,
            upper: 92
        )
        let testingRatio = metrics.swiftFiles > 0 ? Double(metrics.testFiles) / Double(metrics.swiftFiles) : 0
        let testingScore = clamp(
            40,
            value: Int((testingRatio * 100.0) * 0.9 + 40),
            upper: 100
        )
        let docRatio = metrics.totalFiles > 0 ? Double(metrics.docFiles) / Double(metrics.totalFiles) : 0
        let documentationScore = clamp(
            45,
            value: Int(min(100, docRatio * 200)),
            upper: 100
        )
        let performanceScore = clamp(
            50,
            value: 90 - buildFindings.warningCount * 2,
            upper: 90
        )

        let categories = [
            MaturityCategory(name: "Security", score: securityScore),
            MaturityCategory(name: "Code Quality", score: qualityScore),
            MaturityCategory(name: "Test Coverage", score: testingScore),
            MaturityCategory(name: "Documentation", score: documentationScore),
            MaturityCategory(name: "Performance", score: performanceScore)
        ]

        var suggestions: [MaturitySuggestion] = []

        if metrics.todoCount > 0 {
            suggestions.append(.init(
                priority: "HIGH",
                title: "Resolve TODO/FIXME markers",
                description: "Found \(metrics.todoCount) TODO/FIXME comments in \(metrics.swiftFiles) Swift files; addressing them uncovers unfinished work."
            ))
        }

        if buildFindings.errorCount > 0 {
            suggestions.append(.init(
                priority: "HIGH",
                title: "Fix compiler errors",
                description: "Swift build log reports \(buildFindings.errorCount) errors (e.g., \(buildFindings.sampleErrors.first ?? "see build log"))."
            ))
        }

        if buildFindings.warningCount > 0 {
            suggestions.append(.init(
                priority: "MEDIUM",
                title: "Resolve compiler warnings",
                description: "Swift build emitted \(buildFindings.warningCount) warnings. Sample: \(buildFindings.sampleWarnings.joined(separator: " | "))."
            ))
        }

        if testingRatio < 0.15 {
            suggestions.append(.init(
                priority: "MEDIUM",
                title: "Expand test coverage",
                description: "\(metrics.testFiles) test files found out of \(metrics.swiftFiles) Swift sources. Add targeted tests for critical paths."
            ))
        }

        if documentationScore < 60 {
            suggestions.append(.init(
                priority: "LOW",
                title: "Improve documentation density",
                description: "Documentation files make up \(String(format: "%.1f", docRatio * 100))% of the repository; add DocC/dedicated guides for core modules."
            ))
        }

        if suggestions.isEmpty {
            suggestions.append(.init(
                priority: "LOW",
                title: "Maintain the baseline",
                description: "No immediate red flags detected; keep monitoring build warnings and TODO markers."
            ))
        }

        let overall = (securityScore + qualityScore + testingScore + documentationScore + performanceScore) / categories.count
        return MaturityReport(overallScore: overall, categories: categories, suggestions: suggestions)
    }

    private func clamp(_ lower: Int, value: Int, upper: Int) -> Int {
        return min(max(value, lower), upper)
    }
}

private struct CodeScanner {
    struct Metrics {
        let totalFiles: Int
        let swiftFiles: Int
        let docFiles: Int
        let testFiles: Int
        let todoCount: Int
    }

    let workspace: URL

    func scan() throws -> Metrics {
        let fm = FileManager.default
        var totalFiles = 0
        var swiftFiles = 0
        var docFiles = 0
        var testFiles = 0
        var todoCount = 0

        let enumerator = fm.enumerator(
            at: workspace,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let item = enumerator?.nextObject() as? URL {
            let resource = try item.resourceValues(forKeys: [.isRegularFileKey])
            guard resource.isRegularFile == true else { continue }
            totalFiles += 1

            let path = item.path
            let ext = item.pathExtension.lowercased()

            switch ext {
            case "md", "adoc", "rst":
                docFiles += 1
            case "swift":
                swiftFiles += 1
                if path.contains("/Tests/") || path.contains("/tests/") {
                    testFiles += 1
                }
                if let content = try? String(contentsOf: item, encoding: .utf8) {
                    todoCount += occurrences(of: "TODO", in: content)
                    todoCount += occurrences(of: "FIXME", in: content)
                }
            default:
                if path.contains("/Tests/") || path.contains("/tests/") {
                    testFiles += 1
                }
            }
        }

        return Metrics(
            totalFiles: totalFiles,
            swiftFiles: swiftFiles,
            docFiles: docFiles,
            testFiles: testFiles,
            todoCount: todoCount
        )
    }

    private func occurrences(of token: String, in content: String) -> Int {
        content.components(separatedBy: token).count - 1
    }
}

private struct BuildLogAnalyzer {
    struct Result {
        let warnings: [String]
        let errors: [String]
        var warningCount: Int { warnings.count }
        var errorCount: Int { errors.count }
        var sampleWarnings: [String] { Array(warnings.prefix(3)) }
        var sampleErrors: [String] { Array(errors.prefix(2)) }
    }

    static func parse(logAt url: URL?) -> Result {
        guard
            let url = url,
            FileManager.default.fileExists(atPath: url.path),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return Result(warnings: [], errors: [])
        }

        var warnings: [String] = []
        var errors: [String] = []

        for line in content.components(separatedBy: .newlines) {
            let normalized = line.lowercased()
            if normalized.contains("error:") {
                errors.append(line.trimmingCharacters(in: .whitespaces))
            } else if normalized.contains("warning:") {
                warnings.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        return Result(warnings: warnings, errors: errors)
    }
}
