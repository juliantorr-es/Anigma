import Foundation
import CapsuleCore
import TelemetryCore
import AnigmaPrimitives

/// Container types supported by ContainerKit
public enum ContainerType: String, Codable, Sendable {
    case zip
    case tar
    case gzip
    case sevenZ
    case rar
    case iso
    case dmg
}

/// Compression levels for archive creation
public enum CompressionLevel: Int, Codable, Sendable {
    case none = 0
    case fastest = 1
    case fast = 3
    case normal = 6
    case maximum = 9
    case best = 12
}

/// Archive entry representing a file or directory in an archive
public struct ArchiveEntry: Codable, Sendable, Equatable {
    public let path: String
    public let size: Int64
    public let isDirectory: Bool
    public let lastModified: Date
    public let permissions: FilePermissions
    public let checksum: String?
    public let metadata: [String: AnyCodable]
    
    public init(
        path: String,
        size: Int64,
        isDirectory: Bool,
        lastModified: Date,
        permissions: FilePermissions = FilePermissions.default,
        checksum: String? = nil,
        metadata: [String: AnyCodable] = [:]
    ) {
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.lastModified = lastModified
        self.permissions = permissions
        self.checksum = checksum
        self.metadata = metadata
    }
}

/// File permissions for archive entries
public struct FilePermissions: Codable, Sendable, Equatable {
    public let ownerRead: Bool
    public let ownerWrite: Bool
    public let ownerExecute: Bool
    public let groupRead: Bool
    public let groupWrite: Bool
    public let groupExecute: Bool
    public let otherRead: Bool
    public let otherWrite: Bool
    public let otherExecute: Bool
    
    public static let `default` = FilePermissions(
        ownerRead: true,
        ownerWrite: true,
        ownerExecute: false,
        groupRead: true,
        groupWrite: false,
        groupExecute: false,
        otherRead: true,
        otherWrite: false,
        otherExecute: false
    )
    
    public static let executable = FilePermissions(
        ownerRead: true,
        ownerWrite: true,
        ownerExecute: true,
        groupRead: true,
        groupWrite: false,
        groupExecute: true,
        otherRead: true,
        otherWrite: false,
        otherExecute: true
    )
    
    public init(
        ownerRead: Bool,
        ownerWrite: Bool,
        ownerExecute: Bool,
        groupRead: Bool,
        groupWrite: Bool,
        groupExecute: Bool,
        otherRead: Bool,
        otherWrite: Bool,
        otherExecute: Bool
    ) {
        self.ownerRead = ownerRead
        self.ownerWrite = ownerWrite
        self.ownerExecute = ownerExecute
        self.groupRead = groupRead
        self.groupWrite = groupWrite
        self.groupExecute = groupExecute
        self.otherRead = otherRead
        self.otherWrite = otherWrite
        self.otherExecute = otherExecute
    }
    
    /// Convert to octal representation (e.g., 755)
    public var octal: Int {
        var result = 0
        
        if ownerRead { result |= 0o400 }
        if ownerWrite { result |= 0o200 }
        if ownerExecute { result |= 0o100 }
        
        if groupRead { result |= 0o040 }
        if groupWrite { result |= 0o020 }
        if groupExecute { result |= 0o010 }
        
        if otherRead { result |= 0o004 }
        if otherWrite { result |= 0o002 }
        if otherExecute { result |= 0o001 }
        
        return result
    }
}

/// Archive metadata
public struct ArchiveMetadata: Codable, Sendable, Equatable {
    public let createdDate: Date
    public let modifiedDate: Date
    public let creator: String
    public let comment: String?
    public let totalEntries: Int
    public let totalSize: Int64
    public let compressionRatio: Double?
    public let properties: [String: AnyCodable]
    
    public init(
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        creator: String = "ContainerKit",
        comment: String? = nil,
        totalEntries: Int = 0,
        totalSize: Int64 = 0,
        compressionRatio: Double? = nil,
        properties: [String: AnyCodable] = [:]
    ) {
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.creator = creator
        self.comment = comment
        self.totalEntries = totalEntries
        self.totalSize = totalSize
        self.compressionRatio = compressionRatio
        self.properties = properties
    }
}

/// Archive operation result
public struct ArchiveResult: Codable, Sendable, Equatable {
    public let success: Bool
    public let entriesProcessed: Int
    public let bytesProcessed: Int64
    public let errors: [ArchiveError]
    public let warnings: [ArchiveWarning]
    public let metadata: ArchiveMetadata
    
    public init(
        success: Bool,
        entriesProcessed: Int,
        bytesProcessed: Int64,
        errors: [ArchiveError] = [],
        warnings: [ArchiveWarning] = [],
        metadata: ArchiveMetadata = ArchiveMetadata()
    ) {
        self.success = success
        self.entriesProcessed = entriesProcessed
        self.bytesProcessed = bytesProcessed
        self.errors = errors
        self.warnings = warnings
        self.metadata = metadata
    }
}

/// Archive error
public struct ArchiveError: Codable, Sendable, Equatable {
    public let id: String
    public let type: ErrorType
    public let message: String
    public let entryPath: String?
    public let timestamp: Date
    
    public init(id: String, type: ErrorType, message: String, entryPath: String? = nil) {
        self.id = id
        self.type = type
        self.message = message
        self.entryPath = entryPath
        self.timestamp = Date()
    }
    
    public enum ErrorType: String, Codable, Sendable {
        case ioError
        case formatError
        case checksumError
        case permissionError
        case spaceError
        case compressionError
        case encryptionError
        case unknownError
    }
}

/// Archive warning
public struct ArchiveWarning: Codable, Sendable, Equatable {
    public let id: String
    public let type: WarningType
    public let message: String
    public let entryPath: String?
    public let timestamp: Date
    
    public init(id: String, type: WarningType, message: String, entryPath: String? = nil) {
        self.id = id
        self.type = type
        self.message = message
        self.entryPath = entryPath
        self.timestamp = Date()
    }
    
    public enum WarningType: String, Codable, Sendable {
        case largeFile
        case deepDirectory
        case specialFile
        case timestampIssue
        case permissionIssue
        case encodingIssue
        case compressionWarning
    }
}

/// Archive operation progress
public struct ArchiveProgress: Codable, Sendable, Equatable {
    public let entriesProcessed: Int
    public let totalEntries: Int
    public let bytesProcessed: Int64
    public let totalBytes: Int64
    public let currentEntry: String?
    public let percentage: Double
    
    public init(
        entriesProcessed: Int,
        totalEntries: Int,
        bytesProcessed: Int64,
        totalBytes: Int64,
        currentEntry: String? = nil
    ) {
        self.entriesProcessed = entriesProcessed
        self.totalEntries = totalEntries
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.currentEntry = currentEntry
        self.percentage = totalBytes > 0 ? Double(bytesProcessed) / Double(totalBytes) * 100.0 : 0.0
    }
}

/// Type-erased codable for heterogeneous property dictionaries (canonicalized to AnigmaPrimitives)
public typealias AnyCodable = AnigmaPrimitives.AnyCodable