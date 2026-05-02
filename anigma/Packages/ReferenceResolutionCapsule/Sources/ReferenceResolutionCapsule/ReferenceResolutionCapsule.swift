// ReferenceResolutionCapsule - Swift wrapper for reference resolution
//
// This capsule provides high-performance reference resolution and matching
// against bibliographic databases using the "Swift governs, C++ computes" architecture pattern.

import Foundation
import CapsuleCore
import TelemetryCore
import CitationExtractionCapsule

/// Match status enumeration
public enum MatchStatus: Int32, Codable, Hashable, Sendable {
    /// Reference matched successfully
    case matched = 0
    /// Reference not matched
    case unmatched = 1
    /// Reference partially matched
    case partiallyMatched = 2
    /// Reference matching failed
    case failed = 3
}

/// Resolved reference representation
public struct ResolvedReference: Codable, Hashable, Sendable {
    /// Original reference ID
    public let originalID: String
    
    /// Resolved DOI
    public let doi: String?
    
    /// Resolved PubMed ID
    public let pubmedID: String?
    
    /// Resolved CrossRef ID
    public let crossrefID: String?
    
    /// Resolved title
    public let title: String
    
    /// Resolved authors
    public let authors: String
    
    /// Resolved year
    public let year: String?
    
    /// Resolved journal
    public let journal: String?
    
    /// Resolved volume
    public let volume: String?
    
    /// Resolved issue
    public let issue: String?
    
    /// Resolved pages
    public let pages: String?
    
    /// Match confidence score (0-1)
    public let confidence: Double
    
    /// Match status
    public let matchStatus: MatchStatus
    
    /// Initialize a new resolved reference
    ///
    /// - Parameters:
    ///   - originalID: Original reference ID
    ///   - doi: Resolved DOI
    ///   - pubmedID: Resolved PubMed ID
    ///   - crossrefID: Resolved CrossRef ID
    ///   - title: Resolved title
    ///   - authors: Resolved authors
    ///   - year: Resolved year
    ///   - journal: Resolved journal
    ///   - volume: Resolved volume
    ///   - issue: Resolved issue
    ///   - pages: Resolved pages
    ///   - confidence: Confidence score
    ///   - matchStatus: Match status
    public init(
        originalID: String,
        doi: String? = nil,
        pubmedID: String? = nil,
        crossrefID: String? = nil,
        title: String,
        authors: String,
        year: String? = nil,
        journal: String? = nil,
        volume: String? = nil,
        issue: String? = nil,
        pages: String? = nil,
        confidence: Double = 1.0,
        matchStatus: MatchStatus = .matched
    ) {
        self.originalID = originalID
        self.doi = doi
        self.pubmedID = pubmedID
        self.crossrefID = crossrefID
        self.title = title
        self.authors = authors
        self.year = year
        self.journal = journal
        self.volume = volume
        self.issue = issue
        self.pages = pages
        self.confidence = confidence
        self.matchStatus = matchStatus
    }
}

/// Reference resolution result
public struct ReferenceResolutionResult: Codable, Hashable, Sendable {
    /// Resolved references
    public let resolvedReferences: [ResolvedReference]
    
    /// Unresolved references
    public let unresolvedReferences: [ResolvedReference]
    
    /// Total processing time in microseconds
    public let processingTimeUs: UInt64
    
    /// Initialize a new reference resolution result
    ///
    /// - Parameters:
    ///   - resolvedReferences: Resolved references
    ///   - unresolvedReferences: Unresolved references
    ///   - processingTimeUs: Processing time in microseconds
    public init(
        resolvedReferences: [ResolvedReference],
        unresolvedReferences: [ResolvedReference],
        processingTimeUs: UInt64 = 0
    ) {
        self.resolvedReferences = resolvedReferences
        self.unresolvedReferences = unresolvedReferences
        self.processingTimeUs = processingTimeUs
    }
}

/// Reference resolution configuration
public struct ReferenceResolutionConfig: Codable, Hashable, Sendable {
    /// Enable online database lookup
    public let enableOnlineLookup: Bool
    
    /// Enable fuzzy matching
    public let enableFuzzyMatching: Bool
    
    /// Fuzzy matching threshold (0-1)
    public let fuzzyThreshold: Double
    
    /// Enable caching
    public let enableCaching: Bool
    
    /// Cache directory path
    public let cacheDir: String?
    
    /// CrossRef API endpoint
    public let crossrefEndpoint: String?
    
    /// PubMed API endpoint
    public let pubmedEndpoint: String?
    
    /// Default configuration
    public static var `default`: ReferenceResolutionConfig {
        ReferenceResolutionConfig(
            enableOnlineLookup: false,
            enableFuzzyMatching: true,
            fuzzyThreshold: 0.8,
            enableCaching: true,
            cacheDir: nil,
            crossrefEndpoint: nil,
            pubmedEndpoint: nil
        )
    }
    
    /// Initialize a new configuration
    ///
    /// - Parameters:
    ///   - enableOnlineLookup: Enable online database lookup
    ///   - enableFuzzyMatching: Enable fuzzy matching
    ///   - fuzzyThreshold: Fuzzy matching threshold
    ///   - enableCaching: Enable caching
    ///   - cacheDir: Cache directory path
    ///   - crossrefEndpoint: CrossRef API endpoint
    ///   - pubmedEndpoint: PubMed API endpoint
    public init(
        enableOnlineLookup: Bool = false,
        enableFuzzyMatching: Bool = true,
        fuzzyThreshold: Double = 0.8,
        enableCaching: Bool = true,
        cacheDir: String? = nil,
        crossrefEndpoint: String? = nil,
        pubmedEndpoint: String? = nil
    ) {
        self.enableOnlineLookup = enableOnlineLookup
        self.enableFuzzyMatching = enableFuzzyMatching
        self.fuzzyThreshold = fuzzyThreshold
        self.enableCaching = enableCaching
        self.cacheDir = cacheDir
        self.crossrefEndpoint = crossrefEndpoint
        self.pubmedEndpoint = pubmedEndpoint
    }
}

/// Reference resolution capsule
public actor ReferenceResolutionCapsule: IdentifiableCapsule {
    private let handle: CapsuleHandle
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "reference-resolution-v1"
    
    /// Initialize the reference resolution capsule
    ///
    /// - Parameters:
    ///   - config: Reference resolution configuration
    ///   - diagnostics: Optional diagnostics provider
    /// - Throws: If initialization fails
    public init(
        config: ReferenceResolutionConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "ReferenceResolutionCapsule.init",
            category: "referenceresolution.init",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion,
                "enable_online_lookup": "\(config.enableOnlineLookup)",
                "enable_fuzzy_matching": "\(config.enableFuzzyMatching)"
            ]
        )
        
        do {
            var cConfig = anigma_reference_resolution_config_t()
            cConfig.enable_online_lookup = config.enableOnlineLookup
            cConfig.enable_fuzzy_matching = config.enableFuzzyMatching
            cConfig.fuzzy_threshold = Float(config.fuzzyThreshold)
            cConfig.enable_caching = config.enableCaching
            cConfig.cache_dir = config.cacheDir?.cString(using: .utf8)
            cConfig.crossref_endpoint = config.crossrefEndpoint?.cString(using: .utf8)
            cConfig.pubmed_endpoint = config.pubmedEndpoint?.cString(using: .utf8)
            
            var cHandle = anigma_capsule_handle_t()
            let status = anigma_reference_resolution_capsule_create(&cConfig, &cHandle)
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                resolvedDiagnostics.event(
                    level: .error,
                    category: "referenceresolution.init",
                    message: "Failed to initialize reference resolution capsule: \(error)",
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
                category: "referenceresolution.init",
                message: "Failed to initialize reference resolution capsule: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    deinit {
        anigma_reference_resolution_capsule_destroy(handle.rawValue)
    }
    
    /// Resolve references
    ///
    /// - Parameter references: Input references to resolve
    /// - Returns: Reference resolution result
    /// - Throws: If resolution fails
    public func resolve(references: [CitationExtractionCapsule.CitationReference]) throws -> ReferenceResolutionResult {
        let span = diagnostics.beginSpan(
            name: "ReferenceResolutionCapsule.resolve",
            category: "referenceresolution.resolve",
            correlationID: nil,
            tags: [
                "reference_count": "\(references.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            // Convert references to C array
            let cReferences = references.map { $0.toCCitationReference() }
            
            var cResult = anigma_reference_resolution_result_t()
            let status = anigma_reference_resolution_resolve(
                handle.rawValue,
                cReferences,
                cReferences.count,
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
            anigma_reference_resolution_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Export resolved reference to BibTeX
    ///
    /// - Parameter reference: Resolved reference to export
    /// - Returns: BibTeX string
    /// - Throws: If export fails
    public func exportToBibTeX(reference: ResolvedReference) throws -> String {
        var bibtexPtr: UnsafePointer<CChar>? = nil
        var bibtexLen: size_t = 0
        
        let status = anigma_resolved_reference_export_to_bibtex(
            reference.toCResolvedReference(),
            &bibtexPtr,
            &bibtexLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let bibtexPtr = bibtexPtr else {
            throw CapsuleError.internalError
        }
        
        let bibtex = String(cString: bibtexPtr, encoding: .utf8) ?? ""
        anigma_reference_resolution_free_export(bibtexPtr)
        
        return bibtex
    }
    
    /// Export resolved reference to JSON
    ///
    /// - Parameter reference: Resolved reference to export
    /// - Returns: JSON string
    /// - Throws: If export fails
    public func exportToJSON(reference: ResolvedReference) throws -> String {
        var jsonPtr: UnsafePointer<CChar>? = nil
        var jsonLen: size_t = 0
        
        let status = anigma_resolved_reference_export_to_json(
            reference.toCResolvedReference(),
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
        anigma_reference_resolution_free_export(jsonPtr)
        
        return json
    }
    
    // MARK: - Private Methods
    
    private func convertResult(_ cResult: anigma_reference_resolution_result_t) throws -> ReferenceResolutionResult {
        // TODO: Implement conversion from C result to Swift result
        // This would convert the C resolved reference structures to Swift objects
        
        return ReferenceResolutionResult(
            resolvedReferences: [],
            unresolvedReferences: [],
            processingTimeUs: cResult.processing_time_us
        )
    }
}

// MARK: - Extension for CitationExtractionCapsule.CitationReference

extension CitationExtractionCapsule.CitationReference {
    func toCCitationReference() -> anigma_citation_reference_t {
        // TODO: Implement conversion
        return anigma_citation_reference_t()
    }
}

// MARK: - Extension for ResolvedReference

extension ResolvedReference {
    func toCResolvedReference() -> anigma_resolved_reference_t {
        // TODO: Implement conversion
        return anigma_resolved_reference_t()
    }
}
