//
//  PlaceholderPipelines.swift
//  AccessumModule
//
//  Placeholder for Apertum Accesum specific workflows.
//

import AnigmaCore
import Foundation

// MARK: - Example Workflows
//
// Define Accessum-specific workflows here.

// /// Job type for document import.
// public struct DocumentImportJobType: JobType {
//     public static let identifier = "accessum.document_import"
//     public static let displayName = "Document Import"
// }
//
// /// Workflow for importing and processing documents.
// public struct DocumentImportWorkflow: Workflow {
//     public var name: String { "Document Import" }
//     public var jobTypeId: String { DocumentImportJobType.identifier }
//     public var systemNames: [String] { ["DocumentImport", "OcrProcessing", "QACheck", "Persist"] }
//
//     public init() {}
// }

// /// Job type for OCR-only processing.
// public struct OcrProcessingJobType: JobType {
//     public static let identifier = "accessum.ocr_processing"
//     public static let displayName = "OCR Processing"
// }
//
// /// Workflow for OCR processing existing documents.
// public struct OcrProcessingWorkflow: Workflow {
//     public var name: String { "OCR Processing" }
//     public var jobTypeId: String { OcrProcessingJobType.identifier }
//     public var systemNames: [String] { ["OcrProcessing", "QACheck", "Persist"] }
//
//     public init() {}
// }
