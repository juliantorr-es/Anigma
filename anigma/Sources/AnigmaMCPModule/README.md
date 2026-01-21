# Anigma MCP Module

## Responsibility
**The Standard Intelligence Bridge**.
This module implements the Model Context Protocol (MCP) server for the Anigma platform. it acts as the high-bandwidth interface between external AI agents and the internal Anigma core modules and domain verticals.

## Key Components

### 1. MCPServerImpl
The core server implementation that handles the JSON-RPC lifecycle over standard I/O or other transports.
- **Protocol Compliance**: Implements the full MCP specification for tool discovery, resource management, and notification streaming.
- **Security**: Wraps every tool call in a governance context.

### 2. AdaptiveThrottle
Dynamic rate limiting and backoff engine.
- **Load Zones**: Green (Normal), Yellow (Slight Load), Red (Throttling), Black (Hard Reject).
- **Priority-Based Shedding**: High-priority health checks are preserved even during severe overload while heavy compute tasks are shed first.

### 3. MCPMetrics
Real-time observability for tool usage.
- **Latency Percentiles**: Tracks p50, p95, and p99 latencies per tool.
- **Cache Hit Rates**: Monitors the efficiency of the MCP caching layer.

### 4. MCPRequestQueue
Prioritized execution queue for incoming tool requests.
- **Ordering**: Ensures critical system operations jump the queue over standard background tasks.

## Implementation Details
- **Architecture**: Asynchronous actor-based design for extreme concurrency.
- **Efficiency**: Zero-copy data passing for large resource contents.
- **Reliability**: Integrated health checks and adaptive throttling to prevent cascading failures.

## Maturity Level
**Level 5 (Golden)**: Strict concurrency enabled, dedicated test suite for throttle and metrics logic, architectural documentation complete.
