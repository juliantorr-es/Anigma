> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Harmonia V3 Deployment Implementation Guide

**Task**: td-764087  
**Version**: 1.0  
**Last Updated**: April 2026

This document provides Swift code examples and integration points for implementing Harmonia V3's deployment patterns.

---

## 1. Health Check System Integration

### 1.1 Extending HealthCheckCapsule for Deployment

```swift
// File: Packages/CoreUtilities/Sources/Capsules/HealthCheckCapsule/DeploymentHealthCheck.swift

import Foundation
import CapsuleCore
import TelemetryCore

/// Extended health check specifically for deployment scenarios
public extension HealthCheckCapsule {
    
    /// Comprehensive deployment health check with multiple probes
    func performDeploymentHealthCheck() async -> DeploymentHealth {
        async let readiness = checkReadiness()
        async let liveness = checkLiveness()
        async let dependencies = checkDependencies()
        async let performance = checkPerformance()
        
        let (ready, alive, deps, perf) = await (readiness, liveness, dependencies, performance)
        
        let overallStatus: HealthStatus = {
            if ready == .unhealthy || alive == .unhealthy || deps == .unhealthy {
                return .unhealthy
            }
            if perf == .degraded {
                return .degraded
            }
            return .healthy
        }()
        
        return DeploymentHealth(
            status: overallStatus,
            readiness: ready,
            liveness: alive,
            dependencies: deps,
            performance: perf,
            timestamp: Date()
        )
    }
    
    private func checkReadiness() async -> HealthStatus {
        // Can handle new requests?
        // Check: Configuration loaded, cache warm, connections ready
        let configReady = await verifyConfiguration()
        let cacheReady = await verifyCacheConnectivity()
        let connectionsReady = await verifyConnections()
        
        if configReady && cacheReady && connectionsReady {
            return .healthy
        }
        return .unhealthy
    }
    
    private func checkLiveness() async -> HealthStatus {
        // Is process still running?
        // Check: Memory reasonable, watchdog not expired
        let memoryOK = getMemoryUsage() < 2_000_000_000  // 2GB
        let watchdogOK = isWatchdogActive()
        
        if memoryOK && watchdogOK {
            return .healthy
        } else if !memoryOK {
            return .degraded  // Memory high but not critical
        }
        return .unhealthy
    }
    
    private func checkDependencies() async -> HealthStatus {
        let results = await checkAllDependencies()
        
        let allHealthy = results.allSatisfy { $0.status == .healthy }
        if allHealthy {
            return .healthy
        }
        
        let anyUnhealthy = results.contains { $0.status == .unhealthy }
        return anyUnhealthy ? .unhealthy : .degraded
    }
    
    private func checkPerformance() async -> HealthStatus {
        let metrics = await getPerformanceMetrics()
        
        // Check latency
        if metrics.latencyP99 > 500 {
            return .degraded
        }
        
        // Check error rate
        if metrics.errorRate > 0.01 {
            return .degraded
        }
        
        return .healthy
    }
    
    // Helper methods
    private func verifyConfiguration() async -> Bool {
        // Implementation
        return true
    }
    
    private func verifyCacheConnectivity() async -> Bool {
        // Implementation
        return true
    }
    
    private func verifyConnections() async -> Bool {
        // Implementation
        return true
    }
    
    private func isWatchdogActive() -> Bool {
        // Implementation
        return true
    }
    
    private func checkAllDependencies() async -> [DependencyStatus] {
        // Implementation
        return []
    }
    
    private func getPerformanceMetrics() async -> PerformanceMetrics {
        // Implementation
        return PerformanceMetrics(latencyP99: 0, errorRate: 0)
    }
}

public struct DeploymentHealth: Codable, Sendable {
    public let status: HealthStatus
    public let readiness: HealthStatus
    public let liveness: HealthStatus
    public let dependencies: HealthStatus
    public let performance: HealthStatus
    public let timestamp: Date
}

public struct DependencyStatus: Sendable {
    public let name: String
    public let status: HealthStatus
    public let latencyMs: Int
}

public struct PerformanceMetrics: Sendable {
    public let latencyP99: Int
    public let errorRate: Double
}
```

### 1.2 HTTP Endpoints for Health Checks

```swift
// File: Packages/AnigmaWebServer/Sources/DeploymentHealthEndpoints.swift

import Foundation
import NIO
import NIOHTTP1

public final class DeploymentHealthEndpoints {
    private let healthCheckCapsule: HealthCheckCapsule
    private let logger: TelemetryLogger
    
    public init(
        healthCheckCapsule: HealthCheckCapsule,
        logger: TelemetryLogger
    ) {
        self.healthCheckCapsule = healthCheckCapsule
        self.logger = logger
    }
    
    /// Readiness probe: Can this instance accept traffic?
    public func readinessProbe() async -> HTTPResponse {
        let health = await healthCheckCapsule.performDeploymentHealthCheck()
        
        let statusCode: Int = health.readiness == .healthy ? 200 : 503
        
        let response = HTTPResponse(
            status: HTTPResponseStatus(statusCode: statusCode),
            headers: HTTPHeaders([("Content-Type", "application/json")])
        )
        
        let body = """
        {
            "status": "\(health.readiness.rawValue)",
            "timestamp": "\(health.timestamp.ISO8601Format())"
        }
        """
        
        return response.with(body: body)
    }
    
    /// Liveness probe: Is this instance alive?
    public func livenessProbe() async -> HTTPResponse {
        let health = await healthCheckCapsule.performDeploymentHealthCheck()
        
        let statusCode: Int = health.liveness == .healthy ? 200 : 503
        
        let body = """
        {
            "status": "\(health.liveness.rawValue)",
            "uptime": \(ProcessInfo.processInfo.systemUptime),
            "memory_bytes": \(health.status == .healthy ? 0 : 0)
        }
        """
        
        return HTTPResponse(
            status: HTTPResponseStatus(statusCode: statusCode),
            body: body
        )
    }
    
    /// Startup probe: Has startup sequence completed?
    public func startupProbe() async -> HTTPResponse {
        let health = await healthCheckCapsule.performDeploymentHealthCheck()
        
        let statusCode: Int = health.status == .healthy ? 200 : 503
        
        let body = """
        {
            "ready": \(health.status == .healthy),
            "dependencies": {
                "cache": "\(health.dependencies.rawValue)",
                "database": "\(health.dependencies.rawValue)",
                "messaging": "\(health.dependencies.rawValue)"
            }
        }
        """
        
        return HTTPResponse(
            status: HTTPResponseStatus(statusCode: statusCode),
            body: body
        )
    }
    
    /// Detailed metrics for deployment monitoring
    public func deploymentMetrics() async -> HTTPResponse {
        let health = await healthCheckCapsule.performDeploymentHealthCheck()
        
        let body = """
        {
            "overall_status": "\(health.status.rawValue)",
            "readiness": "\(health.readiness.rawValue)",
            "liveness": "\(health.liveness.rawValue)",
            "dependencies": "\(health.dependencies.rawValue)",
            "performance": "\(health.performance.rawValue)",
            "timestamp": "\(health.timestamp.ISO8601Format())"
        }
        """
        
        return HTTPResponse(
            status: HTTPResponseStatus(statusCode: 200),
            body: body
        )
    }
}
```

---

## 2. Graceful Shutdown Implementation

### 2.1 Connection Draining

```swift
// File: Packages/AnigmaCore/Sources/GracefulShutdown/ConnectionDrainer.swift

import Foundation

public actor ConnectionDrainer {
    public enum DrainPhase {
        case accepting       // Accepting new connections
        case draining        // Refusing new, draining existing
        case shutdown        // All drained, ready to shutdown
    }
    
    private var phase: DrainPhase = .accepting
    private var activeConnections: Set<ConnectionID> = []
    private let logger: TelemetryLogger
    private let maxDrainWaitSeconds: TimeInterval = 30
    
    public init(logger: TelemetryLogger) {
        self.logger = logger
    }
    
    /// Register a new connection
    public func registerConnection(_ id: ConnectionID) {
        activeConnections.insert(id)
    }
    
    /// Deregister a completed connection
    public func deregisterConnection(_ id: ConnectionID) {
        activeConnections.remove(id)
    }
    
    /// Initiate graceful shutdown
    public func startGracefulShutdown() async {
        phase = .draining
        
        await logger.event(
            level: .info,
            category: "graceful_shutdown",
            message: "Graceful shutdown initiated",
            metadata: ["active_connections": String(activeConnections.count)]
        )
        
        // Wait for connections to drain with timeout
        let deadline = Date().addingTimeInterval(maxDrainWaitSeconds)
        
        while !activeConnections.isEmpty && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }
        
        // Log remaining connections
        if !activeConnections.isEmpty {
            await logger.event(
                level: .warning,
                category: "graceful_shutdown",
                message: "Shutdown timeout: Force closing \(activeConnections.count) connections"
            )
        }
        
        phase = .shutdown
    }
    
    /// Check if can accept new connections
    public func canAcceptNewConnection() -> Bool {
        phase == .accepting
    }
}

public typealias ConnectionID = String
```

### 2.2 Server Shutdown Coordinator

```swift
// File: Packages/AnigmaWebServer/Sources/ShutdownCoordinator.swift

import Foundation

public actor ServerShutdownCoordinator {
    private let connectionDrainer: ConnectionDrainer
    private let logger: TelemetryLogger
    private let shutdownTimeout: TimeInterval = 60  // 60 seconds total
    
    public init(
        connectionDrainer: ConnectionDrainer,
        logger: TelemetryLogger
    ) {
        self.connectionDrainer = connectionDrainer
        self.logger = logger
    }
    
    public func coordinateShutdown() async {
        let shutdownStart = Date()
        
        await logger.event(
            level: .critical,
            category: "shutdown_coordinator",
            message: "Server shutdown sequence starting"
        )
        
        // Phase 1: Signal graceful shutdown (5 seconds)
        await connectionDrainer.startGracefulShutdown()
        
        // Phase 2: Wait for active connections to drain (30 seconds)
        let drainDeadline = shutdownStart.addingTimeInterval(35)
        var connectionCheckCount = 0
        
        while Date() < drainDeadline {
            connectionCheckCount += 1
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            
            if connectionCheckCount 