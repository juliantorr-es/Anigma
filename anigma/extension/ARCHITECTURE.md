# Anigma MCP Extension Architecture

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                     User's Machine (Local)                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │        Claude Desktop Application                      │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  Claude (LLM)                                │     │    │
│  │  │  - Reads documentation                       │     │    │
│  │  │  - Makes tool calls                          │     │    │
│  │  │  - Generates responses                       │     │    │
│  │  └──────────────────────────────────────────────┘     │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  MCP Runtime                                 │     │    │
│  │  │  - JSON-RPC 2.0 protocol                    │     │    │
│  │  │  - Tool discovery                            │     │    │
│  │  │  - Request/response handling                 │     │    │
│  │  └──────────────────────────────────────────────┘     │    │
│  └────────────────────┬─────────────────────────────────┘    │
│                       │ JSON-RPC                              │
│                       ▼                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │        anigma-mcp Server Process                       │  │
│  │        (Binary: /usr/local/bin/anigma-mcp)             │  │
│  │                                                        │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  MCP Server (JSON-RPC Handler)             │       │  │
│  │  │  - Listen for tool calls                   │       │  │
│  │  │  - Route to handlers                       │       │  │
│  │  │  - Return results                          │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Request Queue (MCPRequestQueue)           │       │  │
│  │  │  - Enqueue requests with priority          │       │  │
│  │  │  - Check per-client quotas (5 concurrent)  │       │  │
│  │  │  - Enforce rate limits (120/min per client)│       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Adaptive Throttle (MCPAdaptiveThrottle)   │       │  │
│  │  │  - Green zone (<70%): Accept all           │       │  │
│  │  │  - Yellow (70-85%): Warn + jitter          │       │  │
│  │  │  - Red (85-95%): Reject low-priority       │       │  │
│  │  │  - Black (>95%): Reject all but critical   │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Timeout Enforcement (MCPTimeouts)         │       │  │
│  │  │  - 2s for fast reads                       │       │  │
│  │  │  - 5s for searches                         │       │  │
│  │  │  - 30s for heavy compute                   │       │  │
│  │  │  - Cancels tasks if limit exceeded         │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Tool Handlers (16 tools)                  │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ Fast Reads (Auto-cached)             │ │       │  │
│  │  │  │ - read_file                          │ │       │  │
│  │  │  │ - list_artifacts, list_models        │ │       │  │
│  │  │  │ - get_system_health                  │ │       │  │
│  │  │  │ - list_active_alerts                 │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ Search & Query (Cached)              │ │       │  │
│  │  │  │ - context_search (5min TTL)          │ │       │  │
│  │  │  │ - database_query (5min TTL)          │ │       │  │
│  │  │  │ - trace_query                        │ │       │  │
│  │  │  │ - git_diff                           │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ Heavy Compute (Not cached)           │ │       │  │
│  │  │  │ - swift_build (30s timeout)          │ │       │  │
│  │  │  │ - swift_test (30s timeout)           │ │       │  │
│  │  │  │ - digest_codebase (async background) │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ Mutations (Need approval)            │ │       │  │
│  │  │  │ - apply_patch                        │ │       │  │
│  │  │  │ - create_tool_contract               │ │       │  │
│  │  │  │ - context_purge                      │ │       │  │
│  │  │  │ - verify_evidence_chain              │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Caching Layer (MCPCaches)                │       │  │
│  │  │  - File Cache (LRU 10MB, read_file)       │       │  │
│  │  │  - Query Cache (5min TTL, searches)       │       │  │
│  │  │  - Metadata Cache (30min TTL, lists)      │       │  │
│  │  │  - Hit Rate: >70% for repeated ops       │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Metrics Collection (MCPMetrics)          │       │  │
│  │  │  - Per-tool call counts                   │       │  │
│  │  │  - Latency percentiles (p50/p95/p99)      │       │  │
│  │  │  - Cache hit rates                        │       │  │
│  │  │  - Error tracking                         │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Platform Runtime (Tier 2)                │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ ExecutionAuthority                   │ │       │  │
│  │  │  │ - Governs all workflow execution     │ │       │  │
│  │  │  │ - Enforces KillSwitch & WriteGate    │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ EvidenceAuthority                    │ │       │  │
│  │  │  │ - Records all operations (tamper-    │ │       │  │
│  │  │  │   evident BLAKE3 hashing)            │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ DatabaseAuthority                    │ │       │  │
│  │  │  │ - Governed database access           │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ ArtifactAuthority                    │ │       │  │
│  │  │  │ - Managed artifact storage           │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Governance Controller (Tier 1)           │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ KillSwitch                           │ │       │  │
│  │  │  │ - Emergency halt for writes          │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ WriteGate                            │ │       │  │
│  │  │  │ - Quality checks before mutations    │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ ABAC (Attribute-Based Access)        │ │       │  │
│  │  │  │ - Role/attribute-based control       │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  └────────────────┬─────────────────────────┘       │  │
│  │                   ▼                                   │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Capability Modules (Tier 3)              │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ HarmoniaModule                       │ │       │  │
│  │  │  │ - AI coding assistant with kernel    │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ ContextumModule                      │ │       │  │
│  │  │  │ - Semantic search & context mgmt     │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ ArtifactStoreModule                  │ │       │  │
│  │  │  │ - Build artifact management          │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ ModelRegistryModule                  │ │       │  │
│  │  │  │ - ML model lifecycle management      │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ ObservatoriumModule                  │ │       │  │
│  │  │  │ - System health monitoring           │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  │  ┌──────────────────────────────────────┐ │       │  │
│  │  │  │ CathedralModule                      │ │       │  │
│  │  │  │ - Evidence & audit logging           │ │       │  │
│  │  │  └──────────────────────────────────────┘ │       │  │
│  │  └─────────────────────────────────────────────      │  │
│  │                                                        │  │
│  │  ┌────────────────────────────────────────────┐       │  │
│  │  │  Local Resources                          │       │  │
│  │  │  - SQLite database                        │       │  │
│  │  │  - Anigma repository files                │       │  │
│  │  │  - System utilities (git, swift, etc)     │       │  │
│  │  │  - ML models (local)                      │       │  │
│  │  └────────────────────────────────────────────┘       │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘

ZERO NETWORK TRAFFIC - Everything stays on user's machine
```

## Request Lifecycle

```
User asks Claude:
  "What files need refactoring?"

              │
              ▼
Claude calls MCP tool:
  context_search(query="refactoring metrics")

              │
              ▼
Claude Desktop MCP Handler:
  1. Parse JSON-RPC request
  2. Identify tool: context_search
  3. Extract parameters: query="refactoring metrics"

              │
              ▼
anigma-mcp Server:
  1. Create MCPRequestContext
     - UUID, timestamp, clientId
     - Priority: normal (search)
     - Deadline: now + 5s timeout

              │
              ▼
  2. MCPRequestQueue.enqueueRequest()
     - Check client quota (5 concurrent, 120/min)
     - Evaluate adaptive throttle
     - If overloaded: return 429 with retry hint
     - Else: Add to priority queue

              │
              ▼
  3. dequeueNextRequest()
     - Pop highest priority request
     - (May be batched with other requests)

              │
              ▼
  4. Timeout Enforcement (MCPTimeouts)
     - Start 5s timeout countdown
     - Prepare cancellation task

              │
              ▼
  5. Tool Handler Execution
     - Check cache first (MCPCaches)
     - Cache HIT (5ms):
       ├─ Return cached results
       ├─ Record cache hit in metrics
       └─ Done!

     OR

     - Cache MISS (200ms):
       ├─ Call ContextumModule.search()
       ├─ Wait for results (timeout guards)
       ├─ Store in cache (5min TTL)
       ├─ Record latency in MCPMetrics
       └─ Return to Claude

              │
              ▼
  6. Metrics Recording (MCPMetrics)
     - Record call count
     - Record latency (p50/p95/p99)
     - Update cache hit/miss rates
     - Track errors if any

              │
              ▼
  7. Error Tracking (ErrorTracker)
     - If error: add to recent errors list
     - Limit to last 10 errors
     - Available via get_system_health

              │
              ▼
  8. Response to Claude
     - JSON-RPC result
     - Include request ID for debugging
     - Include latency info

              │
              ▼
Claude processes results:
  - Analyzes search results
  - Generates response with citations
  - Presents to user
```

## Scaling Under Load

```
Normal Load (Green Zone: <70%):
┌─────────────────────────────────────┐
│ Queue Depth: 2                      │
│ Load: 40%                           │
│ Response: ACCEPT (instant)          │
│ Latency: ~50ms                      │
│ Status: ✓ Green - All good          │
└─────────────────────────────────────┘


Moderate Load (Yellow Zone: 70-85%):
┌─────────────────────────────────────┐
│ Queue Depth: 10                     │
│ Load: 75%                           │
│ Response: ACCEPT with jitter        │
│ Latency: ~100ms (+ 10-50ms jitter)  │
│ Status: ⚠ Yellow - Watch it         │
└─────────────────────────────────────┘


High Load (Red Zone: 85-95%):
┌─────────────────────────────────────┐
│ Queue Depth: 35                     │
│ Load: 90%                           │
│ Response:                           │
│   - Critical: ACCEPT                │
│   - High: ACCEPT (50-500ms backoff) │
│   - Normal: REJECT (retry later)    │
│   - Low: REJECT (hard)              │
│ Status: 🔴 Red - Degraded mode      │
└─────────────────────────────────────┘


Extreme Load (Black Zone: >95%):
┌─────────────────────────────────────┐
│ Queue Depth: 50 (max)               │
│ Load: 98%                           │
│ Response:                           │
│   - Critical (health): ACCEPT       │
│   - All else: REJECT                │
│   - Backoff: 500-2000ms             │
│ Status: ⚫ Black - Emergency mode    │
└─────────────────────────────────────┘
```

## Performance Stack

```
┌─────────────────────────────────────────────────────────┐
│                   Application Layer                    │
│          Claude Desktop + MCP Protocol                 │
├─────────────────────────────────────────────────────────┤
│                   Request Handling                     │
│        Queue → Throttle → Timeout → Handler            │
├─────────────────────────────────────────────────────────┤
│                  Caching Layer                        │
│  LRU (files) + TTL (queries) + TTL (metadata)         │
│  Hit Rate: >70% → 10-40x faster                       │
├─────────────────────────────────────────────────────────┤
│                Execution Layer                         │
│  Capability Modules (with governance checks)          │
├─────────────────────────────────────────────────────────┤
│              Platform Runtime (Tier 2)                │
│  Execution, Evidence, Database, Artifact Authorities  │
├─────────────────────────────────────────────────────────┤
│           Governance Controller (Tier 1)              │
│  KillSwitch, WriteGate, ABAC, Lifecycle               │
├─────────────────────────────────────────────────────────┤
│              Local Resources                          │
│  Database, Files, System utilities, ML models         │
└─────────────────────────────────────────────────────────┘

Performance characteristics by layer:

Request Handling:      <1ms   (queue enqueue/dequeue)
Caching Hit:           5-10ms (return from cache)
Fast Tool (read):      50ms   (read + parse)
Search (cold):         200ms  (full search)
Search (cached):       5ms    (cache hit)
Heavy Compute:         10-30s (builds, tests)
```

## Security Model

```
┌─────────────────────────────────────────────────────────┐
│           Sandboxed Execution (Claude Desktop)          │
│  - MCP runs as isolated subprocess                     │
│  - No network access                                    │
│  - No system access (sandboxed)                        │
│  - No access to other apps' data                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Tool-Level Permissions                       │
│  - Read tools: Auto-approved (safe)                    │
│  - Search tools: Auto-approved (read-only)             │
│  - Build tools: Ask for approval                       │
│  - Mutation tools: Require explicit user approval      │
│  - Evidence tools: Auto-approved (read-only)           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Governance Controller (Tier 1)               │
│  - KillSwitch: Emergency halt for all writes           │
│  - WriteGate: Pre-flight checks                        │
│  - ABAC: Attribute-based access control                │
│  - Lifecycle: Data retention policies                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Execution Authority (Tier 2)                │
│  - Checks governance before any operation              │
│  - Records evidence (tamper-evident)                   │
│  - Enforces deadlines                                  │
│  - Handles errors gracefully                           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Capability Modules (Tier 3)                 │
│  - Cannot bypass governance                           │
│  - Cannot create World instances                       │
│  - Cannot access database directly                     │
│  - Cannot write evidence directly                      │
│  - Must go through ExecutionAuthority                  │
└─────────────────────────────────────────────────────────┘
```

## Deployment Architecture

```
Developer Machine:
┌─────────────────────────────────────────┐
│  Source Code (GitHub)                   │
│  ├─ Sources/                            │
│  ├─ Packages/                           │
│  ├─ Tests/                              │
│  └─ Scripts/                            │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  Build: swift build -c release          │
│  Output: .build/release/anigma-mcp      │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  Package: bash Scripts/package_extension │
│  ├─ Binary + manifest.json               │
│  ├─ Icons (4 sizes)                      │
│  └─ Documentation                        │
│  Output: anigma-mcp.mcpb                 │
└────────────┬────────────────────────────┘
             │
             ▼
Distribution Options:
├─ GitHub Releases (recommended)
├─ Personal website
├─ Claude registry (coming soon)
└─ Package managers (future)

User Installation:
┌─────────────────────────────────────────┐
│  1. Download anigma-mcp.mcpb             │
│  2. Double-click                         │
│  3. Claude Desktop extracts              │
│  4. Configuration UI renders             │
│  5. Restart Claude                       │
│  6. Ready to use!                        │
└─────────────────────────────────────────┘
```

---

This architecture enables:
- **Scalability**: Handle 10+ concurrent instances
- **Performance**: Sub-100ms latency for cached ops
- **Reliability**: Adaptive degradation under load
- **Security**: Full governance integration
- **Usability**: One-click installation
- **Observability**: Complete metrics and health checks

All local, all governed, all auditable. ✨
