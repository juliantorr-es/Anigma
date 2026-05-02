//
//  MCPProgressNotification.swift
//  AnigmaCLIMCP
//
//  Shared progress notification payload for MCP streaming updates.
//

import Foundation
import MCP

public struct MCPProgressUpdate: Hashable, Codable, Sendable {
    public let updateId: String
    public let timestamp: Date
    public let phase: String
    public let progress: Double
    public let message: String
    public let itemsProcessed: Int?
    public let totalItems: Int?
    public let estimatedTimeRemaining: TimeInterval?
    public let currentItem: String?
    public let error: String?

    public init(
        updateId: String,
        timestamp: Date,
        phase: String,
        progress: Double,
        message: String,
        itemsProcessed: Int? = nil,
        totalItems: Int? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentItem: String? = nil,
        error: String? = nil
    ) {
        self.updateId = updateId
        self.timestamp = timestamp
        self.phase = phase
        self.progress = progress
        self.message = message
        self.itemsProcessed = itemsProcessed
        self.totalItems = totalItems
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentItem = currentItem
        self.error = error
    }
}

public struct MCPProgressNotification: MCP.Notification {
    public static let name = "anigma/progress"

    public struct Parameters: Hashable, Codable, Sendable {
        public let toolName: String
        public let update: MCPProgressUpdate

        public init(toolName: String, update: MCPProgressUpdate) {
            self.toolName = toolName
            self.update = update
        }
    }
}
