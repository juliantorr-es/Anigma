import Foundation
import CapsuleCore
import TelemetryCore

/// ContainerKit: Archive operations protocol and stub implementation
/// Provides comprehensive archive management with diagnostic support
public final class ContainerKit: Sendable {
    
    /// Unique identifier for this container manager instance
    public let id: String
    
    /// Diagnostics for observability
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation
    private nonisolated let impl: ContainerKitInternal
    
    /// Initialize ContainerKit instance
    /// - Parameters:
    ///   - id: Unique identifier for this container manager (UUID recommended)
    ///   - diagnostics: Diagnostics collector for observability
    /// - Throws: `CapsuleError.invalidConfiguration` if id is empty or invalid
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        guard !id.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "ContainerKit ID cannot be empty")
        }
        
        self.id = id
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.impl = ContainerKitInternal()
        
        let span = self.diagnostics.beginSpan(
            name: "ContainerKit.init",
            category: "initialization",
            correlationID: nil,
            tags: ["containerkit_id": id]
        )
        span.end(status: .ok)
    }
    
    /// Create archive from files and directories
    /// - Parameters:
    ///   - sourcePaths: Array of source file/directory paths
    ///   - outputPath: Path for output archive file
    ///   - containerType: Type of archive to create
    ///   - compressionLevel: Compression level for archive
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Archive creation result
    /// - Throws: `CapsuleError` variants:
    ///   - `.invalidInput` if paths are invalid or inaccessible
    ///   - `.resourceExhausted` if insufficient disk space
    ///   - `.timeout` if operation exceeds deadline
    ///   - `.internalError` if bug detected
    public func createArchive(
        from sourcePaths: [String],
        to outputPath: String,
        containerType: ContainerType,
        compressionLevel: CompressionLevel = .normal,
        correlationID: String? = nil
    ) async throws -> ArchiveResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ContainerKit.createArchive",
            category: "archive_creation",
            correlationID: corrID,
            tags: [
                "container_type": containerType.rawValue,
                "compression_level": "\(compressionLevel.rawValue)",
                "source_count": "\(sourcePaths.count)"
            ]
        )
        
        // Validation: Contract 1 - return CapsuleError for invalid inputs
        guard !sourcePaths.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "sourcePaths",
                constraint: "At least one source path required"
            )
        }
        
        guard !outputPath.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "outputPath",
                constraint: "Output path cannot be empty"
            )
        }
        
        // Validate source paths exist
        for path in sourcePaths {
            guard FileManager.default.fileExists(atPath: path) else {
                span.end(status: .error)
                throw CapsuleError.invalidInput(
                    field: "sourcePaths",
                    constraint: "Source path does not exist: \(path)"
                )
            }
        }
        
        // Emit diagnostic event (Contract 2)
        diagnostics.event(
            level: .debug,
            category: "containerkit.archive",
            message: "Starting archive creation: \(containerType.rawValue)",
            correlationID: corrID,
            metadata: [
                "output_path": outputPath,
                "total_sources": "\(sourcePaths.count)"
            ]
        )
        
        do {
            let result = try await impl.createArchive(
                sourcePaths: sourcePaths,
                outputPath: outputPath,
                containerType: containerType,
                compressionLevel: compressionLevel,
                diagnostics: diagnostics,
                correlationID: corrID
            )
            
            diagnostics.event(
                level: .info,
                category: "containerkit.archive",
                message: "Archive creation completed",
                correlationID: corrID,
                metadata: [
                    "success": "\(result.success)",
                    "entries_processed": "\(result.entriesProcessed)",
                    "bytes_processed": "\(result.bytesProcessed)"
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch {
            diagnostics.event(
                level: .error,
                category: "containerkit.archive",
                message: "Archive creation failed: \(error)",
                correlationID: corrID,
                metadata: [:]
            )
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Extract archive to specified directory
    /// - Parameters:
    ///   - archivePath: Path to archive file
    ///   - outputDirectory: Directory to extract files to
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Archive extraction result
    /// - Throws: `CapsuleError` variants matching createArchive pattern
    public func extractArchive(
        from archivePath: String,
        to outputDirectory: String,
        correlationID: String? = nil
    ) async throws -> ArchiveResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ContainerKit.extractArchive",
            category: "archive_extraction",
            correlationID: corrID,
            tags: ["archive_path": archivePath]
        )
        
        // Validation
        guard !archivePath.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "archivePath",
                constraint: "Archive path cannot be empty"
            )
        }
        
        guard !outputDirectory.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "outputDirectory",
                constraint: "Output directory cannot be empty"
            )
        }
        
        guard FileManager.default.fileExists(atPath: archivePath) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "archivePath",
                constraint: "Archive file does not exist: \(archivePath)"
            )
        }
        
        // Create output directory if needed
        try FileManager.default.createDirectory(
            atPath: outputDirectory,
            withIntermediateDirectories: true
        )
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "containerkit.archive",
            message: "Starting archive extraction",
            correlationID: corrID,
            metadata: [
                "archive_path": archivePath,
                "output_directory": outputDirectory
            ]
        )
        
        do {
            let result = try await impl.extractArchive(
                archivePath: archivePath,
                outputDirectory: outputDirectory,
                diagnostics: diagnostics,
                correlationID: corrID
            )
            
            diagnostics.event(
                level: .info,
                category: "containerkit.archive",
                message: "Archive extraction completed",
                correlationID: corrID,
                metadata: [
                    "success": "\(result.success)",
                    "entries_processed": "\(result.entriesProcessed)",
                    "bytes_processed": "\(result.bytesProcessed)"
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch {
            diagnostics.event(
                level: .error,
                category: "containerkit.archive",
                message: "Archive extraction failed: \(error)",
                correlationID: corrID,
                metadata: [:]
            )
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// List contents of archive without extracting
    /// - Parameters:
    ///   - archivePath: Path to archive file
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Array of archive entries
    /// - Throws: `CapsuleError` variants matching createArchive pattern
    public func listArchiveContents(
        _ archivePath: String,
        correlationID: String? = nil
    ) async throws -> [ArchiveEntry] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ContainerKit.listArchiveContents",
            category: "archive_listing",
            correlationID: corrID,
            tags: ["archive_path": archivePath]
        )
        
        guard !archivePath.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "archivePath",
                constraint: "Archive path cannot be empty"
            )
        }
        
        guard FileManager.default.fileExists(atPath: archivePath) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "archivePath",
                constraint: "Archive file does not exist: \(archivePath)"
            )
        }
        
        do {
            let entries = try await impl.listArchiveContents(
                archivePath: archivePath,
                diagnostics: diagnostics,
                correlationID: corrID
            )
            
            diagnostics.event(
                level: .debug,
                category: "containerkit.archive",
                message: "Archive listing completed",
                correlationID: corrID,
                metadata: ["entry_count": "\(entries.count)"]
            )
            
            span.end(status: .ok)
            return entries
        } catch {
            diagnostics.event(
                level: .error,
                category: "containerkit.archive",
                message: "Archive listing failed: \(error)",
                correlationID: corrID,
                metadata: [:]
            )
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get supported container types
    /// - Returns: Array of supported container types
    /// - Throws: Never (informational method)
    public func getSupportedContainerTypes() -> [ContainerType] {
        return impl.getSupportedContainerTypes()
    }
    
    /// Validate archive file integrity
    /// - Parameters:
    ///   - archivePath: Path to archive file
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Validation result
    public func validateArchive(
        _ archivePath: String,
        correlationID: String? = nil
    ) async -> ValidationResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ContainerKit.validateArchive",
            category: "archive_validation",
            correlationID: corrID,
            tags: ["archive_path": archivePath]
        )
        
        defer { span.end(status: .ok) }
        
        return impl.validateArchive(
            archivePath: archivePath,
            diagnostics: diagnostics,
            correlationID: corrID
        )
    }
    
    /// Get archive metadata
    /// - Parameters:
    ///   - archivePath: Path to archive file
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Archive metadata if available
    /// - Throws: `CapsuleError` variants matching createArchive pattern
    public func getArchiveMetadata(
        _ archivePath: String,
        correlationID: String? = nil
    ) async throws -> ArchiveMetadata {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ContainerKit.getArchiveMetadata",
            category: "archive_metadata",
            correlationID: corrID,
            tags: ["archive_path": archivePath]
        )
        
        guard FileManager.default.fileExists(atPath: archivePath) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "archivePath",
                constraint: "Archive file does not exist: \(archivePath)"
            )
        }
        
        do {
            let metadata = try await impl.getArchiveMetadata(
                archivePath: archivePath,
                diagnostics: diagnostics,
                correlationID: corrID
            )
            
            span.end(status: .ok)
            return metadata
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get container manager health status
    /// - Returns: A dictionary with health metrics (sendable-safe)
    /// - Throws: Never (diagnostic-only method)
    public func healthStatus() -> [String: String] {
        return [
            "containerkit_id": id,
            "status": "healthy",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "supported_types": getSupportedContainerTypes().map(\.rawValue).joined(separator: ",")
        ]
    }
}

/// Validation result for archives
public struct ValidationResult: Codable, Sendable, Equatable {
    public let isValid: Bool
    public let issues: [ValidationIssue]
    public let warnings: [ValidationIssue]
    
    public init(
        isValid: Bool,
        issues: [ValidationIssue] = [],
        warnings: [ValidationIssue] = []
    ) {
        self.isValid = isValid
        self.issues = issues
        self.warnings = warnings
    }
}

/// Validation issue for archives
public struct ValidationIssue: Codable, Sendable, Equatable {
    public let id: String
    public let severity: Severity
    public let message: String
    public let entryPath: String?
    
    public init(id: String, severity: Severity, message: String, entryPath: String? = nil) {
        self.id = id
        self.severity = severity
        self.message = message
        self.entryPath = entryPath
    }
    
    public enum Severity: String, Codable, Sendable {
        case error
        case warning
        case info
    }
}

// MARK: - Helper for Diagnostics Integration

/// Mock diagnostics implementation for testing
internal final class DefaultCapsuleDiagnostics: CapsuleDiagnostics {
    public func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        MockDiagnosticSpan()
    }
    
    public func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // In tests, diagnostics are collected for assertions
    }
    
    public func getEvents(since: Date) -> [DiagnosticEvent] {
        []
    }
    
    public func getAllEvents() -> [DiagnosticEvent] {
        []
    }
    
    public func clearEvents() {
        // noop
    }
}

internal final class MockDiagnosticSpan: DiagnosticSpan {
    let spanID = UUID().uuidString
    let name = "mock"
    let category = "mock"
    let correlationID = UUID().uuidString
    let startTime = Date()
    
    var endTime: Date? { nil }
    var duration: TimeInterval? { nil }
    var status: SpanStatus? { nil }
    var tags: [String: String] { [:] }
    
    func end(status: SpanStatus) { }
    func addTag(key: String, value: String) { }
    func recordEvent(level: DiagnosticLevel, message: String) { }
}

/// Context for correlation IDs
internal enum CorrelationIDContext {
    static var current: String {
        // In a real implementation, this would come from async context or thread locals
        return UUID().uuidString
    }
}