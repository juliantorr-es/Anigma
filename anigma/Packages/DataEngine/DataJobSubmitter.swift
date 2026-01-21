import Foundation
import DataCore
import AnigmaSystemSpine

public actor DataJobSubmitter {
    private let jobEngine: JobEngine

    public init(jobEngine: JobEngine) {
        self.jobEngine = jobEngine
    }

    public func submitIngestJob(source: URL, options: IngestionOptions) async throws -> UUID {
        let payload = try JSONEncoder().encode(IngestJobPayload(source: source, options: options))
        let job = SharedJob(
            type: .ingest,
            payload: payload,
            idempotencyKey: "ingest-\(source.absoluteString)",
            sourceSurface: "data.engine"
        )
        try await jobEngine.enqueue(job)
        return job.id
    }

    public func submitProfileJob(ir: TabularIR) async throws -> UUID {
        let payload = try JSONEncoder().encode(ProfileJobPayload(ir: ir))
        let job = SharedJob(
            type: .profile,
            payload: payload,
            idempotencyKey: "profile-\(ir.storagePointer)",
            sourceSurface: "data.engine"
        )
        try await jobEngine.enqueue(job)
        return job.id
    }

    // Add other job submission methods...
}

struct IngestJobPayload: Codable {
    let source: URL
    let options: IngestionOptions
}

struct ProfileJobPayload: Codable {
    let ir: TabularIR
}
