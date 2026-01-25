//
//  BundleTemplate.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

@preconcurrency import Foundation

// Public because it's used by public APIs. Keeping it top-level avoids ordering
// weirdness and forward-reference surprises.
public struct BundleTemplate: Sendable, Codable, Equatable {
    public let templateID: String
    public let name: String
    public let rules: [String]
    public let createdAt: Date

    public init(
        templateID: String,
        name: String,
        rules: [String],
        createdAt: Date = Date()
    ) {
        self.templateID = templateID
        self.name = name
        self.rules = rules
        self.createdAt = createdAt
    }
}
