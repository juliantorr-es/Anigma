> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research: Backup/Restore/Recovery Procedures (td-22fa24)

## Executive Summary

| Strategy | RPO (Data Loss) | RTO (Recovery) | Cost | Complexity |
|----------|-----------------|--------|------|-----------|
| **Continuous Replication** | <5 min | 1-5 min | High | Medium |
| **Hourly Snapshots** | <1 hour | 10-30 min | Medium | Low |
| **Daily Full + Hourly Incremental** | 1-24 hours | 30-60 min | Low | High |
| **Point-in-Time Recovery (PITR)** | <1 min | 5-15 min | High | High |

**Recommendation for Harmonia V3**: Hybrid approach - continuous replication (RPO <5 min) + daily snapshots (geo-redundancy) + PITR for 7 days.

---

## 1. Backup Strategies for Harmonia V3

### 1.1 Continuous Replication

**How It Works:**
- Master PostgreSQL database in primary region
- Standby replicas in secondary regions (streaming replication)
- Every write automatically replicated to all standbys
- Failover: Promote standby to primary within 1-5 minutes

**RPO (Recoverable Point Objective): <5 minutes**
- Worst case: lose transactions from past 5 minutes
- Typical: lose 0-1 minutes of data

**RTO (Recovery Time Objective): 1-5 minutes**
- Automatic failover: 1-3 min
- Manual failover: 3-5 min

**Implementation for Harmonia V3:**
```sql
-- Primary: Streaming replication config
wal_level = replica
max_wal_senders = 10
wal_keep_segments = 64

-- Standby: Automatic standby
standby_mode = 'on'
primary_conninfo = 'host=primary.region1.harmonia.internal'
recovery_target_timeline = 'latest'
```

**Failover Procedure:**
```
1. Detect primary failure (health check failed for 30s)
2. Query all standbys for replication lag
3. Choose replica with lowest lag (highest data consistency)
4. Promote chosen replica: SELECT pg_promote();
5. Update DNS: harmonia-db.internal → new primary
6. Redirect all connections to new primary
7. Verify all clients connected to new primary
8. Investigate primary failure (async from failover)
```

**Cost Estimate**: $2,000-5,000/month (3x database replicas)

### 1.2 Daily Snapshots (Geo-Redundant)

**How It Works:**
- Daily full snapshot at 2:00 UTC
- Store snapshot in S3 (cross-region replicated)
- Keep 30-day retention
- Optional: hourly snapshots for backup RPO <1 hour

**RPO (if daily snapshots only): ~24 hours**
- Restore to any point in last 24 hours (if using transaction logs)
- Restore to "last snapshot" (if snapshot-only)

**RTO (if hourly snapshots): 10-30 minutes**
- Restore PostgreSQL from snapshot: 5-10 min
- Verify data integrity: 2-5 min
- Run migration scripts (if schema changed): 5-10 min

**Implementation:**
```bash
# Daily snapshot script
#!/bin/bash
DATE=$(date +