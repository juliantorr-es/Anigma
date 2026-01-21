//
//  DealComponent.swift
//  ConexusModule
//
//  Component representing a deal/opportunity in a pipeline.
//

import Foundation
import AnigmaCore

/// Component representing a deal or opportunity in a pipeline.
public struct DealComponent: Component, Sendable, Codable {
    public let dealId: DealId
    public var pipelineId: PipelineId
    public var stageId: String

    // Basic information
    public var name: String
    public var description: String?

    // Value
    public var amount: Decimal?
    public var currency: String

    // Timing
    public var expectedCloseDate: Date?
    public var actualCloseDate: Date?

    // Relationships
    public var contactIds: [ContactId]
    public var organizationId: OrganizationId?
    public var primaryContactId: ContactId?

    // Classification
    public var source: String?          // Where the deal came from
    public var campaignId: String?      // Marketing campaign
    public var tags: Set<String>
    public var customFields: [String: String]

    // Probability and forecasting
    public var probability: Double      // 0.0 to 1.0
    public var weightedAmount: Decimal? {
        guard let amount = amount else { return nil }
        return amount * Decimal(probability)
    }

    // Lifecycle
    public var createdAt: Date
    public var updatedAt: Date
    public var stageEnteredAt: Date
    public var ownerId: String?

    // Outcome
    public var isWon: Bool
    public var isLost: Bool
    public var lossReason: String?

    public init(
        dealId: DealId = DealId(),
        pipelineId: PipelineId,
        stageId: String,
        name: String,
        description: String? = nil,
        amount: Decimal? = nil,
        currency: String = "USD",
        expectedCloseDate: Date? = nil,
        contactIds: [ContactId] = [],
        organizationId: OrganizationId? = nil,
        primaryContactId: ContactId? = nil,
        source: String? = nil,
        campaignId: String? = nil,
        tags: Set<String> = [],
        customFields: [String: String] = [:],
        probability: Double = 0.5,
        ownerId: String? = nil
    ) {
        self.dealId = dealId
        self.pipelineId = pipelineId
        self.stageId = stageId
        self.name = name
        self.description = description
        self.amount = amount
        self.currency = currency
        self.expectedCloseDate = expectedCloseDate
        self.contactIds = contactIds
        self.organizationId = organizationId
        self.primaryContactId = primaryContactId
        self.source = source
        self.campaignId = campaignId
        self.tags = tags
        self.customFields = customFields
        self.probability = probability
        self.createdAt = Date()
        self.updatedAt = Date()
        self.stageEnteredAt = Date()
        self.ownerId = ownerId
        self.isWon = false
        self.isLost = false
    }

    /// Marks deal as won.
    public mutating func markWon() {
        isWon = true
        isLost = false
        actualCloseDate = Date()
        probability = 1.0
        updatedAt = Date()
    }

    /// Marks deal as lost with optional reason.
    public mutating func markLost(reason: String? = nil) {
        isWon = false
        isLost = true
        actualCloseDate = Date()
        probability = 0.0
        lossReason = reason
        updatedAt = Date()
    }

    /// Moves deal to a new stage.
    public mutating func moveToStage(_ newStageId: String, probability: Double? = nil) {
        stageId = newStageId
        stageEnteredAt = Date()
        updatedAt = Date()
        if let prob = probability {
            self.probability = prob
        }
    }

    /// Days in current stage.
    public var daysInStage: Int {
        Calendar.current.dateComponents([.day], from: stageEnteredAt, to: Date()).day ?? 0
    }

    /// Days since creation.
    public var age: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
}
