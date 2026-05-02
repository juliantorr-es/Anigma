# Anigma CLI - Daemon Communication Protocol Specification

## Overview

This document specifies the communication protocol between the thin Anigma CLI client and the Anigma daemon. The protocol builds upon the existing SidecarBridge infrastructure while adding enhancements for CLI-specific requirements.

## 1. Transport Layer

### 1.1 Connection Methods

**Primary**: Unix Domain Socket
```
Protocol: http+unix
Path: /tmp/anigma-daemon.sock (configurable via ~/.anigma/config.json)
Format: http+unix:///tmp/anigma-daemon.sock
```

**Secondary**: TCP Socket (for remote access)
```
Protocol: http
Host: 127.0.0.1 (localhost only for security)
Port: 8080 (configurable)
Format: http://127.0.0.1:8080
```

### 1.2 Connection Lifecycle

```swift
// Client connection sequence
1. Check daemon availability via /health endpoint
2. Open session via /session/open
3. Receive capability token and client ID
4. Start heartbeat monitoring (30s interval)
5. Begin normal operations
6. Close session on exit (optional - daemon will timeout)
```

## 2. Message Format

### 2.1 Request Format (JSON-RPC 2.0)

```json
{
  "jsonrpc": "2.0",
  "method": "anigma.<endpoint>",
  "params": {
    "ctx": {
      "clientId": "client-123",
      "capabilityToken": "base64-encoded-token",
      "nonce": "random-base64-string"
    },
    "data": {
      // Endpoint-specific parameters
    }
  },
  "id": "request-uuid-456"
}
```

### 2.2 Response Format

```json
{
  "jsonrpc": "2.0",
  "result": {
    // Endpoint-specific response data
  },
  "error": null,
  "id": "request-uuid-456"
}
```

### 2.3 Error Response

```json
{
  "jsonrpc": "2.0",
  "result": null,
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Capability token validation failed",
    "data": {
      "requiredScope": "job.submit",
      "clientId": "client-123",
      "timestamp": "2024-01-27T15:30:00Z"
    }
  },
  "id": "request-uuid-456"
}
```

## 3. Authentication & Authorization

### 3.1 Session Establishment

**Request**: `POST /session/open`
```json
{
  "requestedClientName": "anigma-cli",
  "requestedScopes": [
    "job.submit",
    "job.status", 
    "vault.read",
    "vault.write",
    "receipt.verify"
  ]
}
```

**Response**:
```json
{
  "clientId": "client-123",
  "capabilityToken": "base64-encoded-jwt",
  "grantedScopes": ["job.submit", "job.status", "vault.read"],
  "sessionExpiresAt": "2024-01-28T15:30:00Z"
}
```

### 3.2 Request Context

Every request must include:
```swift
struct AnigmaRequestContext: Codable {
    let clientId: String
    let capabilityToken: String  // Base64 encoded
    let nonce: String           // Random string for replay protection
    let timestamp: Date?        // Optional for clock skew tolerance
}
```

### 3.3 Scope Definitions

| Scope | Description | Required For |
|-------|-------------|--------------|
| `job.submit` | Submit new jobs | `anigma job submit` |
| `job.status` | Check job status | `anigma job status` |
| `job.cancel` | Cancel jobs | `anigma job cancel` |
| `vault.read` | Read from vault | `anigma vault get`, `anigma vault list` |
| `vault.write` | Write to vault | `anigma vault put` |
| `models.list` | List models | `anigma models list` |
| `models.install` | Install models | `anigma models install` |
| `ml.chat` | Use chat API | `anigma chat` |
| `ml.embed` | Use embedding API | (future) |
| `config.read` | Read configuration | `anigma config show` |
| `config.write` | Write configuration | `anigma config set` |

## 4. Core API Endpoints

### 4.1 Health & Status

**GET /health**
```json
{
  "ok": true,
  "version": "1.0.0",
  "uptime": 3600,
  "services": {
    "vault": "healthy",
    "jobQueue": "healthy",
    "modelRegistry": "healthy"
  }
}
```

**POST /status**
```json
{
  "daemonVersion": "1.0.0",
  "apiVersion": "1.0.0",
  "uptimeSeconds": 3600,
  "activeJobs": 3,
  "vaultSizeBytes": 1073741824,
  "resourceUsage": {
    "memoryMB": 512,
    "cpuPercent": 45.2
  }
}
```

### 4.2 Job Management

**POST /job/submit**
```json
// Request
{
  "spec": {
    "kind": "inference",
    "inputs": ["prompt: Hello world"],
    "parameters": {
      "model": "gpt-4",
      "temperature": 0.7
    }
  }
}

// Response
{
  "jobId": "job-123",
  "receiptHash": "sha256:abc123",
  "estimatedQueueTime": 5
}
```

**POST /job/status**
```json
// Request
{
  "jobId": "job-123"
}

// Response
{
  "jobId": "job-123",
  "state": "RUNNING",
  "progressPermille": 500,
  "outputs": ["result: Hello world response"],
  "startedAt": "2024-01-27T15:30:00Z",
  "estimatedCompletion": "2024-01-27T15:31:00Z"
}
```

**POST /job/events/stream** (Server-Sent Events)
```
event: job-state
data: {"jobId": "job-123", "state": "RUNNING", "progress": 500}

event: job-output  
data: {"jobId": "job-123", "output": "Processing..."}

event: job-complete
data: {"jobId": "job-123", "result": "Success", "receiptHash": "sha256:abc123"}
```

### 4.3 Vault Operations

**POST /artifacts/ingest** (File Upload)
```json
// Request (multipart/form-data or JSON with base64)
{
  "data": "base64-encoded-data",
  "mediaType": "text/plain",
  "filenameHint": "document.txt",
  "kind": "blob",
  "metadata": {
    "project": "anigma",
    "author": "user@example.com"
  }
}

// Response
{
  "hash": "sha256:def456",
  "sizeBytes": 1024,
  "storagePath": "/vault/sha256/def456"
}
```

**POST /artifacts/retrieve** (File Download)
```json
// Request
{
  "hash": "sha256:def456"
}

// Response
{
  "data": "base64-encoded-data",
  "mediaType": "text/plain",
  "sizeBytes": 1024,
  "metadata": {
    "uploadedAt": "2024-01-27T15:30:00Z",
    "uploadedBy": "client-123"
  }
}
```

**POST /artifacts/list**
```json
// Request
{
  "pageToken": "",
  "pageSize": 50,
  "filter": {
    "kind": "blob",
    "createdAfter": "2024-01-01T00:00:00Z"
  }
}

// Response
{
  "artifacts": [
    {
      "hash": "sha256:def456",
      "sizeBytes": 1024,
      "mediaType": "text/plain",
      "createdAt": "2024-01-27T15:30:00Z",
      "metadata": {"project": "anigma"}
    }
  ],
  "nextPageToken": "token-789"
}
```

### 4.4 Model Management

**POST /models/list**
```json
// Response
{
  "models": [
    {
      "id": "gpt-4",
      "name": "GPT-4",
      "type": "chat",
      "sizeGB": 0,
      "provider": "openai",
      "requiresApiKey": true
    },
    {
      "id": "llama3-8b",
      "name": "Llama 3 8B",
      "type": "chat",
      "sizeGB": 4.7,
      "quantization": "Q4_K_M",
      "installedAt": "2024-01-27T15:30:00Z"
    }
  ]
}
```

**POST /models/install**
```json
// Request
{
  "modelId": "llama3-8b",
  "repo": "TheBloke/Llama-3-8B-GGUF",
  "revision": "main",
  "quantization": "Q4_K_M"
}

// Response (streaming via SSE)
event: download-progress
data: {"progress": 25, "downloadedMB": 250, "totalMB": 1000}

event: install-complete
data: {"modelId": "llama3-8b", "path": "/models/llama3-8b.Q4_K_M.gguf"}
```

### 4.5 ML Operations

**POST /ml/chat**
```json
// Request
{
  "messages": [
    {"role": "user", "content": "Hello, how are you?"}
  ],
  "model": "gpt-4",
  "temperature": 0.7,
  "sessionId": "session-123"
}

// Response (streaming)
event: chunk
data: {"content": "Hello", "finishReason": null}

event: chunk  
data: {"content": "! I'm", "finishReason": null}

event: complete
data: {"content": "Hello! I'm doing well, thank you for asking.", "finishReason": "stop"}
```

## 5. CLI-Specific Extensions

### 5.1 Configuration Management

**POST /config/get**
```json
// Request
{
  "keys": ["inference.provider", "workspace.path", "ui.theme"]
}

// Response
{
  "values": {
    "inference.provider": "openai",
    "workspace.path": "/Users/me/projects",
    "ui.theme": "dark"
  }
}
```

**POST /config/set**
```json
// Request
{
  "values": {
    "inference.provider": "anthropic",
    "apiKey": "sk-...",
    "workspace.path": "/Users/me/new-projects"
  }
}

// Response
{
  "updated": ["inference.provider", "workspace.path"],
  "failed": ["apiKey"]  // If validation fails
}
```

### 5.2 Workspace Operations

**POST /workspace/sync**
```json
// Request
{
  "path": "/Users/me/projects/anigma",
  "patterns": ["**/*.swift", "**/*.md"],
  "ignore": ["**/.build/**", "**/node_modules/**"]
}

// Response (streaming)
event: file-found
data: {"path": "Sources/main.swift", "size": 1024}

event: sync-complete
data: {"filesSynced": 42, "totalSize": 1048576}
```

### 5.3 System Integration

**GET /system/info**
```json
{
  "platform": "macOS",
  "version": "14.3",
  "architecture": "arm64",
  "cpuCores": 10,
  "memoryGB": 32,
  "gpu": "Apple M2 Pro",
  "diskFreeGB": 512
}
```

**GET /system/resources**
```json
{
  "current": {
    "memoryUsedMB": 4096,
    "cpuPercent": 65.2,
    "diskUsedGB": 128
  },
  "limits": {
    "maxMemoryMB": 16384,
    "maxConcurrentJobs": 4
  },
  "recommendations": [
    "Consider increasing maxMemoryMB to 8192 for better performance",
    "Reduce concurrent jobs to 3 to avoid memory pressure"
  ]
}
```

## 6. Error Handling

### 6.1 Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_TOKEN` | 401 | Capability token invalid or expired |
| `INSUFFICIENT_SCOPE` | 403 | Token lacks required scope |
| `RATE_LIMITED` | 429 | Too many requests |
| `JOB_NOT_FOUND` | 404 | Job ID not found |
| `ARTIFACT_NOT_FOUND` | 404 | Artifact hash not found |
| `MODEL_NOT_FOUND` | 404 | Model not found |
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `INTERNAL_ERROR` | 500 | Internal daemon error |
| `SERVICE_UNAVAILABLE` | 503 | Service temporarily unavailable |

### 6.2 Retry Logic

```swift
protocol RetryPolicy {
    func shouldRetry(error: AnigmaError) -> Bool
    func delayBeforeRetry(attempt: Int) -> TimeInterval
}

struct DefaultRetryPolicy: RetryPolicy {
    func shouldRetry(error: AnigmaError) -> Bool {
        // Retry on network errors and rate limits
        switch error.code {
        case "RATE_LIMITED", "SERVICE_UNAVAILABLE", "NETWORK_ERROR":
            return true
        default:
            return false
        }
    }
    
    func delayBeforeRetry(attempt: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let baseDelay = pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.1)
        return min(baseDelay + jitter, 30.0) // Max 30 seconds
    }
}
```

## 7. Performance Considerations

### 7.1 Connection Pooling

```swift
class ConnectionPool {
    private var connections: [HTTPClient]
    private let maxConnections: Int = 5
    
    func getConnection() -> HTTPClient {
        // Reuse existing connections
        // Create new ones if needed
        // Clean up idle connections
    }
}
```

### 7.2 Request Batching

```json
// Batch request
{
  "batch": [
    {"method": "anigma.job.status", "params": {"jobId": "job-1"}, "id": "1"},
    {"method": "anigma.job.status", "params": {"jobId": "job-2"}, "id": "2"},
    {"method": "anigma.vault.list", "params": {"pageSize": 10}, "id": "3"}
  ]
}

// Batch response
{
  "responses": [
    {"result": {...}, "error": null, "id": "1"},
    {"result": {...}, "error": null, "id": "2"},
    {"result": {...}, "error": null, "id": "3"}
  ]
}
```

### 7.3 Response Caching

```swift
protocol ResponseCache {
    func get<T: Codable>(key: String) -> T?
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval)
}

// Cache strategies:
// - Model metadata: 5 minutes
// - Job status: 10 seconds  
// - Vault listings: 30 seconds
// - Configuration: Until changed
```

## 8. Security Considerations

### 8.1 Token Security

- Capability tokens are short-lived (default: 24 hours)
- Tokens include client ID and granted scopes
- Tokens are signed by daemon private key
- Tokens never logged or displayed to users

### 8.2 Request Validation

- All inputs validated for type and constraints
- File size limits enforced (configurable)
- Rate limiting per client ID
- Request size limits (10MB default)

### 8.3 Transport Security

- Unix socket permissions: 0600 (owner read/write only)
- TCP connections restricted to localhost
- Optional TLS for remote deployments
- No sensitive data in URLs or headers

## 9. CLI Output Formatting

### 9.1 Output Formats

**Text** (default):
```
Job submitted: job-123
Status: RUNNING (50%)
Estimated completion: 15:31:00
```

**JSON** (`--format json`):
```json
{
  "jobId": "job-123",
  "status": "RUNNING",
  "progress": 0.5,
  "estimatedCompletion": "2024-01-27T15:31:00Z"
}
```

**Table** (`--format table`):
```
┌─────────┬──────────┬─────────┬─────────────────────┐
│ Job ID  │ Status   │ Progress│ Estimated Completion│
├─────────┼──────────┼─────────┼─────────────────────┤
│ job-123 │ RUNNING  │ 50%     │ 15:31:00           │
│ job-456 │ QUEUED   │ 0%      │ 15:35:00           │
└─────────┴──────────┴─────────┴─────────────────────┘
```

### 9.2 Progress Display

**Indeterminate** (spinner):
```
⠋ Processing... (no ETA)
```

**Determinate** (progress bar):
```
██████████░░░░░░░░░░ 50% (512KB/1MB) 10s remaining
```

**Multi-step**:
```
✓ Step 1: Download model
✓ Step 2: Load weights  
⣾ Step 3: Inference (45%)
  Step 4: Save results
```

## 10. Implementation Notes

### 10.1 CLI Architecture

```
anigma-cli
├── Command Layer (ArgumentParser)
│   ├── ChatCommand
│   ├── ModelsCommand
│   ├── JobCommand
│   └── ConfigCommand
├── Protocol Layer
│   ├── DaemonClient (SidecarBridge wrapper)
│   ├── RequestBuilder
│   └── ResponseParser
├── Formatting Layer
│   ├── TextFormatter
│   ├── JSONFormatter
│   └── TableFormatter
└── Integration Layer
    ├── FileSystem
    ├── Configuration
    └── Cache
```

### 10.2 Daemon Integration Points

Existing daemon endpoints that need CLI support:
1. `/session/open` - Session management ✓
2. `/job/*` - Job operations ✓
3. `/artifacts/*` - Vault operations ✓
4. `/models/*` - Model management ✓
5. `/ml/*` - ML operations ✓
6. `/config/*` - Configuration (new)
7. `/workspace/*` - Workspace (new)
8. `/system/*` - System info (new)

### 10.3 Migration Strategy

1. **Phase 1**: Basic command mapping using existing SidecarBridge
2. **Phase 2**: Add JSON-RPC wrapper for better error handling
3. **Phase 3**: Implement streaming and progress reporting
4. **Phase 4**: Add new protocol extensions (config, workspace, system)
5. **Phase 5**: Performance optimization and caching

## Appendix A: Complete API Reference

See `API_REFERENCE.md` for complete endpoint documentation with request/response examples.

## Appendix B: Protocol Versioning

Protocol version: `1.0.0`
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes

Version negotiation via `X-Protocol-Version` header.

## Appendix C: Testing Strategy

1. **Unit Tests**: Protocol layer, formatting layer
2. **Integration Tests**: CLI ↔ Daemon communication
3. **End-to-End Tests**: Complete user workflows
4. **Performance Tests**: Load testing, memory usage
5. **Security Tests**: Token validation, input sanitization