//
//  DataGridRenderer.swift
//  RendererKit
//
//  Created by Anigma Agent.
//

import Foundation
import DataCore

public struct GridViewModel: Codable {
    public let columns: [String]
    public let rows: [[String]]
    public let totalRows: Int
    public let page: Int
    public let pageSize: Int
}

public final class DataGridRenderer: Renderer, Sendable {
    public typealias Input = TabularIR
    public typealias Output = RenderArtifact

    public let id = "com.anigma.renderer.datagrid"
    public let name = "Data Grid"
    public let description = "Tabular view of data with virtualization support."

    public init() {}

    public func render(input: TabularIR, viewSpec: ViewSpec) async throws -> RenderArtifact {
        // In a real implementation, this would apply filters/sorts from ViewSpec
        // and paginate the data from the storage backend.
        // For now, we generate a simple view model from the IR metadata/sample.

        let columns = input.schema.columns.map { $0.name }
        // Mocking rows for the IR stub
        let rows = (0..<min(10, input.rowCount)).map { i in
            columns.map { "Row \(i) \($0)" }
        }

        let viewModel = GridViewModel(
            columns: columns,
            rows: rows,
            totalRows: input.rowCount,
            page: 1,
            pageSize: 50
        )

        let data = try JSONEncoder().encode(viewModel)

        return RenderArtifact(
            rendererId: id,
            viewSpecId: UUID(), // ViewSpec doesn't have an ID, generating one for the artifact
            data: data
        )
    }
}
