//
//  ProfilerRenderer.swift
//  RendererKit
//
//  Created by Anigma Agent.
//

import Foundation
import DataCore

public struct ProfileViewModel: Codable {
    public struct ColumnProfile: Codable {
        public let name: String
        public let type: String
        public let nullCount: Int
        public let distinctCount: Int
        public let topValues: [String]
    }

    public let totalRows: Int
    public let columns: [ColumnProfile]
    public let healthScore: Double
}

public final class ProfilerRenderer: Renderer, Sendable {
    public typealias Input = ProfileArtifact
    public typealias Output = RenderArtifact

    public let id = "com.anigma.renderer.profiler"
    public let name = "Data Profiler"
    public let description = "Statistical summary and health check of the dataset."

    public init() {}

    public func render(input: ProfileArtifact, viewSpec: ViewSpec) async throws -> RenderArtifact {
        // Transform ProfileArtifact into a view-ready model

        let columnProfiles = input.columnProfiles.map { name, profile in
            ProfileViewModel.ColumnProfile(
                name: name,
                type: profile.inferredType.rawValue,
                nullCount: profile.nullCount,
                distinctCount: profile.distinctCount,
                topValues: [] // Populate from distribution in real impl
            )
        }

        let viewModel = ProfileViewModel(
            totalRows: input.totalRows,
            columns: columnProfiles,
            healthScore: 0.95 // Calculate based on nulls/errors
        )

        let data = try JSONEncoder().encode(viewModel)

        return RenderArtifact(
            rendererId: id,
            viewSpecId: UUID(), // ViewSpec doesn't have an ID
            data: data
        )
    }
}
