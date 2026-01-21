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

    public init(id: UUID = UUID(), rendererId: String, viewSpecId: UUID, timestamp: Date = Date(), data: Data) {
        self.id = id
        self.rendererId = rendererId
        self.viewSpecId = viewSpecId
        self.timestamp = timestamp
        self.data = data
    }
}
