//
//  ASTServicesStore.swift
//  AnigmaAppMac
//
//  Manages AST analysis, code intelligence, refactoring, and symbol management.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac
import AnigmaPrimitives
import AnigmaSidecar
import AnigmaASTServicesCore

@MainActor
@Observable
final class ASTServicesStore {

    // MARK: - Properties

    /// AST Services client for legacy symbol lookup and fallback behavior
    private let astServicesClient: ASTServicesClient

    /// Daemon store used for daemon-owned AST execution
    private let daemonStore: DaemonStore?

    /// AST analysis results
    var analysisResults: ASTAnalysisResponse?

    /// Symbol references
    var symbolReferences: ReferencesResponse?

    /// Parsed AST
    var parseResults: ASTParseResponse?

    /// Available symbols in file
    var symbols: SymbolsResponse?

    // MARK: - Dependencies (Injected)

    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }

    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }

    // MARK: - Initialization

    init(astServicesClient: ASTServicesClient, daemonStore: DaemonStore? = nil) {
        self.astServicesClient = astServicesClient
        self.daemonStore = daemonStore
    }

    // MARK: - Parsing Operations

    /// Parse a file to generate AST
    func parseFile(filePath: String, language: String) async {
        do {
            if let daemonResult = try await parseFileViaDaemon(filePath: filePath) {
                parseResults = daemonResult
            } else {
                parseResults = try await astServicesClient.parse(filePath: filePath, language: language)
            }

            showToast(
                "Parse Complete",
                "Took \(String(format: "%.3f", parseResults?.parseTime ?? 0))s",
                "doc.text.magnifyingglass"
            )
        } catch {
            showError("Failed to parse file: \(error)")
        }
    }

    // MARK: - Analysis Operations

    /// Analyze code for issues and metrics
    func analyzeCode(filePath: String, checks: [String] = []) async {
        do {
            if let daemonResult = try await analyzeCodeViaDaemon(filePath: filePath, checks: checks) {
                analysisResults = daemonResult
            } else {
                analysisResults = try await astServicesClient.analyze(filePath: filePath, checks: checks)
            }

            showToast(
                "Analysis Complete",
                "\(analysisResults?.issues.count ?? 0) issues found",
                "doc.text.magnifyingglass"
            )
        } catch {
            showError("Code analysis failed: \(error)")
        }
    }

    // MARK: - Refactoring Operations

    /// Refactor code with specified operation
    func refactorCode(filePath: String, operation: RefactorOperation) async {
        do {
            let response: RefactorResponse
            if let daemonResult = try await refactorCodeViaDaemon(filePath: filePath, operation: operation) {
                response = daemonResult
            } else {
                response = try await astServicesClient.refactor(
                    filePath: filePath,
                    operation: operation
                )
            }

            if response.success {
                showToast(
                    "Refactor Complete",
                    "\(response.affectedFiles.count) files modified",
                    "wand.and.stars"
                )
            } else {
                showError("Refactor operation was not successful")
            }
        } catch {
            showError("Refactor failed: \(error)")
        }
    }

    // MARK: - Symbol Operations

    /// Find all references to a symbol
    func findSymbolReferences(symbol: String, directory: String) async {
        do {
            if let daemonResult = try await findSymbolReferencesViaDaemon(symbol: symbol, directory: directory) {
                symbolReferences = daemonResult
            } else {
                symbolReferences = try await astServicesClient.findReferences(
                    symbol: symbol,
                    directory: directory
                )
            }
            showToast(
                "Found References",
                "\(symbolReferences?.count ?? 0) references",
                "magnifyingglass"
            )
        } catch {
            showError("Reference search failed: \(error)")
        }
    }

    /// Get all symbols in a file
    func getSymbols(filePath: String) async {
        do {
            if let daemonResult = try await getSymbolsViaDaemon(filePath: filePath) {
                symbols = daemonResult
            } else {
                symbols = try await astServicesClient.getSymbols(filePath: filePath)
            }
            showToast(
                "Symbols Extracted",
                "\(symbols?.symbols.count ?? 0) symbols found",
                "list.bullet.rectangle"
            )
        } catch {
            showError("Failed to get symbols: \(error)")
        }
    }
}

// MARK: - Daemon-backed AST Execution

private extension ASTServicesStore {
    func parseFileViaDaemon(filePath: String) async throws -> ASTParseResponse? {
        guard let bridge = daemonStore?.daemonBridge else { return nil }

        let start = Date()
        let result = try await executeDaemonASTJob(
            kind: "ast.analyze",
            config: makeAnalysisConfig(operation: .parse, visitors: []),
            sourceFilePath: filePath,
            bridge: bridge
        )

        guard result.ok else {
            throw ASTServicesError.executionFailed(message: result.error?.message ?? "Daemon parse failed")
        }

        return ASTParseResponse(
            ast: ASTNode(
                type: "sourceFile",
                range: SourceRange(
                    start: SourcePosition(line: 1, column: 1),
                    end: SourcePosition(line: 1, column: 1)
                ),
                children: nil
            ),
            parseTime: Date().timeIntervalSince(start)
        )
    }

    func analyzeCodeViaDaemon(filePath: String, checks: [String]) async throws -> ASTAnalysisResponse? {
        guard let bridge = daemonStore?.daemonBridge else { return nil }

        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        let result = try await executeDaemonASTJob(
            kind: "ast.analyze",
            config: makeAnalysisConfig(operation: .analyze, visitors: checks),
            sourceFilePath: filePath,
            bridge: bridge
        )

        guard result.ok else {
            throw ASTServicesError.executionFailed(message: result.error?.message ?? "Daemon analysis failed")
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

    func refactorCodeViaDaemon(filePath: String, operation: RefactorOperation) async throws -> RefactorResponse? {
        guard let bridge = daemonStore?.daemonBridge else { return nil }

        let sourceData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let artifact = try await bridge.ingestArtifact(
            data: sourceData,
            kind: "source",
            mediaType: "text/x-swift",
            filenameHint: URL(fileURLWithPath: filePath).lastPathComponent
        ).artifact

        let config = DaemonASTTransformConfig(
            files: [filePath],
            ruleNames: [operation.params["rule"] ?? operation.type],
            dryRun: operation.params["dryRun"].map { $0 != "false" } ?? false
        )
        let configData = try JSONEncoder().encode(config)

        let spec = AnigmaJobSpec(
            kind: "ast.transform",
            configCanonical: configData,
            inputs: [artifact]
        )

        let submitted = try await bridge.submitJob(spec)
        guard let jobId = submitted.jobId else {
            throw ASTServicesError.executionFailed(message: submitted.error?.message ?? "AST transform submission failed")
        }

        let status = try await waitForDaemonJobCompletion(jobId: jobId, bridge: bridge)
        guard let output = status.outputs.first else {
            throw ASTServicesError.executionFailed(message: "AST transform completed without outputs")
        }

        let data = try await bridge.retrieveArtifact(hash: output.hash).data
        let payload = try JSONDecoder().decode(DaemonASTTransformResult.self, from: data)

        let summary = payload.changes.isEmpty
            ? (payload.errors.isEmpty ? "No refactor changes were required." : payload.errors.joined(separator: "\n"))
            : payload.changes.joined(separator: "\n")

        return RefactorResponse(
            success: payload.errors.isEmpty,
            diff: summary,
            affectedFiles: [filePath]
        )
    }

    func findSymbolReferencesViaDaemon(symbol: String, directory: String) async throws -> ReferencesResponse? {
        guard let bridge = daemonStore?.daemonBridge else { return nil }

        let config = DaemonCodeSearchConfig(
            pattern: symbol,
            directory: directory,
            fileExtensions: ["swift"],
            ignorePatterns: [],
            caseSensitive: true,
            contextLines: 2
        )
        let configData = try JSONEncoder().encode(config)
        let spec = AnigmaJobSpec(kind: "code.search", configCanonical: configData, inputs: [])

        let submitted = try await bridge.submitJob(spec)
        guard let jobId = submitted.jobId else {
            throw ASTServicesError.executionFailed(message: submitted.error?.message ?? "Code search submission failed")
        }

        let status = try await waitForDaemonJobCompletion(jobId: jobId, bridge: bridge)
        guard let output = status.outputs.first else {
            throw ASTServicesError.executionFailed(message: "Code search completed without outputs")
        }

        let data = try await bridge.retrieveArtifact(hash: output.hash).data
        let results = try JSONDecoder().decode([DaemonSearchResult].self, from: data)

        let references = results.enumerated().map { index, result in
            SymbolReference(
                id: "\(result.filePath):\(result.lineNumber):\(result.column):\(index)",
                filePath: result.filePath,
                location: SourceRange(
                    start: SourcePosition(line: result.lineNumber, column: result.column),
                    end: SourcePosition(line: result.lineNumber, column: result.column + max(symbol.count, result.matchedText.count))
                ),
                context: result.context
            )
        }

        return ReferencesResponse(references: references, count: references.count)
    }

    func getSymbolsViaDaemon(filePath: String) async throws -> SymbolsResponse? {
        guard let bridge = daemonStore?.daemonBridge else { return nil }

        let sourceData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let artifact = try await bridge.ingestArtifact(
            data: sourceData,
            kind: "source",
            mediaType: "text/x-swift",
            filenameHint: URL(fileURLWithPath: filePath).lastPathComponent
        ).artifact

        let configData = try JSONEncoder().encode(DaemonCtagsConfig(format: "u-ctags", recursive: false))
        let spec = AnigmaJobSpec(
            kind: "code.index",
            configCanonical: configData,
            inputs: [artifact]
        )

        let submitted = try await bridge.submitJob(spec)
        guard let jobId = submitted.jobId else {
            throw ASTServicesError.executionFailed(message: submitted.error?.message ?? "Code indexing submission failed")
        }

        let status = try await waitForDaemonJobCompletion(jobId: jobId, bridge: bridge)
        guard let output = status.outputs.first else {
            throw ASTServicesError.executionFailed(message: "Code indexing completed without outputs")
        }

        let data = try await bridge.retrieveArtifact(hash: output.hash).data
        let tagsText = String(data: data, encoding: .utf8) ?? ""
        return SymbolsResponse(symbols: parseCTagsSymbols(tagsText, filePath: filePath))
    }

    func parseCTagsSymbols(_ tagsText: String, filePath: String) -> [Symbol] {
        tagsText
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { index, line in
                guard !line.isEmpty, !line.hasPrefix("!") else { return nil }
                let fields = line.components(separatedBy: "\t")
                guard let name = fields.first, !name.isEmpty else { return nil }
                let kind = fields.first(where: { $0.hasPrefix("kind:") })?.replacingOccurrences(of: "kind:", with: "") ?? "symbol"
                let symbolFile = fields.dropFirst().first ?? filePath
                return Symbol(
                    id: "\(symbolFile):\(index):\(name)",
                    name: name,
                    kind: kind,
                    location: SourceRange(
                        start: SourcePosition(line: 1, column: 1),
                        end: SourcePosition(line: 1, column: max(name.count, 1) + 1)
                    )
                )
            }
    }

    func executeDaemonASTJob(
        kind: String,
        config: Data,
        sourceFilePath: String,
        bridge: SidecarBridge
    ) async throws -> ASTResult {
        let sourceData = try Data(contentsOf: URL(fileURLWithPath: sourceFilePath))
        let artifact = try await bridge.ingestArtifact(
            data: sourceData,
            kind: "source",
            mediaType: "text/x-swift",
            filenameHint: URL(fileURLWithPath: sourceFilePath).lastPathComponent
        ).artifact

        let spec = AnigmaJobSpec(
            kind: kind,
            configCanonical: config,
            inputs: [artifact]
        )

        let submitted = try await bridge.submitJob(spec)
        guard let jobId = submitted.jobId else {
            throw ASTServicesError.executionFailed(message: submitted.error?.message ?? "AST job submission failed")
        }

        let status = try await waitForDaemonJobCompletion(jobId: jobId, bridge: bridge)
        guard let output = status.outputs.first else {
            throw ASTServicesError.executionFailed(message: "AST job completed without outputs")
        }

        let data = try await bridge.retrieveArtifact(hash: output.hash).data
        return try JSONDecoder().decode(ASTResult.self, from: data)
    }

    func waitForDaemonJobCompletion(jobId: String, bridge: SidecarBridge) async throws -> AnigmaGetJobStatusResponse {
        let deadline = Date().addingTimeInterval(60)

        while Date() < deadline {
            let status = try await bridge.getJobStatus(jobId: jobId)
            switch status.state.lowercased() {
            case "completed":
                return status
            case "failed", "cancelled":
                throw ASTServicesError.executionFailed(message: status.error?.message ?? "Daemon AST job \(status.state)")
            default:
                try await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        throw ASTServicesError.executionFailed(message: "Timed out waiting for daemon AST job \(jobId)")
    }

    func makeAnalysisConfig(operation: DaemonASTOperation, visitors: [String]) throws -> Data {
        let config = DaemonASTAnalysisConfig(
            operation: operation.rawValue,
            visitors: visitors,
            maxFileSize: 10 * 1024 * 1024,
            cacheEnabled: true,
            cacheSizeLimit: 100 * 1024 * 1024,
            timeoutSeconds: 60
        )
        return try JSONEncoder().encode(config)
    }

    func makeMetrics(source: String, findings: [ASTFinding]) -> CodeMetrics {
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
}

private enum DaemonASTOperation: String, Codable {
    case parse
    case analyze
}

private struct DaemonASTAnalysisConfig: Codable {
    let operation: String
    let visitors: [String]
    let maxFileSize: Int
    let cacheEnabled: Bool
    let cacheSizeLimit: Int
    let timeoutSeconds: Int
}

private struct DaemonASTTransformConfig: Codable {
    let files: [String]
    let ruleNames: [String]
    let dryRun: Bool
}

private struct DaemonASTTransformResult: Codable {
    let filesProcessed: Int
    let filesModified: Int
    let totalChanges: Int
    let errors: [String]
    let changes: [String]
    let outcomes: [String]
    let duration: TimeInterval
    let verification: VerificationPayload?

    struct VerificationPayload: Codable {
        let success: Bool
        let detail: String
    }
}

private struct DaemonCodeSearchConfig: Codable {
    let pattern: String
    let directory: String
    let fileExtensions: [String]
    let ignorePatterns: [String]
    let caseSensitive: Bool
    let contextLines: Int
}

private struct DaemonSearchResult: Codable {
    let filePath: String
    let lineNumber: Int
    let column: Int
    let matchedText: String
    let context: String
}

private struct DaemonCtagsConfig: Codable {
    let format: String
    let recursive: Bool
}
