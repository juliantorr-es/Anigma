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

@MainActor
@Observable
final class ASTServicesStore {

    // MARK: - Properties

    /// AST Services client for code analysis
    private let astServicesClient: ASTServicesClient

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

    init(astServicesClient: ASTServicesClient) {
        self.astServicesClient = astServicesClient
    }

    // MARK: - Parsing Operations

    /// Parse a file to generate AST
    func parseFile(filePath: String, language: String) async {
        do {
            parseResults = try await astServicesClient.parse(filePath: filePath, language: language)
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
            analysisResults = try await astServicesClient.analyze(filePath: filePath, checks: checks)
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
            let response = try await astServicesClient.refactor(
                filePath: filePath,
                operation: operation
            )
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
            symbolReferences = try await astServicesClient.findReferences(
                symbol: symbol,
                directory: directory
            )
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
            symbols = try await astServicesClient.getSymbols(filePath: filePath)
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
