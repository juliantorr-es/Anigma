> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Event Sourcing Snapshots: Quick Reference for Harmonia V3

## TL;DR Recommendation

| Aspect | Recommendation | Rationale |
|--------|-----------------|-----------|
| **Serialization** | MessagePack + Zstd | 83maller than JSON, 50 0.000000aster, debuggable |
| **Storage** | Hybrid (PostgreSQL + S3) | Hot: fast (5ms), Cold: cheap ($0.01/month), Best of both |
| **Triggers** | Hybrid (5K events OR 2 hours) | Adapts to workload variance |
| **Validation** | 3-layer (checksum + version + content) | Prevents corruption and schema misalignment |
| **Annual Cost** | ~$280 (100 aggregates) | 85heaper than database-only approach |

---

## Decision Matrix

### When to Snapshot
**Use hybrid trigger:**
```
IF events_since_snapshot >= 5_000 OR time_since_snapshot >= 2_hours:
    create_snapshot()
```

### Where to Store
```
IF created < 7 days ago:
    store in PostgreSQL        # Hot (5ms P50 latency)
ELSE:
    store in S3               # Cold (100ms P50, $0.01/month)
```

### How to Format
```
WorkspaceSnapshot 
  → MessagePack encoder (576 MB from 1 GB)
  → Zstd compression (-10) (102 MB final)
  → SHA256 checksum
  → PG/S3 storage
```

---

## Performance Guarantees

| Scenario | Latency | Cost | Reliability |
|----------|---------|------|-------------|
| Hot snapshot (< 7d) | 2-5ms P50 | $0.15/month | 99.95