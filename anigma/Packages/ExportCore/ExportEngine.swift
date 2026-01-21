import Foundation
import AnigmaSystemSpine

public actor ExportEngine {
    private let jobEngine: JobEngine

    public init(jobEngine: JobEngine) {
        self.jobEngine = jobEngine
    }

    public func compilePlan(request: ExportRequest) async throws -> ExportPlan {
        // In a real implementation, this would resolve the profile ID to a spec
        // and merge options into overrides.
        // For now, we return a stub plan.
        let profile = ExportProfileSpec(
            id: request.profileId,
            version: "1.0.0",
            name: "Stub Profile",
            description: "Stub",
            intent: .digital,
            pipelineSteps: [],
            outputFormats: ["pdf"],
            constraints: [:]
        )

        return ExportPlan(
            id: UUID().uuidString,
            profile: profile,
            overrides: OverrideSpec(),
            inputs: request.inputs,
            target: request.target
        )
    }

    public func execute(plan: ExportPlan) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            Task {
                let jobId = UUID()
                do {
                    // Enqueue job to system spine
                    try await jobEngine.enqueue(
                        SharedJob(
                            id: jobId,
                            type: .export,
                            payload: try JSONEncoder().encode(plan),
                            idempotencyKey: plan.id,
                            sourceSurface: "universal.export"
                        )
                    )

                    continuation.yield(.started(jobId: jobId.uuidString))
                    continuation.yield(.phase(name: "Queued"))

                    // In a real implementation, we would subscribe to job updates here.
                    // For this spine, we simulate progress but now backed by a real job ID.

                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continuation.yield(.phase(name: "Compiling"))

                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continuation.yield(.phase(name: "Rendering"))
                    continuation.yield(.progress(completed: 50, total: 100))

                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continuation.yield(.progress(completed: 100, total: 100))
                    continuation.yield(.finished(success: true, receiptRef: "receipt-\(jobId.uuidString)"))
                    continuation.finish()

                } catch {
                    continuation.yield(.failed(message: error.localizedDescription, receiptRef: nil))
                    continuation.finish()
                }
            }
        }
    }
}
