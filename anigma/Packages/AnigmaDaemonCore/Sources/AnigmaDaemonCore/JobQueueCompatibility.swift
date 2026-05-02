import Foundation
import AnigmaCore
import AnigmaSystemSpine
import AnigmaPrimitives

private func jobQueueCheckpoint(_ message: String) {
    logInfo(message, category: "JobQueueCompatibility")
}

private struct JobQueueCompatibilityJobRecord: Sendable {
    var spec: JobSpec
    var state: JobState
    var progressPermille: UInt32
    var outputs: [ArtifactRef]
    var finalReceiptHash: String
    var errorMessage: String?
    var createdAt: Date
    var clientId: String
}

private final class JobQueueCompatibilityState {
    static let shared = JobQueueCompatibilityState()

    struct State: Sendable {
        var paused = false
        var processedCount = 0
        var jobs: [String: JobQueueCompatibilityJobRecord] = [:]
    }

    private let lock = NSLock()
    private var states: [ObjectIdentifier: State] = [:]

    func withState<T>(for queue: JobQueue, _ body: (inout State) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }

        let key = ObjectIdentifier(queue)
        var state = states[key] ?? State()
        let result = body(&state)
        states[key] = state
        return result
    }

    func readState<T>(for queue: JobQueue, _ body: (State) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }

        let key = ObjectIdentifier(queue)
        return body(states[key] ?? State())
    }
}

extension JobQueue {
    func submit(spec: JobSpec, clientId: String) async throws -> String {
        let jobId = UUID().uuidString
        let payload = try JSONEncoder().encode(spec)
        let sharedJob = SharedJob(
            id: UUID(uuidString: jobId) ?? UUID(),
            type: .agentExecution,
            payload: payload,
            idempotencyKey: jobId,
            sourceSurface: clientId
        )
        try enqueue(job: sharedJob)
        jobQueueCheckpoint(
            "submit queue=\(ObjectIdentifier(self)) jobId=\(jobId) kind=\(spec.kind) source=\(clientId)"
        )

        JobQueueCompatibilityState.shared.withState(for: self) { state in
            state.jobs[jobId] = JobQueueCompatibilityJobRecord(
                spec: spec,
                state: .queued,
                progressPermille: 0,
                outputs: [],
                finalReceiptHash: "",
                errorMessage: nil,
                createdAt: sharedJob.createdAt,
                clientId: clientId
            )
        }

        return jobId
    }

    func dequeue() async -> Job? {
        guard !JobQueueCompatibilityState.shared.readState(for: self, { $0.paused }) else {
            jobQueueCheckpoint("dequeue queue=\(ObjectIdentifier(self)) paused")
            return nil
        }

        guard
            let sharedJob = try? peek()
        else {
            return nil
        }
        jobQueueCheckpoint(
            "peek queue=\(ObjectIdentifier(self)) sharedJobId=\(sharedJob.id.uuidString) source=\(sharedJob.sourceSurface)"
        )
        guard let spec = try? JSONDecoder().decode(JobSpec.self, from: sharedJob.payload) else {
            jobQueueCheckpoint(
                "decode-failed queue=\(ObjectIdentifier(self)) sharedJobId=\(sharedJob.id.uuidString)"
            )
            return nil
        }

        _ = try? pop()
        jobQueueCheckpoint(
            "pop queue=\(ObjectIdentifier(self)) sharedJobId=\(sharedJob.id.uuidString) kind=\(spec.kind)"
        )

        let jobId = sharedJob.id.uuidString
        JobQueueCompatibilityState.shared.withState(for: self) { state in
            if state.jobs[jobId] == nil {
                state.jobs[jobId] = JobQueueCompatibilityJobRecord(
                    spec: spec,
                    state: .queued,
                    progressPermille: 0,
                    outputs: [],
                    finalReceiptHash: "",
                    errorMessage: nil,
                    createdAt: sharedJob.createdAt,
                    clientId: sharedJob.sourceSurface
                )
            }
        }

        return Job(
            jobId: jobId,
            spec: spec,
            state: JobState.queued.rawValue,
            progressPermille: 0,
            outputs: [],
            finalReceiptHash: ""
        )
    }

    func markRunning(jobId: String) async {
        jobQueueCheckpoint("markRunning queue=\(ObjectIdentifier(self)) jobId=\(jobId)")
        JobQueueCompatibilityState.shared.withState(for: self) { state in
            guard var record = state.jobs[jobId] else { return }
            record.state = .running
            record.progressPermille = 0
            state.jobs[jobId] = record
        }
    }

    func complete(jobId: String, outputs: [ArtifactRef], receiptHash: String) async {
        jobQueueCheckpoint("complete queue=\(ObjectIdentifier(self)) jobId=\(jobId) outputs=\(outputs.count)")
        JobQueueCompatibilityState.shared.withState(for: self) { state in
            guard var record = state.jobs[jobId] else { return }
            record.state = .succeeded
            record.progressPermille = 1000
            record.outputs = outputs
            record.finalReceiptHash = receiptHash
            state.jobs[jobId] = record
            state.processedCount += 1
        }
    }

    func fail(jobId: String, error: String, receiptHash: String) async {
        jobQueueCheckpoint("fail queue=\(ObjectIdentifier(self)) jobId=\(jobId) error=\(error)")
        JobQueueCompatibilityState.shared.withState(for: self) { state in
            guard var record = state.jobs[jobId] else { return }
            record.state = .failed
            record.errorMessage = error
            record.finalReceiptHash = receiptHash
            state.jobs[jobId] = record
            state.processedCount += 1
        }
    }

    func cancel(jobId: String) async {
        JobQueueCompatibilityState.shared.withState(for: self) { state in
            guard var record = state.jobs[jobId] else { return }
            record.state = .canceled
            state.jobs[jobId] = record
            state.processedCount += 1
        }
    }

    func getStatus(jobId: String) async -> Job? {
        JobQueueCompatibilityState.shared.readState(for: self) { state in
            guard let record = state.jobs[jobId] else { return nil }
            return Job(
                jobId: jobId,
                spec: record.spec,
                state: record.state.rawValue,
                progressPermille: record.progressPermille,
                outputs: record.outputs.map {
                    AnigmaArtifactRef(hash: $0.hash, mediaType: $0.mediaType, sizeBytes: $0.sizeBytes)
                },
                finalReceiptHash: record.finalReceiptHash
            )
        }
    }

    func listJobs(pageToken: String? = nil, pageSize: Int? = nil, filterByState: [String] = []) async -> ([Job], String?) {
        JobQueueCompatibilityState.shared.readState(for: self) { state in
            let allowedStates = Set(filterByState.isEmpty ? JobState.allCases.map(\.rawValue) : filterByState)
            let sorted = state.jobs
                .map { jobId, record in (jobId, record) }
                .sorted { $0.1.createdAt < $1.1.createdAt }
                .filter { allowedStates.contains($0.1.state.rawValue) }

            let startIndex: Int
            if let token = pageToken, let index = sorted.firstIndex(where: { $0.0 == token }) {
                startIndex = index + 1
            } else {
                startIndex = 0
            }

            let size = max(1, min(pageSize ?? 100, 1000))
            let endIndex = min(startIndex + size, sorted.count)
            let page = sorted[startIndex..<endIndex]
            let nextToken = endIndex < sorted.count ? page.last?.0 : nil

            let jobs = page.map { jobId, record in
                Job(
                    jobId: jobId,
                    spec: record.spec,
                    state: record.state.rawValue,
                    progressPermille: record.progressPermille,
                    outputs: record.outputs.map {
                        AnigmaArtifactRef(hash: $0.hash, mediaType: $0.mediaType, sizeBytes: $0.sizeBytes)
                    },
                    finalReceiptHash: record.finalReceiptHash
                )
            }
            return (jobs, nextToken)
        }
    }

    func pause() async {
        JobQueueCompatibilityState.shared.withState(for: self) { state in
            state.paused = true
        }
    }

    func restore() async {
        JobQueueCompatibilityState.shared.withState(for: self) { state in
            state.paused = false
        }
    }

    var processedJobCount: Int {
        JobQueueCompatibilityState.shared.readState(for: self) { $0.processedCount }
    }
}
