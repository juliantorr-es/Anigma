import Foundation
import CapsuleCore
import TelemetryCore
import CapsuleRegistry

// MARK: - Models

/// System health status report
public struct SystemHealth: Codable, Sendable {
    public let uptime: TimeInterval
    public let memoryUsage: UInt64
    public let status: HealthStatus
    public let timestamp: Date
    
    public init(uptime: TimeInterval, memoryUsage: UInt64, status: HealthStatus, timestamp: Date) {
        self.uptime = uptime
        self.memoryUsage = memoryUsage
        self.status = status
        self.timestamp = timestamp
    }
}

// MARK: - HealthCheckCapsule

/// Capsule responsible for monitoring system health
public final class HealthCheckCapsule: Sendable {
    public let id: String
    private let diagnostics: CapsuleDiagnostics

    public init(id: String = UUID().uuidString, diagnostics: CapsuleDiagnostics) {
        self.id = id
        self.diagnostics = diagnostics
    }

    /// Performs a health check of the system
    /// - Returns: A SystemHealth struct containing uptime, memory usage, and status
    public func checkHealth() async -> SystemHealth {
        let uptime = ProcessInfo.processInfo.systemUptime
        let memory = getMemoryUsage()
        
        // Basic heuristic: Process is running, so it's "healthy".
        // In a real system, we might check if memory > threshold -> degraded.
        let status: HealthStatus = .healthy

        let health = SystemHealth(
            uptime: uptime,
            memoryUsage: memory,
            status: status,
            timestamp: Date()
        )
        
        // Log telemetry event
        diagnostics.event(
            level: .info,
            category: "health_check",
            message: "System health check completed",
            metadata: [
                "uptime": String(uptime),
                "memory_bytes": String(memory),
                "status": status.rawValue
            ]
        )
        
        return health
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
}
