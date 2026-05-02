// DiffCapsule - Swift wrapper for document diffing
//
// This capsule provides high-performance document diffing and version comparison
// using the "Swift governs, C++ computes" architecture pattern.

import Foundation
import CapsuleCore
import TelemetryCore

/// Diff operation types
public enum DiffOpType: Int32, Codable, Hashable, Sendable {
    /// No change
    case equal = 0
    /// Deletion
    case delete = 1
    /// Insertion
    case insert = 2
    /// Replacement
    case replace = 3
}

/// Diff operation representation
public struct DiffOp: Codable, Hashable, Sendable {
    /// Operation type
    public let opType: DiffOpType
    
    /// Text for this operation
    public let text: String
    
    /// Line number in original document
    public let originalLine: Int
    
    /// Line number in modified document
    public let modifiedLine: Int
    
    /// Initialize a new diff operation
    ///
    /// - Parameters:
    ///   - opType: Operation type
    ///   - text: Text for this operation
    ///   - originalLine: Line number in original document
    ///   - modifiedLine: Line number in modified document
    public init(
        opType: DiffOpType,
        text: String,
        originalLine: Int,
        modifiedLine: Int
    ) {
        self.opType = opType
        self.text = text
        self.originalLine = originalLine
        self.modifiedLine = modifiedLine
    }
}

/// Document version representation
public struct DocumentVersion: Codable, Hashable, Sendable {
    /// Document ID
    public let docID: String
    
    /// Document content
    public let content: String
    
    /// Version timestamp
    public let timestamp: UInt64
    
    /// Author
    public let author: String?
    
    /// Version message
    public let message: String?
    
    /// Initialize a new document version
    ///
    /// - Parameters:
    ///   - docID: Document ID
    ///   - content: Document content
    ///   - timestamp: Version timestamp
    ///   - author: Author
    ///   - message: Version message
    public init(
        docID: String,
        content: String,
        timestamp: UInt64 = 0,
        author: String? = nil,
        message: String? = nil
    ) {
        self.docID = docID
        self.content = content
        self.timestamp = timestamp
        self.author = author
        self.message = message
    }
}

/// Document diff result
public struct DocumentDiffResult: Codable, Hashable, Sendable {
    /// Diff operations
    public let operations: [DiffOp]
    
    /// Original document version
    public let original: DocumentVersion
    
    /// Modified document version
    public let modified: DocumentVersion
    
    /// Similarity score (0-1)
    public let similarity: Double
    
    /// Total processing time in microseconds
    public let processingTimeUs: UInt64
    
    /// Initialize a new document diff result
    ///
    /// - Parameters:
    ///   - operations: Diff operations
    ///   - original: Original document version
    ///   - modified: Modified document version
    ///   - similarity: Similarity score
    ///   - processingTimeUs: Processing time in microseconds
    public init(
        operations: [DiffOp],
        original: DocumentVersion,
        modified: DocumentVersion,
        similarity: Double = 1.0,
        processingTimeUs: UInt64 = 0
    ) {
        self.operations = operations
        self.original = original
        self.modified = modified
        self.similarity = similarity
        self.processingTimeUs = processingTimeUs
    }
}

/// Diff configuration
public struct DiffConfig: Codable, Hashable, Sendable {
    /// Enable line-based diff
    public let enableLineDiff: Bool
    
    /// Enable word-based diff
    public let enableWordDiff: Bool
    
    /// Enable character-based diff
    public let enableCharDiff: Bool
    
    /// Ignore whitespace
    public let ignoreWhitespace: Bool
    
    /// Ignore case
    public let ignoreCase: Bool
    
    /// Context lines around changes
    public let contextLines: Int
    
    /// Default configuration
    public static var `default`: DiffConfig {
        DiffConfig(
            enableLineDiff: true,
            enableWordDiff: false,
            enableCharDiff: false,
            ignoreWhitespace: false,
            ignoreCase: false,
            contextLines: 3
        )
    }
    
    /// Initialize a new configuration
    ///
    /// - Parameters:
    ///   - enableLineDiff: Enable line-based diff
    ///   - enableWordDiff: Enable word-based diff
    ///   - enableCharDiff: Enable character-based diff
    ///   - ignoreWhitespace: Ignore whitespace
    ///   - ignoreCase: Ignore case
    ///   - contextLines: Context lines around changes
    public init(
        enableLineDiff: Bool = true,
        enableWordDiff: Bool = false,
        enableCharDiff: Bool = false,
        ignoreWhitespace: Bool = false,
        ignoreCase: Bool = false,
        contextLines: Int = 3
    ) {
        self.enableLineDiff = enableLineDiff
        self.enableWordDiff = enableWordDiff
        self.enableCharDiff = enableCharDiff
        self.ignoreWhitespace = ignoreWhitespace
        self.ignoreCase = ignoreCase
        self.contextLines = contextLines
    }
}

/// Diff capsule
public actor DiffCapsule: IdentifiableCapsule {
    private let handle: CapsuleHandle
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "diff-v1"
    
    /// Initialize the diff capsule
    ///
    /// - Parameters:
    ///   - config: Diff configuration
    ///   - diagnostics: Optional diagnostics provider
    /// - Throws: If initialization fails
    public init(
        config: DiffConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "DiffCapsule.init",
            category: "diff.init",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion,
                "enable_line_diff": "\(config.enableLineDiff)",
                "enable_word_diff": "\(config.enableWordDiff)",
                "enable_char_diff": "\(config.enableCharDiff)"
            ]
        )
        
        do {
            var cConfig = anigma_diff_config_t()
            cConfig.enable_line_diff = config.enableLineDiff
            cConfig.enable_word_diff = config.enableWordDiff
            cConfig.enable_char_diff = config.enableCharDiff
            cConfig.ignore_whitespace = config.ignoreWhitespace
            cConfig.ignore_case = config.ignoreCase
            cConfig.context_lines = Int32(config.contextLines)
            
            var cHandle = anigma_capsule_handle_t()
            let status = anigma_diff_capsule_create(&cConfig, &cHandle)
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                resolvedDiagnostics.event(
                    level: .error,
                    category: "diff.init",
                    message: "Failed to initialize diff capsule: \(error)",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw error
            }
            
            self.handle = CapsuleHandle(rawValue: cHandle)
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "diff.init",
                message: "Failed to initialize diff capsule: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    deinit {
        anigma_diff_capsule_destroy(handle.rawValue)
    }
    
    /// Compute diff between two documents
    ///
    /// - Parameters:
    ///   - original: Original document content
    ///   - modified: Modified document content
    /// - Returns: Document diff result
    /// - Throws: If diff computation fails
    public func compute(original: String, modified: String) throws -> DocumentDiffResult {
        let span = diagnostics.beginSpan(
            name: "DiffCapsule.compute",
            category: "diff.compute",
            correlationID: nil,
            tags: [
                "original_length": "\(original.count)",
                "modified_length": "\(modified.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            var cResult = anigma_document_diff_result_t()
            let status = anigma_diff_compute(
                handle.rawValue,
                original,
                original.count,
                modified,
                modified.count,
                &cResult
            )
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_diff_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Compute diff between two document versions
    ///
    /// - Parameters:
    ///   - original: Original document version
    ///   - modified: Modified document version
    /// - Returns: Document diff result
    /// - Throws: If diff computation fails
    public func compute(original: DocumentVersion, modified: DocumentVersion) throws -> DocumentDiffResult {
        let span = diagnostics.beginSpan(
            name: "DiffCapsule.computeFromVersions",
            category: "diff.compute",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            var cOriginal = original.toCDocumentVersion()
            var cModified = modified.toCDocumentVersion()
            
            var cResult = anigma_document_diff_result_t()
            let status = anigma_diff_compute_from_versions(
                handle.rawValue,
                &cOriginal,
                &cModified,
                &cResult
            )
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_diff_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Export diff to unified format
    ///
    /// - Parameter result: Diff result to export
    /// - Returns: Unified diff string
    /// - Throws: If export fails
    public func exportToUnified(result: DocumentDiffResult) throws -> String {
        var unifiedPtr: UnsafePointer<CChar>? = nil
        var unifiedLen: size_t = 0
        
        let status = anigma_diff_export_to_unified(
            result.toCDocumentDiffResult(),
            &unifiedPtr,
            &unifiedLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let unifiedPtr = unifiedPtr else {
            throw CapsuleError.internalError
        }
        
        let unified = String(cString: unifiedPtr, encoding: .utf8) ?? ""
        anigma_diff_free_export(unifiedPtr)
        
        return unified
    }
    
    /// Export diff to JSON
    ///
    /// - Parameter result: Diff result to export
    /// - Returns: JSON string
    /// - Throws: If export fails
    public func exportToJSON(result: DocumentDiffResult) throws -> String {
        var jsonPtr: UnsafePointer<CChar>? = nil
        var jsonLen: size_t = 0
        
        let status = anigma_diff_export_to_json(
            result.toCDocumentDiffResult(),
            &jsonPtr,
            &jsonLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let jsonPtr = jsonPtr else {
            throw CapsuleError.internalError
        }
        
        let json = String(cString: jsonPtr, encoding: .utf8) ?? ""
        anigma_diff_free_export(jsonPtr)
        
        return json
    }
    
    // MARK: - Private Methods
    
    private func convertResult(_ cResult: anigma_document_diff_result_t) throws -> DocumentDiffResult {
        // TODO: Implement conversion from C result to Swift result
        // This would convert the C diff structures to Swift objects
        
        return DocumentDiffResult(
            operations: [],
            original: DocumentVersion(
                docID: String(cString: cResult.original.doc_id ?? ""),
                content: String(cString: cResult.original.content ?? "")
            ),
            modified: DocumentVersion(
                docID: String(cString: cResult.modified.doc_id ?? ""),
                content: String(cString: cResult.modified.content ?? "")
            ),
            similarity: Double(cResult.similarity),
            processingTimeUs: cResult.processing_time_us
        )
    }
}

// MARK: - Extension for DocumentVersion

extension DocumentVersion {
    func toCDocumentVersion() -> anigma_document_version_t {
        // TODO: Implement conversion
        return anigma_document_version_t()
    }
}

// MARK: - Extension for DocumentDiffResult

extension DocumentDiffResult {
    func toCDocumentDiffResult() -> anigma_document_diff_result_t {
        // TODO: Implement conversion
        return anigma_document_diff_result_t()
    }
}
