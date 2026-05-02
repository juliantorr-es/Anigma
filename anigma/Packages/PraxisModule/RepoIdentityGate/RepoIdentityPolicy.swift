//
//  RepoIdentityPolicy.swift
//  PraxisModule
//
//  [Brief description of file purpose]
//

import Foundation

public struct RepoIdentityPolicy: Codable, Sendable {
    public let policyVersion: Int
    public let allowedRepoRoots: [String]
    public let allowedBranches: [String]
    public let rejectDetachedHEAD: Bool
    public let requireCleanWorkingTree: Bool
    public let rejectWorktreesUnderPaths: [String]
    public let requireOriginURLPrefix: [String]
    public let allowIfRepoRootContains: [String]

    public init(
        policyVersion: Int = 1,
        allowedRepoRoots: [String],
        allowedBranches: [String],
        rejectDetachedHEAD: Bool = true,
        requireCleanWorkingTree: Bool = true,
        rejectWorktreesUnderPaths: [String] = [],
        requireOriginURLPrefix: [String] = [],
        allowIfRepoRootContains: [String] = []
    ) {
        self.policyVersion = policyVersion
        self.allowedRepoRoots = allowedRepoRoots
        self.allowedBranches = allowedBranches
        self.rejectDetachedHEAD = rejectDetachedHEAD
        self.requireCleanWorkingTree = requireCleanWorkingTree
        self.rejectWorktreesUnderPaths = rejectWorktreesUnderPaths
        self.requireOriginURLPrefix = requireOriginURLPrefix
        self.allowIfRepoRootContains = allowIfRepoRootContains
    }

    public static func load(from url: URL) throws -> RepoIdentityPolicy {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RepoIdentityPolicy.self, from: data)
    }
}
