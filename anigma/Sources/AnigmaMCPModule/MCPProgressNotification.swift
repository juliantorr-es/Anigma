//
//  MCPProgressNotification.swift
//  AnigmaMCPModule
//
//  Notification payload for streaming progress updates to MCP clients.
//

import MCP

public struct MCPProgressNotification: MCP.Notification {
    public static let name = "anigma/progress"

    public struct Parameters: Hashable, Codable, Sendable {
        public let toolName: String
        public let update: ProgressUpdate

        public init(toolName: String, update: ProgressUpdate) {
            self.toolName = toolName
            self.update = update
        }
    }
}
