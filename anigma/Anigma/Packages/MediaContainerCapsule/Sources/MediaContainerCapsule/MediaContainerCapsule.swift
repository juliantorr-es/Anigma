/// MediaContainerCapsule.swift
/// Public API for MediaContainerCapsule
/// Tier 1: Container format support with stream extraction and subtitle handling
///
/// This file provides:
/// - Contract 1: CapsuleError for all public failures
/// - Contract 2: CapsuleDiagnostics for observability
/// - Sendable compliance (Swift 6)
/// - Container format support (MP4, WebM, MKV)
/// - Stream extraction
/// - Subtitle handling

import Foundation
import CapsuleCore
import TelemetryCore

/// The MediaContainerCapsule public API
/// Container format support with stream extraction and subtitle handling
public final class MediaContainerCapsule: Sendable {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Diagnostics for observability (correlation ID tracking, span timing)
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation (separated for clarity)
    private nonisolated let impl: MediaContainerCapsuleInternal
    
    /// Initialize a MediaContainerCapsule instance
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
        self.impl = MediaContainerCapsuleInternal()
        
        // Emit initialization event
        let span = self.diagnostics.beginSpan(
            name: "MediaContainerCapsule.init",
            category: "initialization",
            correlationID: nil,
            tags: ["capsule_id": id]
        )
        span.end(status: .ok)
    }
    
    /// Analyze a media container and extract detailed stream information
    /// - Parameters:
    ///   - containerURL: URL of the container file to analyze
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: ContainerAnalysis with detailed stream information
    /// - Throws: `CapsuleError` variants:
    ///   - `.invalidInput` if file doesn't exist or is unsupported
    ///   - `.internalError` if analysis fails
    public func analyzeContainer(
        from containerURL: URL,
        correlationID: String? = nil
    ) async throws -> ContainerAnalysis {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "MediaContainerCapsule.analyzeContainer",
            category: "container_analysis",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "container_path": containerURL.path
            ]
        )
        
        // Validation
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "containerURL",
                constraint: "File does not exist: \(containerURL.path)"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "mediacontainercapsule.analyzeContainer",
            message: "Analyzing container: \(containerURL.path)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let analysis = try await impl.analyzeContainer(from: containerURL)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "mediacontainercapsule.analyzeContainer",
                message: "Container analysis completed",
                correlationID: corrID,
                metadata: [
                    "format": analysis.format.rawValue,
                    "stream_count": "\(analysis.streams.count)",
                    "duration": "\(analysis.duration)"
                ]
            )
            
            span.end(status: .ok)
            return analysis
        } catch let mediaError as MediaContainerError {
            // Map MediaContainer errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "mediacontainercapsule.analyzeContainer",
                message: "Container analysis failed: \(mediaError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "MediaContainerError"]
            )
            span.end(status: .error)
            
            switch mediaError {
            case .unsupportedFormat:
                throw CapsuleError.invalidInput(field: "format", constraint: mediaError.localizedDescription)
            case .analysisFailed, .invalidStream, .extractionFailed:
                throw CapsuleError.internalError(details: mediaError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Extract a specific stream from a container
    /// - Parameters:
    ///   - containerURL: URL of the source container
    ///   - streamIndex: Index of the stream to extract
    ///   - outputPath: Output path for the extracted stream
    ///   - correlationID: Request ID for tracing (optional)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: StreamExtractionResult with extraction details
    /// - Throws: `CapsuleError` variants for extraction failures
    public func extractStream(
        from containerURL: URL,
        streamIndex: Int,
        outputPath: String,
        correlationID: String? = nil,
        progress: ((Double) -> Void)? = nil
    ) async throws -> StreamExtractionResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "MediaContainerCapsule.extractStream",
            category: "stream_extraction",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "container_path": containerURL.path,
                "stream_index": "\(streamIndex)",
                "output_path": outputPath
            ]
        )
        
        // Validation
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "containerURL",
                constraint: "File does not exist: \(containerURL.path)"
            )
        }
        
        guard !outputPath.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "outputPath",
                constraint: "Non-empty path required"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "mediacontainercapsule.extractStream",
            message: "Extracting stream \(streamIndex) from container",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let result = try await impl.extractStream(
                from: containerURL,
                streamIndex: streamIndex,
                outputPath: outputPath,
                progress: progress
            )
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "mediacontainercapsule.extractStream",
                message: "Stream extraction completed",
                correlationID: corrID,
                metadata: [
                    "processing_time": "\(result.processingTime)",
                    "output_size": "\(result.fileSize)"
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch let mediaError as MediaContainerError {
            // Map MediaContainer errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "mediacontainercapsule.extractStream",
                message: "Stream extraction failed: \(mediaError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "MediaContainerError"]
            )
            span.end(status: .error)
            
            switch mediaError {
            case .invalidStream:
                throw CapsuleError.invalidInput(field: "streamIndex", constraint: mediaError.localizedDescription)
            case .unsupportedFormat, .analysisFailed, .extractionFailed:
                throw CapsuleError.internalError(details: mediaError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Extract subtitles from a container
    /// - Parameters:
    ///   - containerURL: URL of the source container
    ///   - outputPath: Output directory for subtitle files
    ///   - correlationID: Request ID for tracing (optional)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: Array of subtitle file paths
    /// - Throws: `CapsuleError` variants for extraction failures
    public func extractSubtitles(
        from containerURL: URL,
        outputPath: String,
        correlationID: String? = nil,
        progress: ((Double) -> Void)? = nil
    ) async throws -> [String] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "MediaContainerCapsule.extractSubtitles",
            category: "subtitle_extraction",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "container_path": containerURL.path,
                "output_path": outputPath
            ]
        )
        
        // Validation
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "containerURL",
                constraint: "File does not exist: \(containerURL.path)"
            )
        }
        
        guard !outputPath.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "outputPath",
                constraint: "Non-empty path required"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "mediacontainercapsule.extractSubtitles",
            message: "Extracting subtitles from container",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let subtitleFiles = try await impl.extractSubtitles(
                from: containerURL,
                outputPath: outputPath,
                progress: progress
            )
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "mediacontainercapsule.extractSubtitles",
                message: "Subtitle extraction completed",
                correlationID: corrID,
                metadata: [
                    "subtitle_count": "\(subtitleFiles.count)",
                    "files": subtitleFiles.joined(separator: ",")
                ]
            )
            
            span.end(status: .ok)
            return subtitleFiles
        } catch let mediaError as MediaContainerError {
            // Map MediaContainer errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "mediacontainercapsule.extractSubtitles",
                message: "Subtitle extraction failed: \(mediaError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "MediaContainerError"]
            )
            span.end(status: .error)
            
            switch mediaError {
            case .unsupportedFormat, .invalidStream:
                throw CapsuleError.invalidInput(field: "container", constraint: mediaError.localizedDescription)
            case .analysisFailed, .extractionFailed:
                throw CapsuleError.internalError(details: mediaError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get available subtitle tracks from a container
    /// - Parameters:
    ///   - containerURL: URL of the container
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Array of SubtitleInfo
    /// - Throws: `CapsuleError` variants for analysis failures
    public func getSubtitleTracks(
        from containerURL: URL,
        correlationID: String? = nil
    ) async throws -> [SubtitleInfo] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "MediaContainerCapsule.getSubtitleTracks",
            category: "subtitle_analysis",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "container_path": containerURL.path
            ]
        )
        
        // Validation
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "containerURL",
                constraint: "File does not exist: \(containerURL.path)"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "mediacontainercapsule.getSubtitleTracks",
            message: "Getting subtitle tracks from container",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let subtitleTracks = try await impl.getSubtitleTracks(from: containerURL)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "mediacontainercapsule.getSubtitleTracks",
                message: "Subtitle tracks analysis completed",
                correlationID: corrID,
                metadata: [
                    "subtitle_count": "\(subtitleTracks.count)"
                ]
            )
            
            span.end(status: .ok)
            return subtitleTracks
        } catch let mediaError as MediaContainerError {
            // Map MediaContainer errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "mediacontainercapsule.getSubtitleTracks",
                message: "Subtitle tracks analysis failed: \(mediaError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "MediaContainerError"]
            )
            span.end(status: .error)
            
            switch mediaError {
            case .unsupportedFormat, .invalidStream:
                throw CapsuleError.invalidInput(field: "container", constraint: mediaError.localizedDescription)
            case .analysisFailed, .extractionFailed:
                throw CapsuleError.internalError(details: mediaError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
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
    
    /// Perform a minimal operation on input data
    /// This is the template's example public API method.
    ///
    /// - Parameters:
    ///   - input: Input string (non-empty, max 1MB)
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Processed output string
    /// - Throws: `CapsuleError` variants matching Phase 0 spec:
    ///   - `.invalidInput` if input is empty or malformed
    ///   - `.resourceExhausted` if input exceeds max size
    ///   - `.timeout` if operation exceeds deadline
    ///   - `.internalError` if bug detected
    ///
    /// # Contract Tests (Phase 0)
    /// This method is covered by:
    /// 1. Contract test: Verify error cases match CapsuleError spec
    /// 2. Golden test: Verify deterministic output
    /// 3. Edge case tests: Empty, max size, malformed inputs
    public func process(
        _ input: String,
        correlationID: String? = nil
    ) async throws -> String {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VizAggregationCapsule.process",
            category: "processing",
            correlationID: corrID,
            tags: ["input_length": "\(input.count)"]
        )
        
        // Validation: Contract 1 - return CapsuleError for invalid inputs
        guard !input.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "input",
                constraint: "Non-empty string required"
            )
        }
        
        let maxSize = 1024 * 1024  // 1MB
        guard input.utf8.count <= maxSize else {
            span.end(status: .error)
            throw CapsuleError.resourceExhausted(
                resource: "memory",
                limit: "\(maxSize) bytes"
            )
        }
        
        // Emit diagnostic event (Contract 2)
        diagnostics.event(
            level: .debug,
            category: "vizaggregationcapsule.process",
            message: "Processing input of length \(input.count)",
            correlationID: corrID,
            metadata: ["phase": "0", "tier": "template"]
        )
        
        // Delegate to internal implementation
        do {
            let result = try impl.process(input)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vizaggregationcapsule.process",
                message: "Processing succeeded, output length: \(result.count)",
                correlationID: corrID,
                metadata: [:]
            )
            
            span.end(status: .ok)
            return result
        } catch {
            // Map implementation errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vizaggregationcapsule.process",
                message: "Processing failed: \(error)",
                correlationID: corrID,
                metadata: [:]
            )
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
