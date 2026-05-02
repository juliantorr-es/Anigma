//
//  StackRecord.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public struct StackRecord: Codable, Sendable {
    public struct Branch: Codable, Sendable, Hashable {
        public var name: String
        public var parent: String
        public var createdAt: Date
        public var worktreePath: String?

        public init(name: String, parent: String, createdAt: Date = Date(), worktreePath: String? = nil) {
            self.name = name
            self.parent = parent
            self.createdAt = createdAt
            self.worktreePath = worktreePath
        }
    }

    public var schemaVersion: Int
    public var stackID: String
    public var baseBranch: String
    public var remote: String?
    public var createdAt: Date
    public var branches: [Branch]

    public init(
        schemaVersion: Int = 1,
        stackID: String,
        baseBranch: String = "main",
        remote: String? = nil,
        createdAt: Date = Date(),
        branches: [Branch] = []
    ) {
        self.schemaVersion = schemaVersion
        self.stackID = stackID
        self.baseBranch = baseBranch
        self.remote = remote
        self.createdAt = createdAt
        self.branches = branches
    }
}
