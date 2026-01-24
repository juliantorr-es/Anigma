//
//  SharedPDFTypes.swift
//  AnigmaCore
//
//  Contract definition for SharedPDFTypes in AnigmaCore.
//

import Foundation
import ContractsCore

/// Represents a raw PDF blob artifact.
public struct PDFBlobArtifact: Codable, Sendable {
    public let blobID: String // A unique identifier for the raw PDF blob
    public let pageCount: Int // Number of pages in the PDF
    public let rawData: Data // Raw PDF bytes ingested by the pipeline

    public init(blobID: String, pageCount: Int, rawData: Data) {
        self.blobID = blobID
        self.pageCount = pageCount
        self.rawData = rawData
    }
}
