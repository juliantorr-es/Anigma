//
//  DiaplasionWorkflows.swift
//  DiaplasionModule
//
//  Workflows for Diaplasion alt-media transformation pipelines.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Document to EPUB Workflow

/// Complete workflow for transforming documents to accessible EPUB.
/// Pipeline: Ingest → OCR → Chunking → EPUB Export → QA
public struct DocumentToEPUBWorkflow: Workflow {
    public var name: String { "Document to EPUB" }
    public var jobTypeId: String { DiaplasionJobType.documentToEPUB }

    public var systemNames: [String] {
        [
            "DocumentIngest",
            "OCRExtraction",
            "TextChunking",
            "EPUBExport",
            "DiaplasionQA"
        ]
    }

    public init() {}
}

// MARK: - Document to Braille Workflow

/// Complete workflow for transforming documents to braille-ready format.
/// Produces UEB Grade 1/2 braille in BRF and/or PEF formats.
public struct DocumentToBrailleWorkflow: Workflow {
    public var name: String { "Document to Braille" }
    public var jobTypeId: String { DiaplasionJobType.documentToBraille }

    public var systemNames: [String] {
        [
            "DocumentIngest",
            "OCRExtraction",
            "TextChunking",
            "BrailleExport",
            "DiaplasionQA"
        ]
    }

    public init() {}
}

// MARK: - Document to Audio Workflow

/// Complete workflow for transforming documents to audio-ready format.
/// Produces UEB Grade 1/2 braille in BRF and/or PEF formats.
public struct DocumentToAudioWorkflow: Workflow {
    public var name: String { "Document to Audio" }
    public var jobTypeId: String { DiaplasionJobType.documentToAudio }

    public var systemNames: [String] {
        [
            "DocumentIngest",
            "OCRExtraction",
            "TextChunking",
            "AudioPrep",
            "DiaplasionQA"
        ]
    }

    public init() {}
}

// MARK: - OCR Only Workflow

/// Lightweight workflow for OCR extraction only (no export).
/// Useful for text extraction without format conversion.
public struct OCROnlyWorkflow: Workflow {
    public var name: String { "OCR Extraction" }
    public var jobTypeId: String { DiaplasionJobType.ocrExtraction }

    public var systemNames: [String] {
        [
            "DocumentIngest",
            "OCRExtraction"
        ]
    }

    public init() {}
}

// MARK: - Multi-Format Workflow

/// Workflow that produces multiple output formats from a single source.
/// Produces UEB Grade 1/2 braille in BRF and/or PEF formats.
public struct MultiFormatWorkflow: Workflow {
    public var name: String { "Multi-Format Export" }
    public var jobTypeId: String { DiaplasionJobType.multiFormat }

    public var systemNames: [String] {
        [
            "DocumentIngest",
            "OCRExtraction",
            "TextChunking",
            "EPUBExport",      // Run if .epub in targetFormats
            "BrailleExport",   // Run if .brailleReady in targetFormats
            "AudioPrep",       // Run if .audioReady in targetFormats
            "DiaplasionQA"
        ]
    }

    public init() {}

    /// Determines if a system should run based on targetFormats in TransformRequestComponent.
    public func shouldRunSystem(_ systemName: String, for entityId: EntityId, in world: World) async -> Bool {
        // Core systems always run
        let coreSystems = ["DocumentIngest", "OCRExtraction", "TextChunking", "DiaplasionQA"]
        if coreSystems.contains(systemName) {
            return true
        }

        // Export systems only run if their format is requested
        guard let request = await world.getComponent(entityId, TransformRequestComponent.self) else {
            // No request component = run all systems (legacy behavior)
            return true
        }

        switch systemName {
        case "EPUBExport":
            return request.targetFormats.contains(.epub) || request.targetFormats.contains(.epubFixedLayout)
        case "BrailleExport":
            return request.targetFormats.contains(.brailleReady)
        case "AudioPrep":
            return request.targetFormats.contains(.audioReady)
        default:
            return true
        }
    }
}
