//
//  DiaplasionSystems.swift
//  DiaplasionModule
//
//  Barrel file that re-exports all Diaplasion systems.
//
//  Systems for Diaplasion alt-media transformation pipelines.
//
//  These systems use Apple frameworks (Vision, CoreGraphics, PDFKit)
//  to implement document processing without external dependencies.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
import TextChunkingCapsule
import AnigmaNativeShims
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Phase 5: Error Recovery & Resilience Systems (TODO: Implement these)

/*
/// Global resilience systems for Diaplasion pipeline.
/// These systems provide retry mechanisms, error handling, and resilient processing.
public let DiaplasionRetryManager = RetryManager()
public let DiaplasionErrorHandler = ErrorHandler()
public let DiaplasionProgressTracker = ProgressTracker()
public let DiaplasionCheckpointManager = CheckpointManager()

/// Resilient processing system that integrates all Phase 5 components
public let DiaplasionResilientSystem = ResilientProcessingSystem(
    config: .default
)
*/

// MARK: - Re-exports

// The following systems have been extracted to separate files:
// - DocumentIngestSystem.swift
// - OCRExtractionSystem.swift
// - TextChunkingSystem.swift
// - EPUBExportSystem.swift
// - BrailleExportSystem.swift
// - AudioPrepSystem.swift
// - QAValidationSystem.swift
// - EnhancedDocumentIngestSystem.swift
