import Foundation

/// Load zone classification based on queue depth
public enum LoadZone: String, Sendable, Codable {
    case green = "green"      // <70% capacity, normal operation
    case yellow = "yellow"    // 70-85%, moderate throttling
    case red = "red"          // 85-95%, significant throttling
    case black = "black"      // >95%, severe overload

    public init(percentage: Double) {
        switch percentage {
        case 0..<0.70:
            self = .green
        case 0.70..<0.85:
            self = .yellow
        case 0.85..<0.95:
            self = .red
        default:
            self = .black
        }
    }
}

/// Module initialization status
public enum ModuleStatus: String, Sendable, Codable {
    case pending = "pending"
    case initializing = "initializing"
    case ready = "ready"
    case failed = "failed"
}

/// Health check response for MCP server
public struct MCPHealthResponse: Sendable, Codable {
    public let uptime: TimeInterval
    public let loadZone: LoadZone
    public let activeRequests: Int
    public let queueDepth: Int
    public let toolMetrics: [ToolMetrics]
    public let moduleStatus: [String: ModuleStatus]
    public let recentErrors: [String]

    /// Format as readable text for MCP response
    public func formatAsText() -> String {
        let uptimeHours = Int(uptime / 3600)
        let uptimeMinutes = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)

        var text = """
            ═══════════════════════════════════════════════════════════════
            MCP SERVER HEALTH CHECK
            ═══════════════════════════════════════════════════════════════

            Uptime: \(uptimeHours)h \(uptimeMinutes)m
            Load Zone: \(loadZone.rawValue.uppercased())
            Active Requests: \(activeRequests)
            Queue Depth: \(queueDepth)

            """

        // Tool metrics
        if !toolMetrics.isEmpty {
            text += """
                ───────────────────────────────────────────────────────────────
                TOOL METRICS
                ───────────────────────────────────────────────────────────────

                """
            for metric in toolMetrics {
                let cacheRate = String(format: "%.1f", metric.cacheHitRate * 100)
                text += """
                    \(metric.toolName):
                      Calls: \(metric.callCount) | Errors: \(metric.errorCount)
                      Latency (ms): p50=\(metric.latencyP50), p95=\(metric.latencyP95), p99=\(metric.latencyP99)
                      Cache Hit Rate: \(cacheRate)%

                    """
            }
        }

        // Module status
        if !moduleStatus.isEmpty {
            text += """
                ───────────────────────────────────────────────────────────────
                MODULE STATUS
                ───────────────────────────────────────────────────────────────

                """
            for (moduleName, status) in moduleStatus.sorted(by: { $0.key < $1.key }) {
                text += "  \(moduleName): \(status.rawValue)\n"
            }
            text += "\n"
        }

        // Recent errors
        if !recentErrors.isEmpty {
            text += """
                ───────────────────────────────────────────────────────────────
                RECENT ERRORS
                ───────────────────────────────────────────────────────────────

                """
            for (index, error) in recentErrors.prefix(5).enumerated() {
                text += "  \(index + 1). \(error)\n"
            }
            text += "\n"
        }

        text += "═══════════════════════════════════════════════════════════════"
        return text
    }
}

/// Helper to track recent errors
public actor ErrorTracker {
    private var recentErrors: [String] = []
    private let maxErrors = 10

    public init() {}

    public func recordError(_ message: String) {
        recentErrors.append("[\(ISO8601DateFormatter().string(from: Date()))] \(message)")
        if recentErrors.count > maxErrors {
            recentErrors.removeFirst()
        }
    }

    public func getRecentErrors() -> [String] {
        Array(recentErrors.reversed())
    }

    public func clear() {
        recentErrors.removeAll()
    }
}
