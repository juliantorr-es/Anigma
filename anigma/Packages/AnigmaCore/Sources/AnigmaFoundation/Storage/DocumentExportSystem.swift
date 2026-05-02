//
//  DocumentExportSystem.swift
//  AnigmaCore
//
//  Unified system for exporting governed content (PDF, Markdown, JSON).
//  Inspired by Sidekick.
//

import ContractsCore
import Foundation
import AnigmaPrimitives

public enum DocumentExportFormat: Sendable {
    case markdown
    case pdf
    case evidenceBundle // Signed JSON with attachments
}

public struct ExportRequest: Sendable {
    public let sourceId: EntityId
    public let format: DocumentExportFormat
    public let destination: URL
    public let includeEvidence: Bool
}

public actor DocumentExportSystem {
    public init() {}

    public func export(_ request: ExportRequest, runtime: RuntimeServices) async throws -> CoreReceipt {
        // 1. Fetch content (simulated retrieval)
        let content = "# Governed Document\nThis is an exported report from Anigma."

        // 2. Transform based on format
        let data: Data
        switch request.format {
        case .markdown:
            guard let encoded = content.data(using: .utf8) else {
                fatalError("Failed to unwrap data")
            }
            data = encoded
        case .evidenceBundle:
            let bundle = EvidenceBundleExport(
                content: content,
                receipts: [],
                metadata: ["exported_at": ISO8601DateFormatter().string(from: Date())]
            )
            data = try JSONEncoder().encode(bundle)
        case .pdf:
            // This would call DocumentRenderKit
            guard let encoded = content.data(using: .utf8) else {
                fatalError("Failed to unwrap data")
            }
            data = encoded
        }

        // 3. Write to destination
        try data.write(to: request.destination)

        // 4. Record evidence of export
        return try await runtime.evidence.record(
            operation: .custom,
            principal: Principal(id: "system", displayName: "System"),
            payload: .custom(
                type: "document_export",
                data: [
                    "destination": request.destination.path,
                    "format": "\(request.format)"
                ]
            ),
            governanceDecision: nil,
            context: ExecutionContext(principal: Principal(id: "system", displayName: "System"))
        )
    }
}

private struct EvidenceBundleExport: Codable {
    let content: String
    let receipts: [CoreReceipt]
    let metadata: [String: String]
}
