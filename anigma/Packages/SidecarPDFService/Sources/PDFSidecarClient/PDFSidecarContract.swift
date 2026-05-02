//
//  PDFSidecarContract.swift
//  SidecarPDFService
//
//  IPC contract for PDF sidecar communication using Unix sockets.
//  Messages are content-addressed using BLAKE3 hashing for determinism and security.
//

import Foundation

// MARK: - Content-Addressed Message Types

/// Unique content hash of binary data (BLAKE3)
public typealias ContentHash = String

/// A request to perform PDF operations via IPC
public struct PDFSidecarRequest: Codable {
    /// Unique identifier for this request (UUID)
    public let requestID: String
    
    /// The operation to perform
    public let operation: PDFSidecarOperation
    
    /// Content hash of input data (for caching/determinism)
    public let inputHash: ContentHash?
    
    /// Timestamp of request creation (for timeout handling)
    public let createdAt: Date
    
    public init(
        requestID: String = UUID().uuidString,
        operation: PDFSidecarOperation,
        inputHash: ContentHash? = nil,
        createdAt: Date = Date()
    ) {
        self.requestID = requestID
        self.operation = operation
        self.inputHash = inputHash
        self.createdAt = createdAt
    }
}

/// Supported PDF sidecar operations
public enum PDFSidecarOperation: Codable {
    case rasterize(RasterizeRequest)
    case extract(ExtractRequest)
    case split(SplitRequest)
    case merge(MergeRequest)
    case health
    
    enum CodingKeys: String, CodingKey {
        case type, rasterize, extract, split, merge, health
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "rasterize":
            self = .rasterize(try container.decode(RasterizeRequest.self, forKey: .rasterize))
        case "extract":
            self = .extract(try container.decode(ExtractRequest.self, forKey: .extract))
        case "split":
            self = .split(try container.decode(SplitRequest.self, forKey: .split))
        case "merge":
            self = .merge(try container.decode(MergeRequest.self, forKey: .merge))
        case "health":
            self = .health
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown operation type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .rasterize(let req):
            try container.encode("rasterize", forKey: .type)
            try container.encode(req, forKey: .rasterize)
        case .extract(let req):
            try container.encode("extract", forKey: .type)
            try container.encode(req, forKey: .extract)
        case .split(let req):
            try container.encode("split", forKey: .type)
            try container.encode(req, forKey: .split)
        case .merge(let req):
            try container.encode("merge", forKey: .type)
            try container.encode(req, forKey: .merge)
        case .health:
            try container.encode("health", forKey: .type)
        }
    }
}

// MARK: - Operation Request Types

public struct RasterizeRequest: Codable {
    /// Content hash of the PDF data (BLAKE3)
    public let pdfContentHash: String
    /// Base64-encoded PDF bytes. Present only on the daemon-to-sidecar request.
    public let pdfDataBase64: String?
    /// Page index (0-based)
    public let pageIndex: Int
    /// DPI for rendering
    public let dpi: Int
    
    public init(pdfContentHash: String, pageIndex: Int, dpi: Int, pdfDataBase64: String? = nil) {
        self.pdfContentHash = pdfContentHash
        self.pdfDataBase64 = pdfDataBase64
        self.pageIndex = pageIndex
        self.dpi = dpi
    }
}

public struct ExtractRequest: Codable {
    /// Content hash of the PDF data (BLAKE3)
    public let pdfContentHash: String
    /// Base64-encoded PDF bytes. Present only on the daemon-to-sidecar request.
    public let pdfDataBase64: String?
    /// Page indices to extract (0-based)
    public let pages: [Int]
    
    public init(pdfContentHash: String, pages: [Int], pdfDataBase64: String? = nil) {
        self.pdfContentHash = pdfContentHash
        self.pdfDataBase64 = pdfDataBase64
        self.pages = pages
    }
}

public struct SplitRequest: Codable {
    /// Content hash of the PDF data (BLAKE3)
    public let pdfContentHash: String
    /// Base64-encoded PDF bytes. Present only on the daemon-to-sidecar request.
    public let pdfDataBase64: String?
    /// Split at this page index
    public let pageIndex: Int
    
    public init(pdfContentHash: String, pageIndex: Int, pdfDataBase64: String? = nil) {
        self.pdfContentHash = pdfContentHash
        self.pdfDataBase64 = pdfDataBase64
        self.pageIndex = pageIndex
    }
}

public struct MergeRequest: Codable {
    /// Content hashes of the PDF data (BLAKE3)
    public let pdfContentHashes: [String]
    /// Base64-encoded PDF byte payloads. Present only on the daemon-to-sidecar request.
    public let pdfDataBase64: [String]?
    
    public init(pdfContentHashes: [String], pdfDataBase64: [String]? = nil) {
        self.pdfContentHashes = pdfContentHashes
        self.pdfDataBase64 = pdfDataBase64
    }
}

// MARK: - Response Types

public struct PDFSidecarResponse: Codable {
    /// Request ID this response corresponds to
    public let requestID: String
    
    /// Success or error status
    public let status: ResponseStatus
    
    /// The response payload (operation-specific)
    public let payload: PDFSidecarPayload?

    /// Toolchain receipt proving execution happened in the isolated sidecar.
    public let receipt: ToolchainReceipt?
    
    /// Timestamp of response creation
    public let respondedAt: Date
    
    public init(
        requestID: String,
        status: ResponseStatus,
        payload: PDFSidecarPayload? = nil,
        receipt: ToolchainReceipt? = nil,
        respondedAt: Date = Date()
    ) {
        self.requestID = requestID
        self.status = status
        self.payload = payload
        self.receipt = receipt
        self.respondedAt = respondedAt
    }
}

public struct ToolchainReceipt: Codable, Equatable {
    public let receiptID: String
    public let toolName: String
    public let processID: Int32
    public let requestID: String
    public let operation: String
    public let inputHash: String?
    public let outputHash: String?
    public let startedAt: Date
    public let finishedAt: Date
    public let maxMemoryBytes: UInt64
    public let timeoutSeconds: Double

    public init(
        receiptID: String = UUID().uuidString,
        toolName: String = "pdf-sidecar",
        processID: Int32,
        requestID: String,
        operation: String,
        inputHash: String?,
        outputHash: String?,
        startedAt: Date,
        finishedAt: Date,
        maxMemoryBytes: UInt64,
        timeoutSeconds: Double
    ) {
        self.receiptID = receiptID
        self.toolName = toolName
        self.processID = processID
        self.requestID = requestID
        self.operation = operation
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.maxMemoryBytes = maxMemoryBytes
        self.timeoutSeconds = timeoutSeconds
    }
}

public enum ResponseStatus: String, Codable {
    case success
    case invalidRequest
    case internalError
    case documentCorrupted
    case pageNotFound
    case outOfMemory
    case sidecarCrashed
    case timeout
}

public enum PDFSidecarPayload: Codable {
    case rasterizeResult(RasterizeResult)
    case extractResult(ExtractResult)
    case splitResult(SplitResult)
    case mergeResult(MergeResult)
    case healthResult(HealthResult)
    
    enum CodingKeys: String, CodingKey {
        case type, rasterizeResult, extractResult, splitResult, mergeResult, healthResult
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "rasterize":
            self = .rasterizeResult(try container.decode(RasterizeResult.self, forKey: .rasterizeResult))
        case "extract":
            self = .extractResult(try container.decode(ExtractResult.self, forKey: .extractResult))
        case "split":
            self = .splitResult(try container.decode(SplitResult.self, forKey: .splitResult))
        case "merge":
            self = .mergeResult(try container.decode(MergeResult.self, forKey: .mergeResult))
        case "health":
            self = .healthResult(try container.decode(HealthResult.self, forKey: .healthResult))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown payload type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .rasterizeResult(let result):
            try container.encode("rasterize", forKey: .type)
            try container.encode(result, forKey: .rasterizeResult)
        case .extractResult(let result):
            try container.encode("extract", forKey: .type)
            try container.encode(result, forKey: .extractResult)
        case .splitResult(let result):
            try container.encode("split", forKey: .type)
            try container.encode(result, forKey: .splitResult)
        case .mergeResult(let result):
            try container.encode("merge", forKey: .type)
            try container.encode(result, forKey: .mergeResult)
        case .healthResult(let result):
            try container.encode("health", forKey: .type)
            try container.encode(result, forKey: .healthResult)
        }
    }
}

// MARK: - Result Types

public struct RasterizeResult: Codable {
    /// Width in pixels
    public let width: Int
    /// Height in pixels
    public let height: Int
    /// Stride in bytes
    public let stride: Int
    /// Base64-encoded RGBA8888 pixel data
    public let pixelDataBase64: String
    /// Content hash of result (BLAKE3)
    public let resultHash: String
    
    public init(width: Int, height: Int, stride: Int, pixelDataBase64: String, resultHash: String) {
        self.width = width
        self.height = height
        self.stride = stride
        self.pixelDataBase64 = pixelDataBase64
        self.resultHash = resultHash
    }
}

public struct ExtractResult: Codable {
    /// Base64-encoded PDF data
    public let pdfDataBase64: String
    /// Content hash of result (BLAKE3)
    public let resultHash: String
    
    public init(pdfDataBase64: String, resultHash: String) {
        self.pdfDataBase64 = pdfDataBase64
        self.resultHash = resultHash
    }
}

public struct SplitResult: Codable {
    /// Base64-encoded first PDF (pages 0...index-1)
    public let beforeBase64: String
    /// Base64-encoded second PDF (pages index...end)
    public let afterBase64: String
    /// Content hash of first PDF
    public let beforeHash: String
    /// Content hash of second PDF
    public let afterHash: String
    
    public init(beforeBase64: String, afterBase64: String, beforeHash: String, afterHash: String) {
        self.beforeBase64 = beforeBase64
        self.afterBase64 = afterBase64
        self.beforeHash = beforeHash
        self.afterHash = afterHash
    }
}

public struct MergeResult: Codable {
    /// Base64-encoded merged PDF data
    public let pdfDataBase64: String
    /// Content hash of result (BLAKE3)
    public let resultHash: String
    
    public init(pdfDataBase64: String, resultHash: String) {
        self.pdfDataBase64 = pdfDataBase64
        self.resultHash = resultHash
    }
}

public struct HealthResult: Codable {
    /// Sidecar process ID
    public let processID: Int32
    /// Sidecar uptime in seconds
    public let uptimeSeconds: Double
    /// True if ready to accept requests
    public let isReady: Bool
    
    public init(processID: Int32, uptimeSeconds: Double, isReady: Bool) {
        self.processID = processID
        self.uptimeSeconds = uptimeSeconds
        self.isReady = isReady
    }
}

// MARK: - Serialization Helpers

extension PDFSidecarRequest {
    /// Serialize request to JSON data
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// Deserialize request from JSON data
    public static func fromJSON(_ data: Data) throws -> PDFSidecarRequest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PDFSidecarRequest.self, from: data)
    }
}

extension PDFSidecarResponse {
    /// Serialize response to JSON data
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// Deserialize response from JSON data
    public static func fromJSON(_ data: Data) throws -> PDFSidecarResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PDFSidecarResponse.self, from: data)
    }
}
