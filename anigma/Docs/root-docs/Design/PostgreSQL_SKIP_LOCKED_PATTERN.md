# PostgreSQL SKIP LOCKED Pattern for Job Queue Concurrency

## Overview

This document describes how to implement the PostgreSQL `SKIP LOCKED` pattern for efficient job queue processing in Anigma's job management system. This pattern eliminates the need for external message queues (Redis, RabbitMQ) by leveraging PostgreSQL's native concurrency control.

## Problem Statement

In traditional job queue implementations, multiple workers may attempt to acquire the same job simultaneously, leading to:

1. **Lock Contention**: Workers block waiting for locks
2. **Deadlocks**: Circular wait conditions
3. **Inefficient Polling**: Workers repeatedly check for available jobs
4. **Complex Error Handling**: Need to handle lock timeouts and retries

## Solution: SKIP LOCKED

PostgreSQL's `SKIP LOCKED` clause changes the physics of row locking:

```sql
-- Traditional approach (blocks on locked rows)
SELECT * FROM jobs 
WHERE status = 'pending'
ORDER BY created_at 
LIMIT 1 
FOR UPDATE;

-- SKIP LOCKED approach (skips locked rows immediately)
SELECT * FROM jobs 
WHERE status = 'pending'
ORDER BY created_at 
LIMIT 1 
FOR UPDATE SKIP LOCKED;
```

### How It Works

1. **Immediate Acquisition**: Worker acquires the first available unlocked row
2. **No Waiting**: If a row is locked, skip it and try the next one
3. **Atomic Operation**: The entire operation is atomic within a transaction
4. **No Blocking**: Workers never block waiting for locks

## Implementation in Anigma

### Current Contextum Jobs Table

```sql
CREATE TABLE IF NOT EXISTS contextum_jobs (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    status TEXT NOT NULL,  -- 'pending', 'running', 'completed', 'failed'
    payload TEXT NOT NULL,
    correlation_id TEXT,
    created_at INTEGER NOT NULL,
    started_at INTEGER,
    completed_at INTEGER
);
```

### Recommended Schema Enhancements

```sql
-- Add priority support
ALTER TABLE contextum_jobs ADD COLUMN priority INTEGER NOT NULL DEFAULT 0;

-- Add retry count
ALTER TABLE contextum_jobs ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0;

-- Add max retries
ALTER TABLE contextum_jobs ADD COLUMN max_retries INTEGER NOT NULL DEFAULT 3;

-- Add error message
ALTER TABLE contextum_jobs ADD COLUMN error_message TEXT;

-- Add indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_jobs_status_priority ON contextum_jobs(status, priority);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON contextum_jobs(created_at);
```

### Swift Implementation Pattern

```swift
// Job Worker Implementation
actor JobWorker {
    private let database: DatabaseAuthority
    private let workerId: String
    private var isRunning: Bool = false

    func start() async throws {
        isRunning = true
        
        while isRunning {
            do {
                // Get next available job using SKIP LOCKED
                let job = try await getNextJob()
                
                if let job = job {
                    try await processJob(job)
                } else {
                    // No jobs available, wait briefly
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            } catch {
                // Log error and continue
                Logger.error("Worker error: \(error)")
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }

    private func getNextJob() async throws -> Job? {
        let sql = """
            SELECT * FROM contextum_jobs 
            WHERE status = 'pending'
            ORDER BY priority DESC, created_at ASC
            LIMIT 1
            FOR UPDATE SKIP LOCKED
        """
        
        return try await database.executeQuery(sql) { row in
            // Map row to Job object
            Job(
                id: row["id"] as! String,
                kind: row["kind"] as! String,
                status: row["status"] as! String,
                payload: row["payload"] as! String,
                correlationId: row["correlation_id"] as? String,
                createdAt: Date(timeIntervalSince1970: TimeInterval(row["created_at"] as! Int)),
                startedAt: row["started_at"] as? Int != nil ? Date(timeIntervalSince1970: TimeInterval(row["started_at"] as! Int)) : nil,
                completedAt: row["completed_at"] as? Int != nil ? Date(timeIntervalSince1970: TimeInterval(row["completed_at"] as! Int)) : nil,
                priority: row["priority"] as? Int ?? 0,
                retryCount: row["retry_count"] as? Int ?? 0,
                maxRetries: row["max_retries"] as? Int ?? 3
            )
        }
    }

    private func processJob(_ job: Job) async throws {
        // Update job status to running
        let updateSql = """
            UPDATE contextum_jobs 
            SET status = 'running', 
                started_at = ?,
                retry_count = retry_count + 1
            WHERE id = ?
        """
        
        try await database.execute(updateSql, parameters: [
            Int(Date().timeIntervalSince1970),
            job.id
        ])
        
        // Process the job
        do {
            let result = try await executeJob(job)
            
            // Mark as completed
            let completeSql = """
                UPDATE contextum_jobs 
                SET status = 'completed', 
                    completed_at = ?,
                    payload = ?
                WHERE id = ?
            """
            
            try await database.execute(completeSql, parameters: [
                Int(Date().timeIntervalSince1970),
                result,
                job.id
            ])
            
        } catch {
            // Handle job failure
            if job.retryCount < job.maxRetries {
                // Release job back to pending for retry
                let retrySql = """
                    UPDATE contextum_jobs 
                    SET status = 'pending', 
                        error_message = ?
                    WHERE id = ?
                """
                
                try await database.execute(retrySql, parameters: [
                    String(describing: error),
                    job.id
                ])
            } else {
                // Mark as failed
                let failSql = """
                    UPDATE contextum_jobs 
                    SET status = 'failed', 
                        completed_at = ?,
                        error_message = ?
                    WHERE id = ?
                """
                
                try await database.execute(failSql, parameters: [
                    Int(Date().timeIntervalSince1970),
                    String(describing: error),
                    job.id
                ])
            }
        }
    }

    func stop() {
        isRunning = false
    }
}
```

## Transaction Management

### Best Practices

1. **Short Transactions**: Keep transactions as short as possible
2. **Early Release**: Release locks immediately after updating job status
3. **Error Handling**: Ensure proper rollback on errors
4. **Connection Pooling**: Use connection pooling to manage database connections

### Example Transaction Flow

```swift
try await database.inTransaction { connection in
    // 1. Acquire job (SKIP LOCKED)
    guard let job = try await getNextJob(connection: connection) else {
        return nil
    }
    
    // 2. Update job status
    try await markJobAsRunning(job: job, connection: connection)
    
    // 3. Process job (outside transaction to release lock quickly)
    // Note: This would be in a separate step after committing
    
    return job
}
```

## Performance Considerations

### Benefits

✅ **High Concurrency**: Multiple workers can process jobs simultaneously without blocking
✅ **Low Latency**: Workers immediately get available jobs or return empty
✅ **No Polling**: Eliminates inefficient polling loops
✅ **Atomic Operations**: Entire acquire/update cycle is atomic
✅ **Simple Architecture**: No external message queue required

### Potential Issues and Solutions

| Issue | Solution |
|-------|----------|
| **Starvation**: High-priority jobs monopolize workers | Implement fair scheduling with priority decay |
| **Thundering Herd**: Many workers wake up simultaneously | Add brief random delays between worker wakeups |
| **Long Transactions**: Workers hold locks too long | Keep transactions short, release locks quickly |
| **Connection Exhaustion**: Too many concurrent workers | Use connection pooling with appropriate limits |

## Monitoring and Metrics

### Key Metrics to Track

```swift
struct JobQueueMetrics {
    var jobsPending: Int = 0
    var jobsRunning: Int = 0
    var jobsCompleted: Int = 0
    var jobsFailed: Int = 0
    var workerCount: Int = 0
    var averageProcessingTime: TimeInterval = 0
    var lockWaitTime: TimeInterval = 0
    var jobsPerSecond: Double = 0
}
```

### Recommended Monitoring Queries

```sql
-- Current queue status
SELECT 
    status,
    COUNT(*) as count,
    AVG(created_at) as avg_age
FROM contextum_jobs
GROUP BY status;

-- Worker performance
SELECT 
    AVG(completed_at - started_at) as avg_processing_time,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY (completed_at - started_at)) as p95_time
FROM contextum_jobs
WHERE status = 'completed' AND started_at IS NOT NULL;

-- Retry statistics
SELECT 
    retry_count,
    COUNT(*) as count
FROM contextum_jobs
WHERE status = 'failed'
GROUP BY retry_count
ORDER BY retry_count DESC;
```

## Migration Strategy

### From In-Memory to Database-Backed Queue

1. **Dual-Write Phase**: Write jobs to both in-memory queue and database
2. **Validation Phase**: Verify both systems produce identical results
3. **Cutover**: Switch workers to use database queue exclusively
4. **Monitoring**: Closely monitor performance and error rates
5. **Decommission**: Remove in-memory queue after successful migration

### From External Queue (Redis/RabbitMQ) to PostgreSQL

1. **Queue Drain**: Allow existing queue to empty
2. **Schema Setup**: Create jobs table with proper indexes
3. **Worker Update**: Deploy workers using SKIP LOCKED pattern
4. **Traffic Switch**: Route new jobs to PostgreSQL queue
5. **Validation**: Verify no jobs are lost or duplicated
6. **Decommission**: Shut down external queue infrastructure

## Comparison with Alternatives

### Redis

| Aspect | PostgreSQL SKIP LOCKED | Redis |
|--------|----------------------|-------|
| **Complexity** | Low (single system) | Medium (separate service) |
| **Data Locality** | Excellent (same DB) | Poor (separate service) |
| **Transactions** | ACID compliant | Limited |
| **Persistence** | Durable | Configurable |
| **Operational Overhead** | Low | Medium |
| **Cost** | Included | Additional |

### RabbitMQ

| Aspect | PostgreSQL SKIP LOCKED | RabbitMQ |
|--------|----------------------|----------|
| **Throughput** | High | Very High |
| **Features** | Basic | Advanced (routing, exchanges) |
| **Complexity** | Low | High |
| **Maintenance** | Minimal | Significant |
| **Learning Curve** | Low | Steep |

## When to Use External Queue

Consider external queues only when:

1. **Extreme Scale**: Millions of jobs per second
2. **Complex Routing**: Need for advanced message routing patterns
3. **Multi-DC Replication**: Geographic distribution requirements
4. **Specialized Features**: Dead letter queues, delayed messages, etc.

For Anigma's current scale and requirements, PostgreSQL SKIP LOCKED provides optimal balance of simplicity, reliability, and performance.

## References

- [PostgreSQL SKIP LOCKED Documentation](https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE)
- [PostgreSQL Concurrency Control](https://www.postgresql.org/docs/current/mvcc.html)
- [Cybertec PostgreSQL Concurrency Guide](https://www.cybertec-postgresql.com/en/postgresql-concurrency-skip-locked/)
- [ADR-0015: PostgreSQL as Unified Architecture Foundation](../ADR/0015-postgresql-unified-stack.md)
- [Governed Persistence Design](Governed_Persistence_Design.md)

## Implementation Status

- [ ] Enhance contextum_jobs table with priority and retry fields
- [ ] Implement SKIP LOCKED pattern in job workers
- [ ] Add comprehensive monitoring and metrics
- [ ] Create migration plan from current queue system
- [ ] Performance benchmarking and tuning

## Success Metrics

1. **Throughput**: Jobs processed per second
2. **Latency**: Time from job submission to completion
3. **Reliability**: Percentage of jobs successfully processed
4. **Resource Utilization**: CPU, memory, and database connection usage
5. **Operational Simplicity**: Reduction in infrastructure complexity

---

**Status**: Design Complete  
**Last Updated**: 2026-04-16  
**Related ADR**: [ADR-0015: PostgreSQL as Unified Architecture Foundation](../ADR/0015-postgresql-unified-stack.md)