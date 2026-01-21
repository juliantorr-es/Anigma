//
//  AnigmaCore.swift
//  AnigmaCore
//
//  Public API for AnigmaCore - the shared ECS and job/pipeline core.
//

import Foundation
import ContractsCore
import AnigmaPrimitives
import SecurityEventsManager

// MARK: - Core Types

// Re-export all ECS types
@_exported import struct Foundation.UUID
@_exported import struct Foundation.Date

// MARK: - Version Info

/// AnigmaCore version information.
public enum AnigmaCoreVersion {
    public static let major = 0
    public static let minor = 1
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Legacy Database Support

// Note: Direct SQLite access is deprecated in favor of DatabaseAuthority (GRDB).
// These extensions are kept for compatibility during migration but should be 
// replaced with DatabaseAuthority calls.

public extension GovernanceMode {
    /// Get current governance mode. 
    /// In a real implementation, this would query the PlatformRuntime's DatabaseAuthority.
    static func current() async -> GovernanceMode {
        // Fallback to governed if not otherwise specified.
        return .governed
    }

    /// Set governance mode.
    static func set(_ mode: GovernanceMode, by user: String = "system") async -> Bool {
        // This should be implemented via a governed mutation through DatabaseAuthority.
        return true
    }
}
