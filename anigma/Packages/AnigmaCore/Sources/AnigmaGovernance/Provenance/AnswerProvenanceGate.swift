//
//  AnswerProvenanceGate.swift
//  AnigmaCore
//
//  Grounded answer gate that enforces evidence coverage requirements
//  Ensures assistant responses carry canonical provenance and receipt-backed evidence
//

import AnigmaFoundation
import AnigmaPrimitives
import GovernanceCore
import Foundation
import GovernanceContracts
import IntelligenceContracts

/// Grounded answer gate that enforces evidence coverage requirements
/// Validates that assistant responses have sufficient provenance before being returned
public struct AnswerProvenanceGate: Sendable {
    
    // MARK: - Coverage Thresholds
    
    public struct CoverageThresholds: Sendable {
        /// Minimum number of sources required for a grounded answer
        public let minimumSources: Int
        
        /// Minimum similarity score for sources to be considered relevant
        public let minimumSimilarity: Double
        
        /// Maximum age of sources in days (nil for no age limit)
        public let maximumSourceAgeDays: Int?
        
        /// Minimum receipt chain length for provenance validation
        public let minimumReceiptChainLength: Int
        
        /// Confidence threshold for determining if answer is grounded
        public let confidenceThreshold: Double
        
        public init(
            minimumSources: Int = 2,
            minimumSimilarity: Double = 0.7,
            maximumSourceAgeDays: Int? = 30,
            minimumReceiptChainLength: Int = 1,
            confidenceThreshold: Double = 0.6
        ) {
            self.minimumSources = minimumSources
            self.minimumSimilarity = minimumSimilarity
            self.maximumSourceAgeDays = maximumSourceAgeDays
            self.minimumReceiptChainLength = minimumReceiptChainLength
            self.confidenceThreshold = confidenceThreshold
        }
        
        /// Strict thresholds for high-stakes answers
        public static var strict: CoverageThresholds {
            CoverageThresholds(
                minimumSources: 3,
                minimumSimilarity: 0.8,
                maximumSourceAgeDays: 7,
                minimumReceiptChainLength: 2,
                confidenceThreshold: 0.7
            )
        }
        
        /// Lenient thresholds for exploratory answers
        public static var lenient: CoverageThresholds {
            CoverageThresholds(
                minimumSources: 1,
                minimumSimilarity: 0.6,
                maximumSourceAgeDays: 90,
                minimumReceiptChainLength: 1,
                confidenceThreshold: 0.5
            )
        }
        
        /// Default thresholds for general use
        public static var `default`: CoverageThresholds {
            CoverageThresholds()
        }
    }
    
    // MARK: - Properties
    
    private let thresholds: CoverageThresholds
    private let currentDate: @Sendable () -> Date
    
    // MARK: - Initialization
    
    public init(thresholds: CoverageThresholds = .default, currentDate: @escaping @Sendable () -> Date = { Date() }) {
        self.thresholds = thresholds
        self.currentDate = currentDate
    }
    
    // MARK: - Evidence Validation
    
    /// Validate that an answer has sufficient evidence coverage
    /// Returns nil if coverage is sufficient, or MissingContextWarning if insufficient
    public func validateCoverage(
        for answerRecord: AnswerProvenanceRecord
    ) -> MissingContextWarning? {
        
        // Check 1: Minimum sources
        guard answerRecord.sources.count >= thresholds.minimumSources else {
            return MissingContextWarning(
                type: .insufficientSources,
                message: "Insufficient sources: found \(answerRecord.sources.count), require \(thresholds.minimumSources)",
                severity: .high,
                suggestedAction: "Add more relevant sources or broaden search"
            )
        }
        
        // Check 2: Source similarity
        let highQualitySources = answerRecord.sources.filter {
            $0.similarity >= thresholds.minimumSimilarity
        }
        
        guard !highQualitySources.isEmpty else {
            return MissingContextWarning(
                type: .lowRelevance,
                message: "No high-relevance sources: all sources below \(thresholds.minimumSimilarity) similarity threshold",
                severity: .high,
                suggestedAction: "Improve query specificity or add more relevant content"
            )
        }
        
        // Check 3: Source freshness
        if let maxAgeDays = thresholds.maximumSourceAgeDays {
            let staleSources = answerRecord.sources.filter { source in
                // Check if source has timestamp information in metadata or path
                let sourceDate = extractDate(from: source) ?? currentDate()
                let ageDays = Calendar.current.dateComponents([.day], from: sourceDate, to: currentDate()).day ?? 0
                return ageDays > maxAgeDays
            }
            
            if staleSources.count == answerRecord.sources.count {
                return MissingContextWarning(
                    type: .staleContext,
                    message: "All sources older than \(maxAgeDays) days",
                    severity: .medium,
                    suggestedAction: "Update knowledge base or check for newer information"
                )
            }
        }
        
        // Check 4: Receipt chain
        guard answerRecord.receipts.count >= thresholds.minimumReceiptChainLength else {
            return MissingContextWarning(
                type: .weakProvenance,
                message: "Insufficient provenance: receipt chain length \(answerRecord.receipts.count) below minimum \(thresholds.minimumReceiptChainLength)",
                severity: .high,
                suggestedAction: "Ensure proper receipt tracking in ingestion pipeline"
            )
        }
        
        // Check 5: Confidence threshold
        guard answerRecord.confidence >= thresholds.confidenceThreshold else {
            return MissingContextWarning(
                type: .lowConfidence,
                message: "Low confidence: \(String(format: "%.2f", answerRecord.confidence)) below threshold \(String(format: "%.2f", thresholds.confidenceThreshold))",
                severity: .medium,
                suggestedAction: "Review sources or refine query"
            )
        }
        
        // All checks passed
        return nil
    }
    
    /// Validate and potentially filter an answer based on coverage requirements
    /// Returns the original answer if coverage is sufficient, or a GroundedAnswerAbstention if insufficient
    public func validateAndFilter(
        answerRecord: AnswerProvenanceRecord
    ) -> GroundedAnswerResult {
        
        if let missingContext = validateCoverage(for: answerRecord) {
            return .abstention(GroundedAnswerAbstention(
                originalQuery: answerRecord.query,
                missingContext: [missingContext],
                confidence: answerRecord.confidence,
                sources: answerRecord.sources,
                receipts: answerRecord.receipts
            ))
        }
        
        // Convert raw confidence to calibrated evaluation bin
        let calibratedConfidence = calibrateConfidence(answerRecord.confidence)
        
        return .grounded(GroundedAnswer(
            originalAnswer: answerRecord,
            calibratedConfidence: calibratedConfidence,
            coverageSummary: AnswerCoverageSummary(
                sourceCount: answerRecord.sources.count,
                highRelevanceCount: answerRecord.sources.filter { $0.similarity >= thresholds.minimumSimilarity }.count,
                receiptCount: answerRecord.receipts.count,
                missingContext: []
            )
        ))
    }
    
    // MARK: - Confidence Calibration
    
    /// Convert raw model confidence to calibrated evaluation bins
    /// Prevents surfacing raw model certainty scores that may mislead users
    private func calibrateConfidence(_ rawConfidence: Double) -> CalibratedConfidence {
        let calibratedValue = min(max(rawConfidence, 0.0), 1.0)
        
        if calibratedValue >= 0.9 {
            return .high
        } else if calibratedValue >= 0.7 {
            return .medium
        } else if calibratedValue >= 0.5 {
            return .low
        } else {
            return .veryLow
        }
    }
    
    // MARK: - Helper Methods
    
    /// Extract date from source metadata or path
    private func extractDate(from source: AnswerProvenanceSource) -> Date? {
        // Try to extract from metadata if available
        // This would be enhanced with actual metadata parsing in production
        return nil
    }
}


// MARK: - Grounded Answer Results

public enum GroundedAnswerResult: Sendable {
    case grounded(GroundedAnswer)
    case abstention(GroundedAnswerAbstention)
}

public struct GroundedAnswer: Sendable {
    public let originalAnswer: AnswerProvenanceRecord
    public let calibratedConfidence: CalibratedConfidence
    public let coverageSummary: AnswerCoverageSummary
    
    public init(
        originalAnswer: AnswerProvenanceRecord,
        calibratedConfidence: CalibratedConfidence,
        coverageSummary: AnswerCoverageSummary
    ) {
        self.originalAnswer = originalAnswer
        self.calibratedConfidence = calibratedConfidence
        self.coverageSummary = coverageSummary
    }
}

public struct GroundedAnswerAbstention: Sendable {
    public let originalQuery: String
    public let missingContext: [MissingContextWarning]
    public let confidence: Double
    public let sources: [AnswerProvenanceSource]
    public let receipts: [AnswerProvenanceReceipt]
    
    public init(
        originalQuery: String,
        missingContext: [MissingContextWarning],
        confidence: Double,
        sources: [AnswerProvenanceSource],
        receipts: [AnswerProvenanceReceipt]
    ) {
        self.originalQuery = originalQuery
        self.missingContext = missingContext
        self.confidence = confidence
        self.sources = sources
        self.receipts = receipts
    }
}
