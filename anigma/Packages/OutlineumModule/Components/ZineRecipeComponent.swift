import AnigmaPrimitives

import AnigmaPrimitives

//
//  ZineRecipeComponent.swift
//  OutlineumModule
//
//  Stores the recipe metadata consumed by layout/export systems.
//

import AnigmaCore
import Foundation

public struct ZineRecipeComponent: Component, Codable, Sendable {
    public let title: String
    public let version: String?
    public let specPath: String
    public let imagePaths: [String]
    public let metadata: [String: String]
    public let pipelineVersion: String
    public let inputHash: String

    public init(
        title: String,
        version: String?,
        specPath: String,
        imagePaths: [String],
        metadata: [String: String] = [:],
        pipelineVersion: String,
        inputHash: String
    ) {
        self.title = title
        self.version = version
        self.specPath = specPath
        self.imagePaths = imagePaths
        self.metadata = metadata
        self.pipelineVersion = pipelineVersion
        self.inputHash = inputHash
    }
}
