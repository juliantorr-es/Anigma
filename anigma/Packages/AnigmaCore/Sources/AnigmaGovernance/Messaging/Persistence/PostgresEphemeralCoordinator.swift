import Foundation
import MessagingContracts

public actor PostgresEphemeralCoordinator: CoordinatorService {
    private let connection: PostgresConnection

    public init(connection: PostgresConnection) {
        self.connection = connection
    }

    public func acquireLease(key: String, holder: WorkerId, ttlSeconds: Int) async throws -> CoordinatorLease {
        let sql = """
            INSERT INTO coordinator_leases (lease_id, key, holder, expires_at)
            VALUES (gen_random_uuid(), $1, $2, NOW() + ($3 || ' seconds')::INTERVAL)
            ON CONFLICT (key) DO UPDATE
            SET holder = EXCLUDED.holder, expires_at = EXCLUDED.expires_at
            WHERE coordinator_leases.expires_at < NOW()
            RETURNING lease_id, key, holder, expires_at
        """
        
        guard let result = try await connection.queryOne(sql, [key, holder, ttlSeconds], decoding: StoredLease.self) else {
            throw MessagingError.leaseNotFound
        }
        
        return CoordinatorLease(
            leaseId: result.lease_id,
            key: result.key,
            holder: result.holder,
            expiresAt: Timestamp(result.expires_at.timeIntervalSince1970)
        )
    }

    public func refreshLease(leaseId: UUID, ttlSeconds: Int) async throws -> CoordinationReceipt {
        let sql = """
            UPDATE coordinator_leases
            SET expires_at = NOW() + ($2 || ' seconds')::INTERVAL
            WHERE lease_id = $1
            RETURNING expires_at
        """
        
        guard let result = try await connection.queryOne(sql, [leaseId, ttlSeconds], decoding: UpdatedLease.self) else {
            throw MessagingError.leaseNotFound
        }
        
        return CoordinationReceipt(
            leaseId: leaseId,
            operation: "refresh",
            timestamp: Timestamp(result.expires_at.timeIntervalSince1970),
            signature: "postgres-refresh"
        )
    }

    public func releaseLease(leaseId: UUID) async throws -> CoordinationReceipt {
        let sql = """
            DELETE FROM coordinator_leases
            WHERE lease_id = $1
            RETURNING key
        """
        
        let result = try await connection.queryOne(sql, [leaseId], decoding: LeaseKey.self)
        
        return CoordinationReceipt(
            leaseId: leaseId,
            operation: "release",
            timestamp: Timestamp(Date().timeIntervalSince1970),
            signature: "postgres-released"
        )
    }

    public func heartbeat(workerId: WorkerId, ttlSeconds: Int) async throws -> WorkerPresence {
        let sql = """
            INSERT INTO worker_presence (worker_id, last_seen, status)
            VALUES ($1, NOW(), 'alive')
            ON CONFLICT (worker_id) DO UPDATE
            SET last_seen = NOW(), status = 'alive'
            RETURNING status, last_seen
        """
        
        guard let result = try await connection.queryOne(sql, [workerId], decoding: StoredPresence.self) else {
            throw MessagingError.invalidStreamId
        }
        
        return WorkerPresence(
            workerId: workerId,
            status: PresenceStatus(rawValue: result.status) ?? .alive,
            lastSeen: Timestamp(result.last_seen.timeIntervalSince1970)
        )
    }

    public func checkPresence(workerId: WorkerId) async throws -> PresenceStatus {
        let sql = """
            SELECT status, last_seen
            FROM worker_presence
            WHERE worker_id = $1
        """
        
        guard let result = try await connection.queryOne(sql, [workerId], decoding: StoredPresence.self) else {
            return .unknown
        }
        
        return PresenceStatus(rawValue: result.status) ?? .unknown
    }

    // MARK: - Private Types

    private struct StoredLease: Decodable {
        let lease_id: UUID
        let key: String
        let holder: String
        let expires_at: Date
    }

    private struct UpdatedLease: Decodable {
        let expires_at: Date
    }

    private struct LeaseKey: Decodable {
        let key: String
    }

    private struct StoredPresence: Decodable {
        let status: String
        let last_seen: Date
    }
}