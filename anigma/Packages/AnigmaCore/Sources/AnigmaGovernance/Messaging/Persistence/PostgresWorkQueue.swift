import Foundation
import MessagingContracts

public actor PostgresWorkQueue: WorkQueuePersistence {
    private let connection: PostgresConnection

    public init(connection: PostgresConnection) {
        self.connection = connection
    }

    public func enqueue(_ envelope: WorkQueueEnvelope) async throws -> JobOperationReceipt {
        let sql = """
            INSERT INTO work_queue (job_id, payload, metadata, retry_policy, created_at)
            VALUES ($1, $2, $3, $4, NOW())
            RETURNING job_id
        """

        let retryPolicyData = try JSONEncoder().encode(envelope.retryPolicy)

        // queryOne returns Optional<JobIdResult>; guard let unwraps it safely
        guard let result = try await connection.queryOne(sql, [
            envelope.jobId,
            envelope.payload,
            envelope.metadata,
            retryPolicyData
        ], decoding: JobIdResult.self) else {
            throw MessagingError.insertFailed
        }

        // result is already unwrapped above; no second guard needed

        return JobOperationReceipt(
            jobId: result.job_id,
            leaseId: UUID(),
            operation: "enqueue",
            status: "pending",
            timestamp: Timestamp(Date().timeIntervalSince1970),
            metadata: [:]
        )
    }

    public func dequeue(workerId: String, limit: Int) async throws -> [WorkQueueEnvelope] {
        let sql = """
            WITH claimed AS (
                UPDATE work_queue
                SET status = 'claimed', worker_id = $1, claimed_at = NOW()
                WHERE status = 'pending'
                RETURNING job_id, payload, metadata, retry_policy, created_at
                LIMIT $2
            )
            SELECT * FROM claimed
        """

        let results = try await connection.queryAll(sql, [workerId, limit], decoding: QueuedJob.self)

        return results.map { result in
            let retryPolicy = try! JSONDecoder().decode(RetryPolicy.self, from: result.retry_policy)

            return WorkQueueEnvelope(
                jobId: result.job_id,
                payload: result.payload,
                metadata: result.metadata,
                retryPolicy: retryPolicy,
                createdAt: Timestamp(result.created_at.timeIntervalSince1970)
            )
        }
    }

    public func lease(jobId: UUID, workerId: String, ttlSeconds: Int) async throws -> JobLease {
        let sql = """
            UPDATE work_queue
            SET status = 'leased', lease_id = gen_random_uuid(), lease_expires_at = NOW() + ($3 || ' seconds')::INTERVAL
            WHERE job_id = $1 AND (status = 'claimed' OR status = 'pending')
            RETURNING lease_id, lease_expires_at
        """

        guard let result = try await connection.queryOne(sql, [jobId, workerId, ttlSeconds], decoding: LeaseResult.self) else {
            throw MessagingError.leaseNotFound
        }

        return JobLease(
            leaseId: result.lease_id,
            jobId: jobId,
            workerId: workerId,
            claimedAt: Timestamp(Date().timeIntervalSince1970),
            expiresAt: Timestamp(result.lease_expires_at.timeIntervalSince1970)
        )
    }

    public func complete(jobId: UUID, leaseId: UUID) async throws -> JobOperationReceipt {
        let sql = """
            UPDATE work_queue
            SET status = 'completed'
            WHERE job_id = $1 AND lease_id = $2
            RETURNING lease_id
        """

        guard try await connection.queryOne(sql, [jobId, leaseId], decoding: UUID.self) != nil else {
            throw MessagingError.leaseNotFound
        }

        return JobOperationReceipt(
            jobId: jobId,
            leaseId: leaseId,
            operation: "complete",
            status: "completed",
            timestamp: Timestamp(Date().timeIntervalSince1970),
            metadata: [:]
        )
    }

    public func fail(jobId: UUID, leaseId: UUID, reason: String) async throws -> JobOperationReceipt {
        let sql = """
            UPDATE work_queue
            SET status = 'failed', failure_reason = $3
            WHERE job_id = $1 AND lease_id = $2
            RETURNING lease_id
        """

        guard try await connection.queryOne(sql, [jobId, leaseId, reason], decoding: UUID.self) != nil else {
            throw MessagingError.leaseNotFound
        }

        return JobOperationReceipt(
            jobId: jobId,
            leaseId: leaseId,
            operation: "fail",
            status: "failed",
            timestamp: Timestamp(Date().timeIntervalSince1970),
            metadata: ["reason": reason]
        )
    }

    public func nack(jobId: UUID, leaseId: UUID) async throws -> JobOperationReceipt {
        let sql = """
            UPDATE work_queue
            SET status = 'pending', lease_id = NULL, worker_id = NULL
            WHERE job_id = $1 AND lease_id = $2
            RETURNING lease_id
        """

        guard try await connection.queryOne(sql, [jobId, leaseId], decoding: UUID.self) != nil else {
            throw MessagingError.leaseNotFound
        }

        return JobOperationReceipt(
            jobId: jobId,
            leaseId: leaseId,
            operation: "nack",
            status: "pending",
            timestamp: Timestamp(Date().timeIntervalSince1970),
            metadata: [:]
        )
    }

    public func getJobStatus(jobId: UUID) async throws -> JobStatus {
        let sql = "SELECT status FROM work_queue WHERE job_id = $1"

        guard let status = try await connection.queryOne(sql, [jobId], decoding: String.self) else {
            throw MessagingError.jobNotFound
        }

        return JobStatus(rawValue: status) ?? .failed
    }

    public func recoverExpiredLeases() async throws -> Int {
        let sql = """
            UPDATE work_queue
            SET status = 'pending', lease_id = NULL, worker_id = NULL
            WHERE status = 'leased' AND lease_expires_at < NOW()
            RETURNING COUNT(*), array_agg(job_id)
        """

        guard let result = try await connection.queryOne(sql, [], decoding: RecoveryResult.self) else {
            return 0
        }

        return result.count
    }

    private struct JobIdResult: Decodable {
        let job_id: UUID
    }

    private struct QueuedJob: Decodable {
        let job_id: UUID
        let payload: Data
        let metadata: [String: String]
        let retry_policy: Data
        let created_at: Date
    }

    private struct LeaseResult: Decodable {
        let lease_id: UUID
        let lease_expires_at: Date
    }

    private struct RecoveryResult: Decodable {
        let count: Int
    }
}