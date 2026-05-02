/// VizAggregationCapsule.swift
/// Public API for the VizAggregationCapsule
/// Tier 1: Multi-format media aggregation with conversion and metadata extraction
///
/// This file provides:
/// - Contract 1: CapsuleError for all public failures
/// - Contract 2: CapsuleDiagnostics for observability
/// - Sendable compliance (Swift 6)
/// - Multi-format media aggregation (video, audio, images)
/// - Format conversion between types
/// - Metadata extraction
/// - Performance benchmarks

import Foundation
import CapsuleCore
import TelemetryCore

/// The VizAggregationCapsule public API
/// Multi-format media aggregation with format conversion and metadata extraction
public final class VizAggregationCapsule: Sendable {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Diagnostics for observability (correlation ID tracking, span timing)
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation (separated for clarity)
    private nonisolated let impl: VizAggregationCapsuleInternal
    
    /// Initialize a VizAggregationCapsule instance
    /// - Parameters:
    ///   - id: Unique identifier for this capsule (UUID recommended)
    ///   - diagnostics: Diagnostics collector for observability
    /// - Throws: `CapsuleError.invalidConfiguration` if id is empty or invalid
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        // Validate configuration (Contract 1 gate)
        guard !id.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "Capsule ID cannot be empty")
        }
        
        self.id = id
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.impl = VizAggregationCapsuleInternal()
        
        // Emit initialization event
        let span = self.diagnostics.beginSpan(
            name: "VizAggregationCapsule.init",
            category: "initialization",
            correlationID: nil,
            tags: ["capsule_id": id]
        )
        span.end(status: .ok)
    }
    
    /// Aggregate multiple media files into a single output with optional format conversion
    /// - Parameters:
    ///   - mediaURLs: Array of media file URLs to aggregate
    ///   - outputFormat: Target output format
    ///   - outputPath: Output file path
    ///   - correlationID: Request ID for tracing (optional)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: AggregationResult with metadata and processing stats
    /// - Throws: `CapsuleError` variants:
    ///   - `.invalidInput` if mediaURLs is empty or contains invalid files
    ///   - `.unsupportedOperation` if format conversion is not supported
    ///   - `.resourceExhausted` if files are too large
    ///   - `.timeout` if aggregation exceeds time limits
    ///   - `.internalError` if processing fails
    public func aggregate(
        mediaURLs: [URL],
        outputFormat: MediaFormat,
        outputPath: String,
        correlationID: String? = nil,
        progress: ((Double) -> Void)? = nil
    ) async throws -> AggregationResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VizAggregationCapsule.aggregate",
            category: "media_aggregation",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "input_count": "\(mediaURLs.count)",
                "output_format": outputFormat.rawValue
            ]
        )
        
        // Validation: Contract 1 - return CapsuleError for invalid inputs
        guard !mediaURLs.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "mediaURLs",
                constraint: "Non-empty array required"
            )
        }
        
        guard !outputPath.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "outputPath",
                constraint: "Non-empty path required"
            )
        }
        
        // Validate input files exist
        for url in mediaURLs {
            guard FileManager.default.fileExists(atPath: url.path) else {
                span.end(status: .error)
                throw CapsuleError.invalidInput(
                    field: "mediaURLs",
                    constraint: "File does not exist: \(url.path)"
                )
            }
        }
        
        // Emit diagnostic event (Contract 2)
        diagnostics.event(
            level: .info,
            category: "vizaggregationcapsule.aggregate",
            message: "Starting aggregation of \(mediaURLs.count) files to \(outputFormat.rawValue)",
            correlationID: corrID,
            metadata: [
                "total_files": "\(mediaURLs.count)",
                "output_format": outputFormat.rawValue,
                "tier": "1"
            ]
        )
        
        // Delegate to internal implementation
        do {
            let result = try await impl.aggregate(
                mediaURLs: mediaURLs,
                outputFormat: outputFormat,
                outputPath: outputPath,
                progress: progress
            )
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vizaggregationcapsule.aggregate",
                message: "Aggregation completed successfully",
                correlationID: corrID,
                metadata: [
                    "processing_time": "\(result.processingTime)",
                    "output_file": result.outputURL.path
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch let vizError as VizAggregationError {
            // Map VizAggregation errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vizaggregationcapsule.aggregate",
                message: "Aggregation failed: \(vizError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VizAggregationError"]
            )
            span.end(status: .error)
            
            switch vizError {
            case .invalidInput, .unsupportedFormat:
                throw CapsuleError.invalidInput(field: "media", constraint: vizError.localizedDescription)
            case .conversionFailed, .metadataExtractionFailed:
                throw CapsuleError.internalError(details: vizError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vizaggregationcapsule.aggregate",
                message: "Aggregation failed: \(error)",
                correlationID: corrID,
                metadata: ["error_type": "Unknown"]
            )
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Extract metadata from a media file
    /// - Parameters:
    ///   - url: URL of the media file
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: MediaMetadata structure
    /// - Throws: `CapsuleError` variants:
    ///   - `.invalidInput` if file doesn't exist or is unsupported
    ///   - `.internalError` if metadata extraction fails
    public func extractMetadata(
        from url: URL,
        correlationID: String? = nil
    ) async throws -> MediaMetadata {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VizAggregationCapsule.extractMetadata",
            category: "metadata_extraction",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "file_path": url.path
            ]
        )
        
        // Validation
        guard FileManager.default.fileExists(atPath: url.path) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "url",
                constraint: "File does not exist: \(url.path)"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "vizaggregationcapsule.extractMetadata",
            message: "Extracting metadata from \(url.path)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let metadata = try await impl.extractMetadata(from: url)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vizaggregationcapsule.extractMetadata",
                message: "Metadata extraction completed",
                correlationID: corrID,
                metadata: [
                    "format": metadata.format.rawValue,
                    "file_size": "\(metadata.fileSize)",
                    "duration": metadata.duration.map { "\($0)" } ?? "nil"
                ]
            )
            
            span.end(status: .ok)
            return metadata
        } catch let vizError as VizAggregationError {
            // Map VizAggregation errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vizaggregationcapsule.extractMetadata",
                message: "Metadata extraction failed: \(vizError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VizAggregationError"]
            )
            span.end(status: .error)
            
            switch vizError {
            case .invalidInput, .unsupportedFormat:
                throw CapsuleError.invalidInput(field: "file", constraint: vizError.localizedDescription)
            case .metadataExtractionFailed, .conversionFailed:
                throw CapsuleError.internalError(details: vizError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Convert media from one format to another
    /// - Parameters:
    ///   - inputURL: Source media file URL
    ///   - outputURL: Target output URL
    ///   - outputFormat: Desired output format
    ///   - correlationID: Request ID for tracing (optional)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Throws: `CapsuleError` variants for conversion failures
    public func convertFormat(
        inputURL: URL,
        outputURL: URL,
        outputFormat: MediaFormat,
        correlationID: String? = nil,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VizAggregationCapsule.convertFormat",
            category: "format_conversion",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "input_file": inputURL.path,
                "output_file": outputURL.path,
                "output_format": outputFormat.rawValue
            ]
        )
        
        // Validation
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "inputURL",
                constraint: "File does not exist: \(inputURL.path)"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "vizaggregationcapsule.convertFormat",
            message: "Starting format conversion from \(inputURL.pathExtension) to \(outputFormat.rawValue)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            try await impl.convertFormat(
                inputURL: inputURL,
                outputURL: outputURL,
                outputFormat: outputFormat,
                progress: progress
            )
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vizaggregationcapsule.convertFormat",
                message: "Format conversion completed successfully",
                correlationID: corrID,
                metadata: ["output_file": outputURL.path]
            )
            
            span.end(status: .ok)
        } catch let vizError as VizAggregationError {
            // Map VizAggregation errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vizaggregationcapsule.convertFormat",
                message: "Format conversion failed: \(vizError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VizAggregationError"]
            )
            span.end(status: .error)
            
            switch vizError {
            case .invalidInput, .unsupportedFormat:
                throw CapsuleError.invalidInput(field: "media", constraint: vizError.localizedDescription)
            case .conversionFailed, .metadataExtractionFailed:
                throw CapsuleError.internalError(details: vizError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get capsule health status
    /// - Returns: A dictionary with health metrics (sendable-safe)
    /// - Throws: Never (diagnostic-only method)
    public func healthStatus() -> [String: String] {
        return [
            "capsule_id": id,
            "status": "healthy",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }
}

// MARK: - Helper for Diagnostics Integration

/// Mock diagnostics implementation for testing
/// Can be replaced with actual daemon diagnostics when integrated
internal final class MockDiagnostics: CapsuleDiagnostics {
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
