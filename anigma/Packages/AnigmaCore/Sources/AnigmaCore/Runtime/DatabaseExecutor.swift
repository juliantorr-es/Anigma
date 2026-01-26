//
//  DatabaseExecutor.swift
//  AnigmaCore
//

import Foundation
import DatabaseCore

// MARK: - Type Aliases for Migration

/// Typealias for modules that need to reference either DatabaseActor or DatabaseAuthorityAdapter
public typealias LegacyDatabaseExecutor = any DatabaseExecutor

/// Convenience method to create a DatabaseExecutor from a DatabaseAuthority
public func makeDatabaseExecutor(from authority: any DatabaseAuthority) -> any DatabaseExecutor {
    return DatabaseAuthorityAdapter(databaseAuthority: authority)
}
