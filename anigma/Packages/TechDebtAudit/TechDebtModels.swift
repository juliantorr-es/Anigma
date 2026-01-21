//
//  TechDebtModels.swift
//  TechDebtAudit
//
//  [Brief description of file purpose]
//

import Foundation

public struct StubMarker: Sendable, Codable {
    public let id: String
    public let file: String
    public let line: Int

    public init(id: String, file: String, line: Int) {
        self.id = id
        self.file = file
        self.line = line
    }
}

public struct TechDebtEntry: Sendable, Codable {
    public let id: String
    public let title: String
    public let line: Int
    public let metadata: String

    public init(id: String, title: String, line: Int, metadata: String) {
        self.id = id
        self.title = title
        self.line = line
        self.metadata = metadata
    }
}

public struct TechDebtIssue: Sendable, Codable {
    public let id: String
    public let file: String
    public let line: Int
    public let snippet: String

    public init(id: String, file: String, line: Int, snippet: String) {
        self.id = id
        self.file = file
        self.line = line
        self.snippet = snippet
    }
}

public struct TechDebtEntryPayload: Sendable, Codable {
    public let id: String
    public let title: String?
    public let line: Int
    public let metadata: String

    public init(id: String, title: String? = nil, line: Int, metadata: String = "") {
        self.id = id
        self.title = title
        self.line = line
        self.metadata = metadata
    }
}

public struct TechDebtAuditReport: Sendable {
    public let markers: [StubMarker]
    public let entries: [TechDebtEntry]
    public let missingDocIDs: [TechDebtIssue]
    public let orphanedDocIDs: [TechDebtEntryPayload]
    public let success: Bool

    public init(
        markers: [StubMarker],
        entries: [TechDebtEntry],
        missingDocIDs: [TechDebtIssue],
        orphanedDocIDs: [TechDebtEntryPayload],
        success: Bool
    ) {
        self.markers = markers
        self.entries = entries
        self.missingDocIDs = missingDocIDs
        self.orphanedDocIDs = orphanedDocIDs
        self.success = success
    }
}

public enum TechDebtAuditError: Error, Sendable {
    case duplicateMarker(id: String)
    case duplicateEntry(id: String)
    case malformedMarker(reason: String)
    case malformedEntry(reason: String)
}
