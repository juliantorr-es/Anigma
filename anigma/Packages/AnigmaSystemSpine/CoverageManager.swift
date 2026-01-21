//
//  CoverageManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public enum CoverageType: String, Codable, Sendable {
    case site
    case drive
    case folder
    case channel
    case calendar
    case contactGroup
    case project
}

public struct CoverageScope: Codable, Identifiable, Sendable {
    public let id: String
    public let type: CoverageType
    public let name: String
    public let externalId: String
    public let isExcluded: Bool

    public init(
        id: String = UUID().uuidString,
        type: CoverageType,
        name: String,
        externalId: String,
        isExcluded: Bool = false
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.externalId = externalId
        self.isExcluded = isExcluded
    }
}

public struct CoverageMap: Codable, Sendable {
    public let accountId: String
    public let scopes: [CoverageScope]

    public init(accountId: String, scopes: [CoverageScope] = []) {
        self.accountId = accountId
        self.scopes = scopes
    }
}

public actor CoverageManager {
    private var maps: [String: CoverageMap] = [:] // AccountID -> Map

    public init() {}

    public func getCoverage(accountId: String) -> CoverageMap {
        return maps[accountId] ?? CoverageMap(accountId: accountId)
    }

    public func addScope(accountId: String, scope: CoverageScope) {
        let map = getCoverage(accountId: accountId)
        var scopes = map.scopes
        if !scopes.contains(where: { $0.externalId == scope.externalId }) {
            scopes.append(scope)
        }
        maps[accountId] = CoverageMap(accountId: accountId, scopes: scopes)
    }

    public func removeScope(accountId: String, externalId: String) {
        let map = getCoverage(accountId: accountId)
        let scopes = map.scopes.filter { $0.externalId != externalId }
        maps[accountId] = CoverageMap(accountId: accountId, scopes: scopes)
    }

    public func isCovered(accountId: String, externalId: String) -> Bool {
        let map = getCoverage(accountId: accountId)
        // Simple check: is it in the list and not excluded?
        // Real logic would handle hierarchy (e.g. folder in drive)
        return map.scopes.contains { $0.externalId == externalId && !$0.isExcluded }
    }
}
