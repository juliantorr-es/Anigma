//
//  Renderer.swift
//  RendererKit
//
//  Created by Anigma Agent.
//

import Foundation
import DataCore

public protocol Renderer {
    associatedtype Input
    associatedtype Output

    var id: String { get }
    var name: String { get }
    var description: String { get }

    func render(input: Input, viewSpec: ViewSpec) async throws -> Output
}

public struct RenderArtifact: Identifiable, Codable {
    public let id: UUID
    public let rendererId: String
    public let viewSpecId: UUID
    public let timestamp: Date
    public let data: Data // Serialized render output (e.g., JSON for a chart, or a view model)
    public let projection: UIProjection?
    
    public init(
        id: UUID = UUID(),
        rendererId: String,
        viewSpecId: UUID,
        timestamp: Date = Date(),
        data: Data,
        projection: UIProjection? = nil
    ) {
        self.id = id
        self.rendererId = rendererId
        self.viewSpecId = viewSpecId
        self.timestamp = timestamp
        self.data = data
        self.projection = projection
    }
}

public enum UIProjectionBackend: String, Sendable, Codable, Hashable {
    case metal
}

public enum UIProjectionAttachmentFormat: String, Sendable, Codable, Hashable {
    case rgba8unorm
    case rgba16float
    case rgba32float
    case depth32float
}

public enum UIProjectionBlendMode: String, Sendable, Codable, Hashable {
    case opaque
    case alpha
    case additive
}

public struct UIProjection: Sendable, Codable, Hashable {
    public let backend: UIProjectionBackend
    public let role: String
    public let attachmentFormat: UIProjectionAttachmentFormat
    public let estimatedVertexCount: UInt32
    public let estimatedPrimitiveCount: UInt32
    public let blendMode: UIProjectionBlendMode
    public let prefersIndexedPrimitives: Bool
    
    public init(
        backend: UIProjectionBackend = .metal,
        role: String,
        attachmentFormat: UIProjectionAttachmentFormat = .rgba8unorm,
        estimatedVertexCount: UInt32,
        estimatedPrimitiveCount: UInt32,
        blendMode: UIProjectionBlendMode = .alpha,
        prefersIndexedPrimitives: Bool = true
    ) {
        self.backend = backend
        self.role = role
        self.attachmentFormat = attachmentFormat
        self.estimatedVertexCount = estimatedVertexCount
        self.estimatedPrimitiveCount = estimatedPrimitiveCount
        self.blendMode = blendMode
        self.prefersIndexedPrimitives = prefersIndexedPrimitives
    }
    
    public var isMetalBacked: Bool {
        backend == .metal
    }
}
