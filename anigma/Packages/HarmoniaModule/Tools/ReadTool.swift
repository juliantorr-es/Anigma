//
//  ReadTool.swift
//  HarmoniaModule
//
//  Read tool with hash verification and content tracking.
//  Provides reliable file reading with integrity checks.
//

import Foundation
import CryptoKit

/// Read tool request with hash verification.
public struct ReadToolRequest: Sendable, Codable {
    public let filePath: String
    public let includeHash: Bool
    public let includeMetadata: Bool

    public init(filePath: String, includeHash: Bool = true, includeMetadata: Bool = true) {
        self.filePath = filePath
        self.includeHash = includeHash
        self.includeMetadata = includeMetadata
    }
}

/// Read tool response with full content metadata.
public struct ReadToolResponse: Sendable, Codable {
    public let content: String
    public let hash: String
    public let size: Int
    public let lastModified: Int64
    public let permissions: FilePermissions?
    public let exists: Bool

    public init(
        content: String,
        hash: String,
        size: Int,
        lastModified: Int64,
        permissions: FilePermissions? = nil,
        exists: Bool = true
    ) {
        self.content = content
        self.hash = hash
        self.size = size
        self.lastModified = lastModified
        self.permissions = permissions
        self.exists = exists
    }
}

/// File permissions for read operations.
public struct FilePermissions: Sendable, Codable {
    public let readable: Bool
    public let writable: Bool
    public let executable: Bool

    public init(readable: Bool, writable: Bool, executable: Bool) {
        self.readable = readable
        self.writable = writable
        self.executable = executable
    }
}

/// Read tool implementation with integrity checks.
public actor ReadTool {

    /// Read file with hash verification and metadata.
    public func readFile(_ request: ReadToolRequest) async throws -> ReadToolResponse {
        // Check file existence
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: request.filePath) else {
            throw ReadError.fileNotFound(request.filePath)
        }

        // Read file content
        let content: String
        do {
            content = try String(contentsOfFile: request.filePath, encoding: .utf8)
        } catch {
            throw ReadError.readError("Failed to read file: \(error.localizedDescription)")
        }

        // Compute hash if requested
        let hash = request.includeHash ? sha256Hex(content) : ""

        // Get file metadata if requested
        var lastModified: Int64 = 0
        var permissions: FilePermissions?

        if request.includeMetadata {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: request.filePath)

                // Modification time
                if let modDate = attributes[.modificationDate] as? Date {
                    lastModified = Int64(modDate.timeIntervalSince1970)
                }

                // Permissions
                if let filePermissions = attributes[.posixPermissions] as? NSNumber {
                    let perms = filePermissions.int16Value
                    permissions = FilePermissions(
                        readable: (perms & Int16(S_IRUSR)) != 0,
                        writable: (perms & Int16(S_IWUSR)) != 0,
                        executable: (perms & Int16(S_IXUSR)) != 0
                    )
                }
            } catch {
                // Metadata is optional, continue without it
                print("⚠️  Failed to read file metadata: \(error.localizedDescription)")
            }
        }

        return ReadToolResponse(
            content: content,
            hash: hash,
            size: content.count,
            lastModified: lastModified,
            permissions: permissions,
            exists: true
        )
    }

    /// Compute SHA256 hash of content.
    private func sha256Hex(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = CryptoKit.SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supporting Types

/// Read-specific errors.
public enum ReadError: Error, LocalizedError {
    case fileNotFound(String)
    case readError(String)
    case permissionDenied(String)
    case invalidPath(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .readError(let message):
            return "Read error: \(message)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}

// MARK: - POSIX Permission Constants

#if os(Linux)
import Glibc
#endif

let S_IRUSR: UInt16 = 0o400  // Read permission, owner
let S_IWUSR: UInt16 = 0o200  // Write permission, owner
let S_IXUSR: UInt16 = 0o100  // Execute permission, owner
