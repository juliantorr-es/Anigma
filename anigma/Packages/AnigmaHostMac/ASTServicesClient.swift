//
//  ASTServicesClient.swift
//  AnigmaHostMac
//
//  AST analysis and code intelligence client.
//

import Foundation

public struct ASTServicesClient: Sendable {
    private let binaryPath: String

    public init(binaryPath: String = "/usr/local/bin/anigma-ast-services") {
        self.binaryPath = binaryPath
    }

    public func parse(filePath: String, language: String) async throws -> ASTParseResponse {
        let output = try await execute(["parse", "--file", filePath, "--language", language, "--format", "json"])
        return try JSONDecoder().decode(ASTParseResponse.self, from: output)
    }

    public func analyze(filePath: String, checks: [String] = []) async throws -> ASTAnalysisResponse {
        var args = ["analyze", "--file", filePath, "--format", "json"]
        if !checks.isEmpty {
            args.append(contentsOf: ["--checks", checks.joined(separator: ",")])
        }
        let output = try await execute(args)
        return try JSONDecoder().decode(ASTAnalysisResponse.self, from: output)
    }

    public func refactor(filePath: String, operation: RefactorOperation) async throws -> RefactorResponse {
        let opJSON = try JSONEncoder().encode(operation)
        let opString = String(data: opJSON, encoding: .utf8) ?? "{}"
        let output = try await execute(["refactor", "--file", filePath, "--operation", opString, "--format", "json"])
        return try JSONDecoder().decode(RefactorResponse.self, from: output)
    }

    public func findReferences(symbol: String, directory: String) async throws -> ReferencesResponse {
        let output = try await execute(["references", "--symbol", symbol, "--directory", directory, "--format", "json"])
        return try JSONDecoder().decode(ReferencesResponse.self, from: output)
    }

    public func getSymbols(filePath: String) async throws -> SymbolsResponse {
        let output = try await execute(["symbols", "--file", filePath, "--format", "json"])
        return try JSONDecoder().decode(SymbolsResponse.self, from: output)
    }

    private func execute(_ arguments: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ASTServicesError.executionFailed(message: errorMessage)
        }

        return outputData
    }
}

public struct ASTParseResponse: Codable {
    public let ast: ASTNode
    public let parseTime: Double
}

public struct ASTNode: Codable {
    public let type: String
    public let range: SourceRange
    public let children: [ASTNode]?
}

public struct SourceRange: Codable {
    public let start: SourcePosition
    public let end: SourcePosition
}

public struct SourcePosition: Codable {
    public let line: Int
    public let column: Int
}

public struct ASTAnalysisResponse: Codable {
    public let issues: [AnalysisIssue]
    public let metrics: CodeMetrics
}

public struct AnalysisIssue: Codable, Identifiable {
    public let id: String
    public let severity: String
    public let message: String
    public let location: SourceRange
}

public struct CodeMetrics: Codable {
    public let complexity: Int
    public let linesOfCode: Int
    public let maintainability: Double
}

public struct RefactorOperation: Codable {
    public let type: String
    public let params: [String: String]
}

public struct RefactorResponse: Codable {
    public let success: Bool
    public let diff: String
    public let affectedFiles: [String]
}

public struct ReferencesResponse: Codable {
    public let references: [SymbolReference]
    public let count: Int
}

public struct SymbolReference: Codable, Identifiable {
    public let id: String
    public let filePath: String
    public let location: SourceRange
    public let context: String
}

public struct SymbolsResponse: Codable {
    public let symbols: [Symbol]
}

public struct Symbol: Codable, Identifiable {
    public let id: String
    public let name: String
    public let kind: String
    public let location: SourceRange
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
