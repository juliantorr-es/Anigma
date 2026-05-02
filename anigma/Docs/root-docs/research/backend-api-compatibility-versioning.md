> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research: Backend API Compatibility and Versioning Patterns

**Status**: Research Phase Complete  
**Task**: td-662ed2  
**Author**: Harmonia Research Team  
**Last Updated**: 2026-04-14

## Executive Summary

Harmonia V3 backend APIs must evolve while maintaining compatibility with:
1. **Multiple clients**: CLI, web UI, mobile, third-party integrations
2. **Multiple versions**: Old clients can't upgrade immediately
3. **Multiple deployments**: Some deployments lag behind on upgrades

This research evaluates:
- **Versioning strategies**: URL versioning, header versioning, content negotiation
- **Compatibility approaches**: Strict vs loose, deprecation strategies
- **Evolution patterns**: When and how to make breaking changes
- **Lifecycle management**: Alpha/Beta/GA/Deprecated/Sunset
- **Client coordination**: Communicating changes, forcing upgrades

### Key Findings

| Strategy | Compatibility | Client Burden | Operational Load |
|----------|---------------|---------------|-------------------|
| URL versioning (/v1, /v2) | High | High (manage 2+ versions) | High (duplicate code) |
| Header versioning | High | Low | Medium |
| **Recommended (hybrid)** | **High** | **Low** | **Medium** |
| No versioning | Low | Very High | Low |
| Strict versioning | Very High | Very High | Very High |

### Recommendations

**For Harmonia V3**:
1. **Primary strategy**: Hybrid versioning (URL for major breaks, headers for evolution)
2. **Compatibility**: Maintain 2 major versions (current + 1 previous)
3. **Deprecation**: 1-year warning before removal
4. **Implementation timeline**: 3-4 weeks for framework, then ongoing

---

## 1. Versioning Strategies

### 1.1 URL Path Versioning

**Mechanism**: Version in URL path (/v1/query, /v2/query)

```swift
router.post("/api/v1/query") { request in
    // Old API
    return queryV1(request)
}

router.post("/api/v2/query") { request in
    // New API with breaking changes
    return queryV2(request)
}
```

**Characteristics**:
- ✅ Very clear versioning
- ✅ Separate codepaths (easier to maintain)
- ❌ Code duplication
- ❌ Client must know about versions
- ❌ Operational overhead (2+ versions to maintain)

**When to use**: Major breaking changes (v1 → v2, v2 → v3)

### 1.2 Header-Based Versioning

**Mechanism**: Version specified in Accept header

```swift
// Client specifies version in header
GET /api/query
Accept: application/vnd.harmonia+json;version=2

// Server routes based on header
func handleQuery(request: Request) {
    let version = parseVersion(request.headers["accept"])
    
    switch version {
    case .v1:
        return queryV1(request)
    case .v2:
        return queryV2(request)
    }
}
```

**Characteristics**:
- ✅ Single URL
- ✅ Clients can upgrade independently
- ✅ Less coupling to URL structure
- ⚠️ Version in header (not discoverable)
- ⚠️ Need versioning logic in every endpoint

**When to use**: Minor evolutions, gradual upgrades

### 1.3 Recommended: Hybrid Approach

**Mechanism**: Combine URL (major breaks) + headers (evolution)

```
/api/v2/query                          # Major version in URL
Accept: application/vnd.harmonia+json;version=2.1  # Minor in header

Or:

/api/query?api-version=2.1            # Both in URL/query
X-API-Version: 2.1                    # Or in header
```

**Benefits**:
- ✅ Clear major versions (/v1, /v2)
- ✅ Smooth minor evolution (within v2)
- ✅ Clients can evolve independently
- ✅ Operational: Maintain 2 major versions, not 5

---

## 2. API Lifecycle

### 2.1 API Maturity Levels

```
Development (internal only):
├─ No SLO
├─ Breaking changes without warning
├─ No backwards compatibility guarantee
└─ Example: /api/v3-experimental/...

Alpha (early adopters):
├─ Preliminary SLO (90