//
//  DoctrineClient.swift
//  AnigmaHostMac
//
//  CLI client for Doctrine operations.
//

import Foundation

/// Client for executing Doctrine CLI commands.
public struct DoctrineClient: Sendable {
    private let binaryPath: String

    public init(binaryPath: String = "/usr/local/bin/doctrine") {
        self.binaryPath = binaryPath
    }

    // MARK: - Error Types

    public enum DoctrineError: Error, LocalizedError {
        case binaryNotFound(String)
        case executionFailed(Int32, String)
        case outputParsing(Error)
        case timeout(TimeInterval)

        public var errorDescription: String? {
            switch self {
            case .binaryNotFound(let path):
                return "Doctrine binary not found at: \(path)"
            case .executionFailed(let code, let message):
                return "Doctrine execution failed (exit \(code)): \(message)"
            case .outputParsing(let error):
                return "Failed to parse Doctrine output: \(error.localizedDescription)"
            case .timeout(let duration):
                return "Doctrine command timed out after \(duration) seconds"
            }
        }
    }

    // MARK: - Command Execution

    /// Execute a Doctrine command and parse JSON response.
    private func execute<T: Decodable>(
        _ arguments: [String],
        timeout: TimeInterval = 30.0
    ) async throws -> T {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw DoctrineError.binaryNotFound(binaryPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments + ["--json"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Wait with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.isRunning {
            process.terminate()
            throw DoctrineError.timeout(timeout)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw DoctrineError.executionFailed(process.terminationStatus, errorMessage)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: outputData)
        } catch {
            throw DoctrineError.outputParsing(error)
        }
    }

    // MARK: - Scan Operations

    /// Scan a path for doctrine violations.
    public func scan(path: String, domains: [String]? = nil) async throws -> ScanResponse {
        var args = ["scan", path]
        if let domains = domains {
            args.append(contentsOf: ["--domains", domains.joined(separator: ",")])
        }
        return try await execute(args)
    }

    /// Scan a path and return only specific severity violations.
    public func scan(path: String, severity: String) async throws -> ScanResponse {
        let args = ["scan", path, "--severity", severity]
        return try await execute(args)
    }

    // MARK: - Rule Operations

    /// List all available rules.
    public func listRules(domain: String? = nil) async throws -> RulesResponse {
        var args = ["rules", "list"]
        if let domain = domain {
            args.append(contentsOf: ["--domain", domain])
        }
        return try await execute(args)
    }

    /// Get details for a specific rule.
    public func getRule(id: String) async throws -> RuleDetailResponse {
        let args = ["rules", "show", id]
        return try await execute(args)
    }

    // MARK: - Violation Operations

    /// List violations from the ledger.
    public func listViolations(
        severity: String? = nil,
        domain: String? = nil,
        resolved: Bool? = nil,
        limit: Int = 100
    ) async throws -> ViolationsResponse {
        var args = ["violations", "list", "--limit", "\(limit)"]

        if let severity = severity {
            args.append(contentsOf: ["--severity", severity])
        }
        if let domain = domain {
            args.append(contentsOf: ["--domain", domain])
        }
        if let resolved = resolved {
            args.append(contentsOf: ["--resolved", resolved ? "true" : "false"])
        }

        return try await execute(args)
    }

    /// Mark a violation as resolved.
    public func resolveViolation(id: String, note: String? = nil) async throws -> EmptyResponse {
        var args = ["violations", "resolve", id]
        if let note = note {
            args.append(contentsOf: ["--note", note])
        }
        return try await execute(args)
    }

    /// Get statistics about violations.
    public func violationStats() async throws -> ViolationStatsResponse {
        let args = ["violations", "stats"]
        return try await execute(args)
    }

    // MARK: - Pack Operations

    /// List all available doctrine packs.
    public func listPacks() async throws -> PacksResponse {
        let args = ["packs", "list"]
        return try await execute(args)
    }

    /// Get details for a specific pack.
    public func getPack(id: String) async throws -> PackDetailResponse {
        let args = ["packs", "show", id]
        return try await execute(args)
    }

    /// Enable a doctrine pack.
    public func enablePack(id: String) async throws -> EmptyResponse {
        let args = ["packs", "enable", id]
        return try await execute(args)
    }

    /// Disable a doctrine pack.
    public func disablePack(id: String) async throws -> EmptyResponse {
        let args = ["packs", "disable", id]
        return try await execute(args)
    }

    // MARK: - Response Types

    public struct ScanResponse: Codable, Sendable {
        public let scannedPath: String
        public let totalViolations: Int
        public let criticalCount: Int
        public let errorCount: Int
        public let warningCount: Int
        public let infoCount: Int
        public let violations: [Violation]
        public let scanDuration: TimeInterval
        public let timestamp: Date

        public struct Violation: Codable, Sendable, Identifiable {
            public let id: String
            public let ruleId: String
            public let domain: String
            public let severity: String
            public let message: String
            public let filePath: String?
            public let lineNumber: Int?
            public let columnNumber: Int?
            public let context: String?
            public let metadata: [String: String]
        }
    }

    public struct RulesResponse: Codable, Sendable {
        public let rules: [Rule]
        public let totalCount: Int
        public let domains: [String]

        public struct Rule: Codable, Sendable, Identifiable {
            public let id: String
            public let domain: String
            public let title: String
            public let description: String
            public let severity: String
            public let enabled: Bool
        }
    }

    public struct RuleDetailResponse: Codable, Sendable {
        public let id: String
        public let domain: String
        public let title: String
        public let description: String
        public let canonicalSource: String
        public let severity: String
        public let checkType: String
        public let parameters: [String: String]
        public let enabled: Bool
        public let examples: [Example]

        public struct Example: Codable, Sendable {
            public let description: String
            public let code: String
            public let isViolation: Bool
        }
    }

    public struct ViolationsResponse: Codable, Sendable {
        public let violations: [ViolationRecord]
        public let totalCount: Int
        public let filteredCount: Int

        public struct ViolationRecord: Codable, Sendable, Identifiable {
            public let id: String
            public let ruleId: String
            public let domain: String
            public let severity: String
            public let message: String
            public let filePath: String?
            public let lineNumber: Int?
            public let detectedAt: Date
            public let resolved: Bool
            public let resolvedAt: Date?
            public let resolvedBy: String?
            public let resolvedNote: String?
        }
    }

    public struct ViolationStatsResponse: Codable, Sendable {
        public let totalViolations: Int
        public let unresolvedViolations: Int
        public let byDomain: [String: Int]
        public let bySeverity: [String: Int]
        public let topRules: [RuleStats]

        public struct RuleStats: Codable, Sendable {
            public let ruleId: String
            public let count: Int
        }
    }

    public struct PacksResponse: Codable, Sendable {
        public let packs: [Pack]
        public let totalCount: Int

        public struct Pack: Codable, Sendable, Identifiable {
            public let id: String
            public let name: String
            public let domain: String
            public let version: String
            public let enabled: Bool
            public let ruleCount: Int
        }
    }

    public struct PackDetailResponse: Codable, Sendable {
        public let id: String
        public let name: String
        public let domain: String
        public let version: String
        public let description: String
        public let canonicalSource: String
        public let enabled: Bool
        public let rules: [String]
        public let principles: [String]
    }

    public struct EmptyResponse: Codable, Sendable {
        public let success: Bool
        public let message: String?
    }
}
