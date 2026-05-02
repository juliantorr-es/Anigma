import Foundation

/// Defines all database schema for PostgreSQL-backed messaging implementations
public struct MessagingDatabaseSchema {
  /// Migration version (increment on schema changes)
  public static let currentVersion: Int = 1

  /// SQL DDL for event log table (immutable append-only)
  public static let eventLogTableDDL: String = """
    CREATE TABLE IF NOT EXISTS messaging_event_logs (
      id BIGSERIAL PRIMARY KEY,
      event_id UUID NOT NULL UNIQUE,
      stream_id TEXT NOT NULL,
      topic TEXT NOT NULL,
      project_id TEXT NOT NULL,
      partition_key TEXT,
      position BIGINT NOT NULL,
      cursor_checkpoint_id UUID,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      schema_version TEXT NOT NULL,
      source TEXT NOT NULL,
      source_capability_id TEXT,
      parent_event_id UUID,
      hardware_lane TEXT,
      payload BYTEA,
      backpressure_queue_depth INT,
      backpressure_estimated_delay_ms INT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Composite index for stream lookups
    CREATE INDEX IF NOT EXISTS idx_event_logs_stream_position
      ON messaging_event_logs(stream_id, position DESC);

    -- Index for cursor replay queries
    CREATE INDEX IF NOT EXISTS idx_event_logs_stream_created
      ON messaging_event_logs(stream_id, created_at DESC);

    -- Index for checkpoint lookups
    CREATE INDEX IF NOT EXISTS idx_event_logs_checkpoint
      ON messaging_event_logs(cursor_checkpoint_id)
      WHERE cursor_checkpoint_id IS NOT NULL;

    -- Unique position constraint per stream
    CREATE UNIQUE INDEX IF NOT EXISTS idx_event_logs_stream_position_unique
      ON messaging_event_logs(stream_id, position);
  """

  /// SQL DDL for work queue table (mutable, state transitions)
  public static let workQueueTableDDL: String = """
    CREATE TABLE IF NOT EXISTS messaging_work_queue (
      job_id UUID PRIMARY KEY,
      idempotency_key TEXT NOT NULL,
      stream_id TEXT,
      project_id TEXT NOT NULL,
      priority INT NOT NULL DEFAULT 50,
      payload BYTEA,
      retry_policy_max_attempts INT NOT NULL DEFAULT 3,
      retry_policy_initial_delay_ms INT NOT NULL DEFAULT 1000,
      retry_policy_backoff_multiplier FLOAT NOT NULL DEFAULT 2.0,
      retry_policy_max_delay_ms INT NOT NULL DEFAULT 60000,
      retry_policy_dead_letter_after BOOLEAN NOT NULL DEFAULT true,
      source_capability_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempt_count INT NOT NULL DEFAULT 0,
      last_error TEXT,
      enqueued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      next_run_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      completed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Unique idempotency key per job stream
    CREATE UNIQUE INDEX IF NOT EXISTS idx_work_queue_idempotency
      ON messaging_work_queue(idempotency_key, stream_id);

    -- Index for claiming pending jobs (priority, next_run_at)
    CREATE INDEX IF NOT EXISTS idx_work_queue_claim
      ON messaging_work_queue(status, priority DESC, next_run_at)
      WHERE status = 'pending';

    -- Index for status lookups
    CREATE INDEX IF NOT EXISTS idx_work_queue_status
      ON messaging_work_queue(status, created_at DESC);

    -- Index for dead-letter queue review
    CREATE INDEX IF NOT EXISTS idx_work_queue_dead_letter
      ON messaging_work_queue(status, completed_at DESC)
      WHERE status = 'dead_letter';

    -- Index for retry scheduling
    CREATE INDEX IF NOT EXISTS idx_work_queue_retry
      ON messaging_work_queue(status, next_run_at)
      WHERE status IN ('pending', 'failed');
  """

  /// SQL DDL for job leases (exclusive execution grant)
  public static let jobLeaseTableDDL: String = """
    CREATE TABLE IF NOT EXISTS messaging_job_leases (
      lease_id UUID PRIMARY KEY,
      job_id UUID NOT NULL REFERENCES messaging_work_queue(job_id) ON DELETE CASCADE,
      worker_id TEXT NOT NULL,
      granted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      expires_at TIMESTAMPTZ NOT NULL,
      attempt_number INT NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Index for expired lease discovery (background recovery task)
    CREATE INDEX IF NOT EXISTS idx_job_leases_expiry
      ON messaging_job_leases(expires_at)
      WHERE expires_at < CURRENT_TIMESTAMP;

    -- Index for job lookups
    CREATE INDEX IF NOT EXISTS idx_job_leases_job
      ON messaging_job_leases(job_id);

    -- Index for worker lookups
    CREATE INDEX IF NOT EXISTS idx_job_leases_worker
      ON messaging_job_leases(worker_id);
  """

  /// SQL DDL for coordinator leases (ephemeral locks)
  public static let coordinatorLeaseTableDDL: String = """
    CREATE TABLE IF NOT EXISTS messaging_coordinator_leases (
      lease_id UUID PRIMARY KEY,
      key TEXT NOT NULL,
      holder TEXT NOT NULL,
      granted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      expires_at TIMESTAMPTZ NOT NULL,
      refresh_count INT NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Unique constraint: only one active lease per key
    CREATE UNIQUE INDEX IF NOT EXISTS idx_coordinator_leases_key_active
      ON messaging_coordinator_leases(key)
      WHERE expires_at > CURRENT_TIMESTAMP;

    -- Index for expiry cleanup
    CREATE INDEX IF NOT EXISTS idx_coordinator_leases_expiry
      ON messaging_coordinator_leases(expires_at);

    -- Index for lease lookups
    CREATE INDEX IF NOT EXISTS idx_coordinator_leases_holder
      ON messaging_coordinator_leases(holder);
  """

  /// SQL DDL for worker presence tracking
  public static let workerPresenceTableDDL: String = """
    CREATE TABLE IF NOT EXISTS messaging_worker_presence (
      worker_id TEXT PRIMARY KEY,
      status TEXT NOT NULL DEFAULT 'alive',
      last_heartbeat TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      registered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Index for stale worker detection
    CREATE INDEX IF NOT EXISTS idx_worker_presence_heartbeat
      ON messaging_worker_presence(last_heartbeat)
      WHERE status IN ('alive', 'stale');

    -- Index for status lookups
    CREATE INDEX IF NOT EXISTS idx_worker_presence_status
      ON messaging_worker_presence(status);
  """

  /// SQL DDL for event checkpoints (replay recovery)
  public static let eventCheckpointTableDDL: String = """
    CREATE TABLE IF NOT EXISTS messaging_event_checkpoints (
      checkpoint_id UUID PRIMARY KEY,
      stream_id TEXT NOT NULL,
      position BIGINT NOT NULL,
      label TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Index for checkpoint lookups
    CREATE INDEX IF NOT EXISTS idx_event_checkpoints_stream
      ON messaging_event_checkpoints(stream_id);

    -- Index for label lookups
    CREATE INDEX IF NOT EXISTS idx_event_checkpoints_label
      ON messaging_event_checkpoints(label);
  """

  /// SQL DDL for dead-letter records (failed job archive)
  public static let deadLetterTableDDL: String = """
    CREATE TABLE IF NOT EXISTS messaging_dead_letters (
      job_id UUID PRIMARY KEY,
      moved_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      reason TEXT NOT NULL,
      attempt_count INT NOT NULL,
      last_worker_id TEXT,
      payload BYTEA,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    -- Index for review queries
    CREATE INDEX IF NOT EXISTS idx_dead_letters_moved
      ON messaging_dead_letters(moved_at DESC);

    -- Index for reason searches
    CREATE INDEX IF NOT EXISTS idx_dead_letters_reason
      ON messaging_dead_letters(reason);
  """

  /// Compile all DDL statements
  public static let allMigrations: [String] = [
    eventLogTableDDL,
    workQueueTableDDL,
    jobLeaseTableDDL,
    coordinatorLeaseTableDDL,
    workerPresenceTableDDL,
    eventCheckpointTableDDL,
    deadLetterTableDDL
  ]

  /// Run all migrations on the given database connection
  /// - Parameter connection: PostgreSQL connection
  /// - Throws: Database errors
  public static func runMigrations(using connection: PostgresConnection) async throws {
    for migration in allMigrations {
      try await connection.query(migration)
    }
  }
}

/// PostgreSQL connection wrapper for Swift 6 with parameterized queries
public protocol PostgresConnection: Sendable {
  /// Execute a raw SQL query without parameters or return values
  func query(_ sql: String) async throws

  /// Query a single row with parameters, decoding into a specific type
  /// - Parameters:
  ///   - sql: The SQL query with parameter placeholders ($1, $2, etc.)
  ///   - parameters: Array of Sendable parameter values
  ///   - decoding: The type to decode the result into
  /// - Returns: A single decoded value or nil if no rows
  func queryOne<T: Decodable & Sendable>(_ sql: String, _ parameters: [any Sendable], decoding: T.Type) async throws -> T?

  /// Query multiple rows with parameters, decoding into an array of a specific type
  /// - Parameters:
  ///   - sql: The SQL query with parameter placeholders ($1, $2, etc.)
  ///   - parameters: Array of Sendable parameter values
  ///   - decoding: The type to decode each row into
  /// - Returns: Array of decoded values
  func queryAll<T: Decodable & Sendable>(_ sql: String, _ parameters: [any Sendable], decoding: T.Type) async throws -> [T]

  /// Execute a write operation (INSERT, UPDATE, DELETE) with parameters
  /// - Parameters:
  ///   - sql: The SQL statement
  ///   - parameters: Array of Sendable parameter values for placeholders
  func execute(_ sql: String, parameters: [any Sendable]) async throws
}
