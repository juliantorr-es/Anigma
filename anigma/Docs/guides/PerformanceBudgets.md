# Performance Budgets

## Overview
This document defines the performance contracts for Anigma operations. These budgets are **hard limits** enforced by the CI pipeline and monitored in production.

## Latency Budgets (P95)

### Ingest Operations
| Operation | Target (ms) | Critical Path | Notes |
|-----------|-------------|---------------|-------|
| `pdfImport` (per page) | 200 | Yes | Includes OCR, text extraction, indexing |
| `web-capture` | 500 | Yes | HTML parsing, semantic extraction |
| `source_ingest` (discovery) | 1000 | No | File enumeration only |
| `source_ingest` (indexing) | 5000 | No | Full text extraction |

### Compute Operations
| Operation | Target (ms) | Critical Path | Notes |
|-----------|-------------|---------------|-------|
| `ocr` (per image) | 300 | Yes | Vision framework on-device |
| `translate` (per 1000 chars) | 500 | No | Local model preferred |
| `summarize` (per artifact) | 1000 | No | Depends on artifact size |
| `extract_deadlines` | 800 | Yes | Temporal entity extraction |

### Analysis Operations
| Operation | Target (ms) | Critical Path | Notes |
|-----------|-------------|---------------|-------|
| `verify_claims` | 1500 | No | Evidence ledger search |
| `generate_response` | 2000 | No | Research synthesis |
| `baseline_analysis` | 3000 | No | Full artifact scan |

### UI Interactions
| Operation | Target (ms) | Critical Path | Notes |
|-----------|-------------|---------------|-------|
| Surface render | 16 | Yes | 60fps target |
| Toast display | 100 | Yes | User feedback |
| Search (local) | 200 | Yes | Atlas/Inbox search |
| Job submission | 50 | Yes | Optimistic receipt |

## Memory Budgets

### Per-Operation Limits
- **PDF Import**: 100 MB per page (temporary)
- **OCR**: 50 MB per image
- **Web Capture**: 20 MB per page
- **Embeddings**: 10 MB per 1000 tokens

### Global Limits
- **Total App Memory**: 500 MB baseline, 2 GB peak
- **Cache Size**: 1 GB max (LRU eviction)
- **Artifact Storage**: User-configurable, default 10 GB

## Throughput Budgets

### Concurrent Operations
- **Max Parallel Jobs**: 4 (configurable via `GovernanceSettings`)
- **Max PDF Pages/sec**: 5 (sustained)
- **Max Web Captures/min**: 10

### Batch Processing
- **Source Ingest**: 1000 files/min (discovery mode)
- **Bulk OCR**: 100 images/min

## Enforcement

### CI Gates
```bash
# Run performance benchmarks
Scripts/ci/check-performance-budgets.sh

# Fails if any operation exceeds budget by >10%
```

### Runtime Monitoring
- All `OperationResult` instances track `startTime` and `endTime`
- Violations logged to `PerformanceViolations.jsonl`
- Dashboard shows P50/P95/P99 latencies per operation kind

### Budget Violations
**Severity Levels:**
- **Critical**: >50% over budget → Block merge
- **Warning**: 10-50% over budget → Require justification
- **Info**: <10% over budget → Log only

## Optimization Strategies

### Quick Wins
1. **Lazy Loading**: Defer non-critical work
2. **Caching**: Memoize expensive computations
3. **Streaming**: Use `AsyncStream` for incremental results
4. **Concurrency**: Parallelize independent operations

### Long-term
1. **Native Extensions**: Rewrite hot paths in C/C++
2. **GPU Acceleration**: Use Metal for vision tasks
3. **Incremental Processing**: Process deltas, not full artifacts
4. **Background Scheduling**: Use `DispatchQueue.global(qos: .utility)`

## Review Cadence

- **Weekly**: Review P95 latencies for all operations
- **Monthly**: Adjust budgets based on user feedback
- **Quarterly**: Major optimization campaigns

---

*Last updated: 2026-01-07*
