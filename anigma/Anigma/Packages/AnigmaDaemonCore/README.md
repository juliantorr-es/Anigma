# AnigmaDaemonCore

**Purpose:** Swift package providing daemon core types and interfaces for the Anigma system daemon (`anigmad`) with modern concurrency support and extensibility points for AI service integration.

## Invariants

- **Sendable Compliance:** All shared data structures across actor boundaries must conform to `Sendable` for Swift 6 strict concurrency
- **Single-User Environment:** Daemon designed for single-user macOS systems with localhost-only network binding (no remote access)
- **Configuration Persistence:** All configuration changes must be persisted to disk and trigger daemon restart if running
- **Resource Quotas:** Log rotation enforces size and file count limits; configuration prevents unbounded disk growth

## Entry Points

- **DaemonServer (Actor):** HTTP server implementing RESTful API endpoints for job submission, status queries, and metrics collection; listens on configurable port (default 8080)
- **SystemMonitor (Actor):** Real-time resource monitoring delivering CPU usage, memory consumption, disk I/O metrics, and network connection tracking via low-level macOS APIs (mach/kern)
- **Logger (Actor):** Multi-level logging system (`debug`, `info`, `warning`, `error`) with automatic log rotation based on size/count thresholds and persistent storage in Application Support
- **AIServiceManager (Actor):** Framework for registering and health-checking AI services; runs 30-second periodic health checks and tracks service availability status

## Governance & Critical Invariants Enforced

### Concurrency & Data Isolation
- All mutable state isolated within actors; cross-actor communication via async/await
- Sendable requirement prevents data races and enforces type-safe concurrency
- Actor isolation guards prevent direct field access from external contexts

### Resource Management
- **Log Rotation:** Enforced rotation when log files exceed `maxLogSizeMB`; old logs archived with timestamp suffix; only `maxLogFiles` retained
- **Configuration Validation:** Port numbers must be valid (1-65535); log levels restricted to enum cases
- **Metrics Collection:** Updates run every 2 seconds via controlled Task lifecycle; cancellation propagates on daemon shutdown

### API Contract
- HTTP endpoints accept specific methods (GET/POST) with validation; invalid requests return 400/405 status codes
- Job submission requires valid `DaemonJobRequest` structure; all responses include JSON Content-Type header
- Status endpoints distinguish between daemon health status and SidecarBridge compatibility format

### Session & Service Management
- Session tokens generated via capability mechanism (UUID-based, base64-encoded)
- AI services must implement `AIService` protocol; health checks run independently for each registered service
- Job registry maintains in-memory queue; jobs inserted at position 0 (FIFO with most-recent-first display)

## Build & Test

### Build
```bash
swift build --target AnigmaDaemonCore
```

### Test
```bash
# Build complete daemon application
swift build --target anigmad

# Run daemon server
./.build/debug/anigmad

# Verify HTTP endpoints
curl http://localhost:8080/status
curl http://localhost:8080/health
curl http://localhost:8080/metrics
curl -X POST http://localhost:8080/jobs -H "Content-Type: application/json" \
  -d '{"action":"agent_refactor","repoPath":"/tmp/repo","filePath":"/tmp/file.swift","instruction":"refactor"}'

# Check configuration and logs
cat ~/Library/Application\ Support/AnigmaDaemon/config.json
tail -f ~/Library/Application\ Support/AnigmaDaemon/anigmad.log
```

## Key Dependencies

### Standard Library
- `Foundation` – URL handling, FileManager, networking, JSON coding
- `SwiftUI` – Menu bar UI, state management (@StateObject, @Published, @MainActor)
- `System` – System-level APIs
- `Darwin` – Low-level macOS APIs (mach_task_self_, host_statistics, socket operations, fsstat)
- `UserNotifications` – System notifications (macOS 14.0+)

### Core Types
- **DaemonServer:** AsyncSocket, HTTPRequest/Response, SocketListener; handles async socket I/O with manual HTTP parsing
- **SystemMonitor:** host_cpu_load_info, task_vm_info, vfsstat, getifaddrs for metrics; CPU usage computed from tick differences
- **Logger:** FileHandle for persistent logging, DispatchQueue for thread-safe writes, DateFormatter for timestamps
- **DaemonConfig:** JSON persistence via Codable, FileManager directory creation, URL construction for ~/Library/Application Support

### Architecture Patterns
- **Actor Model:** Synchronization via actor-isolated state; parallel health checks and metrics collection
- **Async/Await:** Connection handling, resource monitoring, logging all use Task-based concurrency
- **Observer Pattern:** DaemonManager implements ObservableObject with @Published properties for SwiftUI bindings
- **Protocol Composition:** AIService protocol enables extensible service registration and health checking

## API Endpoints Reference

### GET /status
Returns daemon status with system metrics.

### GET /health
Simple health check response.

### GET /metrics
System metrics only (CPU, memory, disk I/O, network connections).

### POST /jobs
Submit new job; returns 202 Accepted with job ID.

### GET /jobs
List all queued jobs.

### POST /session/open
Session creation with capability token generation.

### POST /job/submit, GET /job/status, POST /job/cancel, POST /artifacts/list
SidecarBridge-compatible endpoints for external integrations.

## Links

- [DAEMON_ENHANCEMENTS.md](../../DAEMON_ENHANCEMENTS.md) – Full daemon architecture and enhancement documentation
- [Sources/anigmad/main.swift](../../Sources/anigmad/main.swift) – Complete daemon implementation (1349 lines)
- [DaemonJobClient](../../Sources/AnigmaAppMac/DaemonJobClient.swift) – Client library for job submission
- [Package.swift](Package.swift) – SPM configuration; targets macOS 14.0+, Swift 6 strict concurrency
