import Foundation
import DataCore
import DataEngine
import AnigmaCorporate
import AnigmaEducation

public struct ToolBridge {
    let dataEngine: DataEngine

    public init(dataEngine: DataEngine) {
        self.dataEngine = dataEngine
    }

    public func ingest(source: URL, contextId: UUID) async throws -> Artifact {
        // Call DataEngine ingestion
        let artifact = try await dataEngine.ingest(source: source)
        return artifact
    }
}
