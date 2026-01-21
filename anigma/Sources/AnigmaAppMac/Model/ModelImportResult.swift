//
//  ModelImportResult.swift
//  AnigmaAppMac
//
//  Result of a model import operation.
//

import Foundation

public struct ModelImportResult {
    public let modelId: String
    public let sourceLocation: String
    public let sourceRevision: String?
    public let license: String?
    public let licenseDecision: String
    public let artifactHash: String
    public let tokenizerHash: String?
    public let conversionReceiptId: String?
    public let backendCompatibility: ModelBackendCompatibility
    public let trustTier: String
    public let warnings: [String]

    public init(
        modelId: String,
        sourceLocation: String,
        sourceRevision: String?,
        license: String?,
        licenseDecision: String,
        artifactHash: String,
        tokenizerHash: String?,
        conversionReceiptId: String?,
        backendCompatibility: ModelBackendCompatibility,
        trustTier: String,
        warnings: [String] = []
    ) {
        self.modelId = modelId
        self.sourceLocation = sourceLocation
        self.sourceRevision = sourceRevision
        self.license = license
        self.licenseDecision = licenseDecision
        self.artifactHash = artifactHash
        self.tokenizerHash = tokenizerHash
        self.conversionReceiptId = conversionReceiptId
        self.backendCompatibility = backendCompatibility
        self.trustTier = trustTier
        self.warnings = warnings
    }
}
