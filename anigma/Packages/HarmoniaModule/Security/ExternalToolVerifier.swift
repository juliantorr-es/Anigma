//
//  ExternalToolVerifier.swift
//  HarmoniaModule
//
//  Verifies external tool binaries against a trusted list.
//

import Foundation
import CryptoKit
import AnigmaCore

public struct TrustedTool: Codable, Sendable {
    public let path: String
    public let sha256: String
    public let addedAt: Date
    public let addedBy: String
}

public actor ExternalToolVerifier {
    private let repoRoot: URL

    public init(repoRoot: URL) {
        self.repoRoot = repoRoot
    }

    private func trustFile() -> URL {
        repoRoot.appendingPathComponent(".anigma", isDirectory: true)
            .appendingPathComponent("trust", isDirectory: true)
            .appendingPathComponent("external_tools.json", isDirectory: false)
    }

    public func listTrustedTools() throws -> [TrustedTool] {
        let url = trustFile()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode([TrustedTool].self, from: data)
    }

    private func saveTrustedTools(_ tools: [TrustedTool]) throws {
        let url = trustFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(tools)
        try data.write(to: url, options: [.atomic])
    }

    public func verify(path: String) throws -> Bool {
        let tools = try listTrustedTools()
        guard let trusted = tools.first(where: { $0.path == path }) else {
            return false
        }

        let currentHash = try calculateSHA256(path: path)
        return currentHash == trusted.sha256
    }

    public func trust(path: String, user: String = "system") throws -> TrustedTool {
        let hash = try calculateSHA256(path: path)
        var tools = try listTrustedTools()

        // Remove existing entry for path if any
        tools.removeAll { $0.path == path }

        let tool = TrustedTool(path: path, sha256: hash, addedAt: Date(), addedBy: user)
        tools.append(tool)
        try saveTrustedTools(tools)
        return tool
    }

    public func revoke(path: String) throws {
        var tools = try listTrustedTools()
        tools.removeAll { $0.path == path }
        try saveTrustedTools(tools)
    }

    private func calculateSHA256(path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
