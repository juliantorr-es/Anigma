//
//  CodeChunk.swift
//  DevelopumModule
//
//  Model for a chunk of code.
//

import Foundation

public struct CodeChunk: Identifiable, Codable, Sendable {
    public let id: UUID
    public let content: String
    public let offset: UInt64
    public let length: UInt64
    public let hash: String
    
    public init(id: UUID = UUID(), content: String, offset: UInt64, length: UInt64, hash: String) {
        self.id = id
        self.content = content
        self.offset = offset
        self.length = length
        self.hash = hash
    }
}
