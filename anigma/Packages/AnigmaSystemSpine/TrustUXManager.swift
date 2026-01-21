//
//  TrustUXManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public struct ActionPreview: Codable, Sendable {
    public let actionId: String
    public let description: String
    public let targetSystem: String
    public let targetResource: String
    public let isReversible: Bool
    public let requiredScopes: [String]

    public init(
        actionId: String = UUID().uuidString,
        description: String,
        targetSystem: String,
        targetResource: String,
        isReversible: Bool,
        requiredScopes: [String]
    ) {
        self.actionId = actionId
        self.description = description
        self.targetSystem = targetSystem
        self.targetResource = targetResource
        self.isReversible = isReversible
        self.requiredScopes = requiredScopes
    }
}

public struct ActionResult: Codable, Sendable {
    public let actionId: String
    public let status: String // "success", "failed", "pending"
    public let receiptId: String?
    public let externalLink: String?
    public let undoActionId: String?

    public init(
        actionId: String,
        status: String,
        receiptId: String? = nil,
        externalLink: String? = nil,
        undoActionId: String? = nil
    ) {
        self.actionId = actionId
        self.status = status
        self.receiptId = receiptId
        self.externalLink = externalLink
        self.undoActionId = undoActionId
    }
}

public actor TrustUXManager {
    private var previews: [String: ActionPreview] = [:] // ActionID -> Preview
    private var results: [String: ActionResult] = [:] // ActionID -> Result

    public init() {}

    public func registerPreview(preview: ActionPreview) {
        previews[preview.actionId] = preview
    }

    public func getPreview(actionId: String) -> ActionPreview? {
        return previews[actionId]
    }

    public func recordResult(result: ActionResult) {
        results[result.actionId] = result
    }

    public func getResult(actionId: String) -> ActionResult? {
        return results[actionId]
    }

    public func generatePreview(for intentType: String, payload: Data) -> ActionPreview {
        // Stub logic to generate a preview based on intent
        // In reality, this would parse the payload and determine the impact
        return ActionPreview(
            description: "Execute \(intentType)",
            targetSystem: "Unknown",
            targetResource: "Unknown",
            isReversible: false,
            requiredScopes: []
        )
    }
}
