//
//  DiaplasionErrors.swift
//  DiaplasionModule
//
//  Shared errors and helper functions for Diaplasion systems.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Diaplasion Errors

/// Errors specific to Diaplasion processing.
public enum DiaplasionError: Error, LocalizedError, Sendable {
    case fileNotFound(path: String)
    case unsupportedFormat(format: String)
    case pdfLoadFailed(path: String)
    case imageLoadFailed(path: String)
    case ocrFailed(reason: String)
    case docxExtractionFailed(reason: String)
    case textExtractionFailed(reason: String)
    case pageExtractionFailed(page: Int, reason: String)
    case cacheDirectoryCreationFailed
    case epubPackagingFailed(reason: String)
    case epubGenerationFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .pdfLoadFailed(let path):
            return "Failed to load PDF: \(path)"
        case .imageLoadFailed(let path):
            return "Failed to load image: \(path)"
        case .ocrFailed(let reason):
            return "OCR failed: \(reason)"
        case .docxExtractionFailed(let reason):
            return "DOCX extraction failed: \(reason)"
        case .textExtractionFailed(let reason):
            return "Text extraction failed: \(reason)"
        case .pageExtractionFailed(let page, let reason):
            return "Failed to extract page \(page): \(reason)"
        case .cacheDirectoryCreationFailed:
            return "Failed to create cache directory"
        case .epubPackagingFailed(let reason):
            return "EPUB packaging failed: \(reason)"
        case .epubGenerationFailed(let reason):
            return "EPUB generation failed: \(reason)"
        }
    }
}

// MARK: - Append Processing Error Configuration

/// Configuration for appending processing errors to entities.
public struct AppendProcessingErrorConfiguration: Sendable {
    public let world: World
    public let entity: EntityId
    public let stage: DiaplasionProcessingStage
    public let code: String
    public let message: String
    public let retryPolicy: RetryPolicy
    public let context: [String: String]
    public let isRetryable: Bool?

    public init(
        world: World,
        entity: EntityId,
        stage: DiaplasionProcessingStage,
        code: String,
        message: String,
        retryPolicy: RetryPolicy,
        context: [String: String] = [:],
        isRetryable: Bool? = nil
    ) {
        self.world = world
        self.entity = entity
        self.stage = stage
        self.code = code
        self.message = message
        self.retryPolicy = retryPolicy
        self.context = context
        self.isRetryable = isRetryable
    }
}

/// Appends a processing error to an entity.
public func appendProcessingError(config: AppendProcessingErrorConfiguration) async {
    var component = await config.world.getComponent(config.entity, DiaplasionProcessingErrorComponent.self)
        ?? DiaplasionProcessingErrorComponent()
    let retryable: Bool = config.isRetryable ?? (config.retryPolicy.maxRetries > 0)
    let error = DiaplasionProcessingError(
        stage: config.stage,
        code: config.code,
        message: config.message,
        isRetryable: retryable,
        retryPolicy: config.retryPolicy,
        context: config.context
    )
    component.errors.append(error)
    await config.world.addComponent(config.entity, component)
}

/// Convenience overload for appendProcessingError with individual parameters.
public func appendProcessingError(
    world: World,
    entity: EntityId,
    stage: DiaplasionProcessingStage,
    code: String,
    message: String,
    retryPolicy: RetryPolicy,
    context: [String: String] = [:],
    isRetryable: Bool? = nil
) async {
    await appendProcessingError(config: AppendProcessingErrorConfiguration(
        world: world,
        entity: entity,
        stage: stage,
        code: code,
        message: message,
        retryPolicy: retryPolicy,
        context: context,
        isRetryable: isRetryable
    ))
}

// MARK: - Shared Helpers

func sha256Hex(_ data: Data) -> String? {
#if canImport(CryptoKit)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
#else
    return nil
#endif
}

func fileHash(at url: URL) -> String? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return sha256Hex(data)
}
