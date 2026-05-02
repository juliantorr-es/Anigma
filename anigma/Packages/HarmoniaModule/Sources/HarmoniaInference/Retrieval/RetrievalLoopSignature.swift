//
//  RetrievalLoopSignature.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import InferenceCore
@preconcurrency import Foundation

public struct RetrievalLoopSignature: Sendable, Hashable, Codable {
    public let queryHash: String
    public let mode: String
    public let pathPrefix: String
    public let limit: Int
    public let resultHash: String

    public init(queryHash: String, mode: String, pathPrefix: String?, limit: Int, resultHash: String) {
        self.queryHash = queryHash
        self.mode = mode
        self.pathPrefix = pathPrefix ?? ""
        self.limit = limit
        self.resultHash = resultHash
    }
}
