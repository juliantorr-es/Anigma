> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Launcher Integration Quick Reference

**For:** Harmonia V3 Design Task td-8e2d3f  
**Document:** launcher-integration-patterns.md  
**Last Updated:** April 2026

---

## TL;DR - Key Findings

### Recommended Architecture
✅ **Adapter Pattern** + **Event Broker** + **Eventual Consistency**

- Use standardized `LauncherAdapter` protocol
- Normalize all events to internal format immediately
- Hybrid webhook (primary) + polling (fallback)
- State reconciliation every 5 minutes

### Platform Selection
| Launcher | Best For | Effort | Cost |
|----------|----------|--------|------|
| **GitHub Actions** | Start here (Phase 1) | 6-8w | $20/10k |
| **GitLab CI** | Enterprise git/CD | 4-6w | $10/10k |
| **Jenkins** | Legacy systems | 6-8w | $0-2k infra |
| **Argo/K8s** | Cloud-native | 6-8w | $50-200/mo |
| **AWS Step Fn** | Managed/scale | 6-8w | $167/10k |

### Implementation Timeline
- **Phase 1:** GitHub Actions only → 6-8 weeks
- **Phase 2:** Add GitLab + Jenkins → +4-6 weeks
- **Phase 3:** Add Argo/Kubernetes → +6-8 weeks
- **Phase 4:** AWS + multi-region failover → +6-8 weeks

**Total:** 22-30 weeks, $66-90k engineering, $300-1300/mo infrastructure

---

## Architecture Overview

```
Harmonia V3 Orchestrator
         ↓
[Launcher Registry] ← [Load Balancer]
         ↓
[Adapter Pattern] ← GitHub | GitLab | Jenkins | Argo | AWS
         ↓
[Event Ingestion] ← Webhooks + Polling + Reconciliation
         ↓
[Event Broker] ← Deduplication + Ordering + Backpressure
         ↓
[State Store] ← GRDB + Replication
         ↓
[Observability] ← OpenTelemetry + Metrics + Alerts
```

---

## Critical Design Decisions

### 1. Event Delivery Strategy
**Use HYBRID approach:**
- 🟢 **Webhooks** (primary): Real-time, <500ms latency
- 🟡 **Polling** (fallback): Every 10-30s per launcher
- 🔵 **Reconciliation** (safety): Every 5 minutes

**Why?** GitHub webhooks fail ~50f the time; polling catches misses; reconciliation prevents divergence.

### 2. State Model
**Use EVENTUAL CONSISTENCY:**
- Webhooks arrive out-of-order
- Multiple sources of truth (launcher + local DB)
- Reconciliation corrects divergence asynchronously

**Alternative rejected:** Strict consistency → expensive, requires distributed consensus

### 3. Failure Handling
**Use DEAD LETTER QUEUE:**
- Retry failed events 3x with exponential backoff
- Store permanently for manual investigation
- Alert ops after 3 retries

### 4. Multi-Launcher Selection
**Use REGISTRY + LOAD BALANCER:**
- Query capabilities matrix
- Select based on requirements + current load
- Fallback to 2nd choice if primary degraded

### 5. Credential Management
**Use SECRET ROTATION:**
- 30-day rotation policy
- Automated via SecretManager
- Zero-downtime rotation

---

## Platform Comparison Summary

### Event Granularity
- **GitHub Actions:** Workflow → Job → Step (3 levels)
- **GitLab CI:** Pipeline → Stage → Job (3 levels)
- **Jenkins:** Build only (1 level)
- **Argo:** Workflow → Node (2 levels)
- **AWS Step Fn:** Execution → Step result (2 levels)

### Failure Recovery
- **GitHub Actions:** Manual (rerun)
- **GitLab CI:** Retry policy + manual
- **Jenkins:** Build rebuild
- **Argo:** Pod restart + retry policy
- **AWS Step Fn:** Built-in retry/catch states ⭐

### Cost at 10k Tasks/Month
- **GitHub Actions:** ~$20
- **GitLab CI:** ~$10
- **Jenkins:** $0-2k (infrastructure)
- **Argo:** $50-200 (K8s cluster)
- **AWS Step Fn:** ~$167 ⭐ (cheapest at scale)

### Webhook Reliability
- **GitHub Actions:** 30-day retry window (~95