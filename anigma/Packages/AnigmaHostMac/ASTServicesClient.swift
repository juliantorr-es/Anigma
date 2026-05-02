//
//  ASTServicesClient.swift
//  AnigmaHostMac
//
//  AST analysis and code intelligence client.
//

import Foundation
import CryptoKit
import AnigmaASTServicesCore
import AnigmaPrimitives

public struct ASTServicesClient: Sendable {
    public init() {}

    public func parse(filePath: String, language _: String) async throws -> ASTParseResponse {
        let start = Date()
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        let _ = try await performWorker(task: .parse, filePath: filePath, visitors: [])
        let parseTree = buildParseTree(source: source, filePath: filePath)
        return ASTParseResponse(ast: parseTree, parseTime: Date().timeIntervalSince(start))
    }

    public func analyze(filePath: String, checks: [String] = []) async throws -> ASTAnalysisResponse {
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        let result = try await performWorker(task: .analyze, filePath: filePath, visitors: checks)

        guard result.ok else {
            throw ASTServicesError.executionFailed(message: result.error?.message ?? "Analysis failed")
        }

        let findings = result.findings ?? []
        return ASTAnalysisResponse(
            issues: findings.map { finding in
                AnalysisIssue(
                    id: "\(finding.ruleId)-\(finding.lineNumber)-\(finding.columnNumber ?? 0)",
                    severity: finding.severity,
                    message: finding.message,
                    location: SourceRange(
                        start: SourcePosition(
                            line: finding.lineNumber,
                            column: finding.columnNumber ?? 1
                        ),
                        end: SourcePosition(
                            line: finding.lineNumber,
                            column: (finding.columnNumber ?? 1) + max(finding.message.count, 1)
                        )
                    )
                )
            },
            metrics: makeMetrics(source: source, findings: findings)
        )
    }

    public func refactor(filePath: String, operation: RefactorOperation) async throws -> RefactorResponse {
        let source = try String(contentsOfFile: filePath, encoding: .utf8)

        guard let anchor = resolveAnchor(for: operation, source: source, filePath: filePath) else {
            return RefactorResponse(
                success: false,
                diff: "No compatible refactor anchor found for \(operation.type).",
                affectedFiles: []
            )
        }

        let supportedRuleNames = ["add-sendable", "add-sendable-to-value-types"]
        let requestedRule = operation.params["rule"] ?? operation.type
        guard supportedRuleNames.contains(requestedRule) else {
            return RefactorResponse(
                success: false,
                diff: "Unsupported refactor operation: \(operation.type)",
                affectedFiles: []
            )
        }

        let pipeline = RewritePipeline(
            rules: [AddSendableToValueTypesRule()],
            config: PipelineConfig(dryRun: false)
        )

        let result = await pipeline.execute(on: [
            RewritePipeline.PipelineItem(filePath: filePath, astAnchor: anchor)
        ])

        let affectedFiles = Array(Set(result.outcomes.map(\.filePath)))
        let summary = makeRefactorSummary(result: result)

        return RefactorResponse(
            success: result.errors.isEmpty,
            diff: summary,
            affectedFiles: affectedFiles
        )
    }

    public func findReferences(symbol: String, directory: String) async throws -> ReferencesResponse {
        let files = try collectSwiftFiles(in: directory)
        var references: [SymbolReference] = []

        for file in files {
            let source = try String(contentsOfFile: file, encoding: .utf8)
            references.append(contentsOf: searchReferences(
                symbol: symbol,
                source: source,
                filePath: file
            ))
        }

        return ReferencesResponse(references: references, count: references.count)
    }

    public func getSymbols(filePath: String) async throws -> SymbolsResponse {
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        return SymbolsResponse(symbols: extractSymbols(from: source, filePath: filePath))
    }

    private func performWorker(
        task: ASTTaskKind,
        filePath: String,
        visitors: [String]
    ) async throws -> ASTResult {
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        let fileData = Data(source.utf8)
        let fileHash = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()

        let request = ASTWorkerRequest(
            requestId: UUID().uuidString,
            runId: "host-mac",
            stepId: "ast-\(task.rawValue)",
            task: task,
            inputs: [ASTArtifactRef(path: filePath, hash: fileHash)],
            options: ASTTaskOptions(visitors: visitors)
        )

        let worker = ASTWorker()
        let response = try await worker.performTask(request)
        guard response.status == .completed, let output = response.outputs.first else {
            throw ASTServicesError.executionFailed(message: response.errorMessage ?? "AST worker failed")
        }

        let resultData = try Data(contentsOf: URL(fileURLWithPath: output.path))
        return try JSONDecoder().decode(ASTResult.self, from: resultData)
    }

    private func buildParseTree(source: String, filePath: String) -> ASTNode {
        let symbols = extractSymbols(from: source, filePath: filePath)
        let lineCount = max(source.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
        let lastLineLength = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .last?
            .utf8.count ?? 0

        return ASTNode(
            type: "sourceFile",
            range: SourceRange(
                start: SourcePosition(line: 1, column: 1),
                end: SourcePosition(line: lineCount, column: lastLineLength + 1)
            ),
            children: symbols.map { symbol in
                ASTNode(type: symbol.kind, range: symbol.location, children: nil)
            }
        )
    }

    private func makeMetrics(source: String, findings: [ASTFinding]) -> CodeMetrics {
        let nonEmptyLines = source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count

        let complexity = max(1, findings.count + 1)
        let maintainability = max(0, min(100, 100 - (findings.count * 4) - (nonEmptyLines / 25)))

        return CodeMetrics(
            complexity: complexity,
            linesOfCode: nonEmptyLines,
            maintainability: Double(maintainability)
        )
    }

    private func resolveAnchor(
        for operation: RefactorOperation,
        source: String,
        filePath: String
    ) -> AstAnchor? {
        if let anchorJSON = operation.params["anchor"],
           let decoded = AstAnchor.decode(from: anchorJSON) {
            return decoded
        }

        let targetName = operation.params["typeName"] ?? operation.params["symbol"] ?? operation.params["name"]
        let lines = source.components(separatedBy: .newlines)
        var lineStartOffset = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let match = nominalDeclarationMatch(in: trimmed, targetName: targetName) else {
                lineStartOffset += line.utf8.count + 1
                continue
            }

            let keywordOffset = line.range(of: match.keyword)?.lowerBound ?? line.startIndex
            let startOffset = lineStartOffset + line[..<keywordOffset].utf8.count
            let endOffset = lineStartOffset + line.utf8.count
            let fingerprint = AstAnchor.fingerprint(
                sourceText: source,
                startOffset: startOffset,
                endOffset: endOffset
            )
            let hash = blake3Hex(source)

            return AstAnchor(
                filePath: filePath,
                contentHash: hash,
                startOffset: startOffset,
                endOffset: endOffset,
                nodeKind: match.keyword,
                contextFingerprint: fingerprint
            )
        }

        return nil
    }

    private func nominalDeclarationMatch(in line: String, targetName: String?) -> (keyword: String, name: String)? {
        let keywords = ["struct", "class", "enum", "actor", "protocol"]

        for keyword in keywords {
            guard let keywordRange = line.range(of: "\(keyword) ") else { continue }
            let tail = line[keywordRange.upperBound...].trimmingCharacters(in: .whitespaces)
            let candidate = tail
                .prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                .description

            guard !candidate.isEmpty else { continue }
            if let targetName, candidate != targetName {
                continue
            }

            return (keyword: keyword, name: candidate)
        }

        return nil
    }

    private func makeRefactorSummary(result: PipelineResult) -> String {
        if result.changes.isEmpty {
            return result.errors.isEmpty ? "No refactor changes were required." : result.errors.map(\.description).joined(separator: "\n")
        }

        let changeSummaries = result.changes.map { change in
            """
            \(change.ruleName) @ \(change.filePath):\(change.startLine):\(change.startColumn)
            - \(change.oldText)
            + \(change.newText)
            """
        }

        return changeSummaries.joined(separator: "\n")
    }

    private func collectSwiftFiles(in directory: String) throws -> [String] {
        let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var files: [String] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            files.append(fileURL.path)
        }
        return files
    }

    private func searchReferences(
        symbol: String,
        source: String,
        filePath: String
    ) -> [SymbolReference] {
        let lines = source.components(separatedBy: .newlines)
        var references: [SymbolReference] = []

        for (index, line) in lines.enumerated() {
            var searchRange = line.startIndex..<line.endIndex
            while let match = line.range(of: symbol, range: searchRange) {
                let column = line[..<match.lowerBound].utf8.count + 1
                let context = contextLines(for: lines, at: index)
                let id = "\(filePath):\(index + 1):\(column)"
                references.append(SymbolReference(
                    id: id,
                    filePath: filePath,
                    location: SourceRange(
                        start: SourcePosition(line: index + 1, column: column),
                        end: SourcePosition(line: index + 1, column: column + symbol.count)
                    ),
                    context: context
                ))

                searchRange = match.upperBound..<line.endIndex
            }
        }

        return references
    }

    private func extractSymbols(from source: String, filePath: String) -> [Symbol] {
        let lines = source.components(separatedBy: .newlines)
        var symbols: [Symbol] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let match = nominalDeclarationMatch(in: trimmed, targetName: nil) else { continue }
            guard let keywordRange = line.range(of: match.keyword) else { continue }

            let column = line[..<keywordRange.lowerBound].utf8.count + 1
            let id = "\(filePath):\(index + 1):\(column):\(match.name)"
            symbols.append(Symbol(
                id: id,
                name: match.name,
                kind: match.keyword,
                location: SourceRange(
                    start: SourcePosition(line: index + 1, column: column),
                    end: SourcePosition(line: index + 1, column: column + max(match.keyword.count, match.name.count))
                )
            ))
        }

        return uniqueSymbols(symbols)
    }

    private func uniqueSymbols(_ symbols: [Symbol]) -> [Symbol] {
        var seen = Set<String>()
        var unique: [Symbol] = []

        for symbol in symbols {
            if seen.insert(symbol.id).inserted {
                unique.append(symbol)
            }
        }

        return unique
    }

    private func contextLines(for lines: [String], at index: Int, radius: Int = 2) -> String {
        let start = max(0, index - radius)
        let end = min(lines.count - 1, index + radius)
        return lines[start...end].joined(separator: "\n")
    }

    private func blake3Hex(_ string: String) -> String {
        return BLAKE3Digest.hex(of: string)
    }
}

public struct ASTParseResponse: Codable {
    public let ast: ASTNode
    public let parseTime: Double
    
    public init(ast: ASTNode, parseTime: Double) {
        self.ast = ast
        self.parseTime = parseTime
    }
}

public struct ASTNode: Codable {
    public let type: String
    public let range: SourceRange
    public let children: [ASTNode]?
    
    public init(type: String, range: SourceRange, children: [ASTNode]? = nil) {
        self.type = type
        self.range = range
        self.children = children
    }
}

public struct SourceRange: Codable {
    public let start: SourcePosition
    public let end: SourcePosition
    
    public init(start: SourcePosition, end: SourcePosition) {
        self.start = start
        self.end = end
    }
}

public struct SourcePosition: Codable {
    public let line: Int
    public let column: Int
    
    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public struct ASTAnalysisResponse: Codable {
    public let issues: [AnalysisIssue]
    public let metrics: CodeMetrics
    
    public init(issues: [AnalysisIssue], metrics: CodeMetrics) {
        self.issues = issues
        self.metrics = metrics
    }
}

public struct AnalysisIssue: Codable, Identifiable {
    public let id: String
    public let severity: String
    public let message: String
    public let location: SourceRange
    
    public init(id: String, severity: String, message: String, location: SourceRange) {
        self.id = id
        self.severity = severity
        self.message = message
        self.location = location
    }
}

public struct CodeMetrics: Codable {
    public let complexity: Int
    public let linesOfCode: Int
    public let maintainability: Double
    
    public init(complexity: Int, linesOfCode: Int, maintainability: Double) {
        self.complexity = complexity
        self.linesOfCode = linesOfCode
        self.maintainability = maintainability
    }
}

public struct RefactorOperation: Codable {
    public let type: String
    public let params: [String: String]
    
    public init(type: String, params: [String: String]) {
        self.type = type
        self.params = params
    }
}

public struct RefactorResponse: Codable {
    public let success: Bool
    public let diff: String
    public let affectedFiles: [String]
    
    public init(success: Bool, diff: String, affectedFiles: [String]) {
        self.success = success
        self.diff = diff
        self.affectedFiles = affectedFiles
    }
}

public struct ReferencesResponse: Codable {
    public let references: [SymbolReference]
    public let count: Int
    
    public init(references: [SymbolReference], count: Int) {
        self.references = references
        self.count = count
    }
}

public struct SymbolReference: Codable, Identifiable {
    public let id: String
    public let filePath: String
    public let location: SourceRange
    public let context: String
    
    public init(id: String, filePath: String, location: SourceRange, context: String) {
        self.id = id
        self.filePath = filePath
        self.location = location
        self.context = context
    }
}

public struct SymbolsResponse: Codable {
    public let symbols: [Symbol]
    
    public init(symbols: [Symbol]) {
        self.symbols = symbols
    }
}

public struct Symbol: Codable, Identifiable {
    public let id: String
    public let name: String
    public let kind: String
    public let location: SourceRange
    
    public init(id: String, name: String, kind: String, location: SourceRange) {
        self.id = id
        self.name = name
        self.kind = kind
        self.location = location
    }
}

public enum ASTServicesError: Error, LocalizedError {
    case executionFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "AST Services execution failed: \(message)"
        }
    }
}
