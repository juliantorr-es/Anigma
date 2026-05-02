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
    public let data: Data
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

public final class DataGridRenderer: Renderer, Sendable {
    public typealias Input = TabularIR
    public typealias Output = RenderArtifact

    public let id = "com.anigma.renderer.datagrid"
    public let name = "Data Grid"
    public let description = "Tabular view of data with virtualization support."

    public init() {}

    public func render(input: TabularIR, viewSpec: ViewSpec) async throws -> RenderArtifact {
        let columns = input.schema.columns.map { $0.name }
        let rows = (0..<min(10, input.rowCount)).map { i in
            columns.map { "Row \(i) \($0)" }
        }

        let visibleRowCount = UInt32(min(10, rows.count))
        let columnCount = UInt32(max(1, columns.count))
        let estimatedPrimitiveCount = max(1, visibleRowCount * columnCount + columnCount)
        let projection = UIProjection(
            role: "data-grid",
            attachmentFormat: .rgba8unorm,
            estimatedVertexCount: estimatedPrimitiveCount * 4,
            estimatedPrimitiveCount: estimatedPrimitiveCount,
            blendMode: .alpha,
            prefersIndexedPrimitives: true
        )

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
            viewSpecId: UUID(),
            data: data,
            projection: projection
        )
    }
}

public struct GridViewModel: Codable {
    public let columns: [String]
    public let rows: [[String]]
    public let totalRows: Int
    public let page: Int
    public let pageSize: Int
}

public final class ProfilerRenderer: Renderer, Sendable {
    public typealias Input = ProfileArtifact
    public typealias Output = RenderArtifact

    public let id = "com.anigma.renderer.profiler"
    public let name = "Data Profiler"
    public let description = "Statistical summary and health check of the dataset."

    public init() {}

    public func render(input: ProfileArtifact, viewSpec: ViewSpec) async throws -> RenderArtifact {
        let columnProfiles = input.columnProfiles.map { name, profile in
            ProfileViewModel.ColumnProfile(
                name: name,
                type: profile.inferredType.rawValue,
                nullCount: profile.nullCount,
                distinctCount: profile.distinctCount,
                topValues: []
            )
        }

        let estimatedPrimitiveCount = max(1, UInt32(columnProfiles.count) * 2 + 1)
        let projection = UIProjection(
            role: "data-profiler",
            attachmentFormat: .rgba16float,
            estimatedVertexCount: estimatedPrimitiveCount * 4,
            estimatedPrimitiveCount: estimatedPrimitiveCount,
            blendMode: .alpha,
            prefersIndexedPrimitives: true
        )

        let viewModel = ProfileViewModel(
            totalRows: input.totalRows,
            columns: columnProfiles,
            healthScore: 0.95
        )

        let data = try JSONEncoder().encode(viewModel)
        return RenderArtifact(
            rendererId: id,
            viewSpecId: UUID(),
            data: data,
            projection: projection
        )
    }
}

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
