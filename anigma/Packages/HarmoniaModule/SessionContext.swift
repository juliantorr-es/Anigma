//
//  SessionContext.swift
//  HarmoniaModule
//
//  Session context for tool execution.
//

import Foundation

/// Context information about the current session
public struct SessionContext: Codable, Sendable {
    /// Unique session identifier
    public let sessionId: String

    /// Agent identifier
    public let agentId: String

    /// Session permissions
    public let permissions: Set<Permission>

    /// Session status
    public var status: SessionStatus

    /// When the session was created
    public let createdAt: Date

    /// When the session expires
    public let expiresAt: Date

    /// Current working directory for this session
    public let workingDirectory: String

    /// Allow wrapper execution for governed builds
    public let allowGovernedBuild: Bool

    public init(
        sessionId: String,
        agentId: String,
        permissions: Set<Permission>,
        workingDirectory: String = FileManager.default.currentDirectoryPath,
        duration: TimeInterval = 3600, // 1 hour by default
        allowGovernedBuild: Bool = false
    ) {
        self.sessionId = sessionId
        self.agentId = agentId
        self.permissions = permissions
        self.status = .active
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(duration)
        self.workingDirectory = workingDirectory
        self.allowGovernedBuild = allowGovernedBuild
    }
}
