//
//  GovernanceEventSinks.swift
//  HarmoniaModule
//
//  Event sinks with verbosity tiers for Phase C.
//

import Foundation

// MARK: - Event Verbosity Tiers

/// Controls which events are emitted.
public enum EventVerbosity: Sendable {
    /// Only critical errors and user-facing summaries.
    case minimal

    /// Normal operational events (default).
    case normal

    /// All events including debug traces.
    case debug
}

// MARK: - Tiered Console Event Sink

/// Console event sink with verbosity control.
public actor TieredConsoleEventSink: GovernanceEventSink {
    private let verbosity: EventVerbosity

    public init(verbosity: EventVerbosity = .normal) {
        self.verbosity = verbosity
    }

    public func emit(_ event: GovernanceLogEvent) async {
        // Filter by verbosity
        switch verbosity {
        case .minimal:
            guard event.severity == .critical else { return }

        case .normal:
            // Include info, warning, critical
            break

        case .debug:
            // Include everything
            break
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let severityIcon: String
        switch event.severity {
        case .info: severityIcon = "ℹ️"
        case .warning: severityIcon = "⚠️"
        case .critical: severityIcon = "🚨"
        }

        print("\(severityIcon) [\(timestamp)] Project \(event.projectId.uuidString.prefix(8)): \(event.message)")

        if !event.context.isEmpty && verbosity == .debug {
            let contextStr = event.context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            print("   Context: \(contextStr)")
        }
    }
}

// MARK: - User-Facing Event Collector

/// Collects events for user-facing summaries in CLI status.
public actor UserEventCollector: GovernanceEventSink {
    private var recentEvents: [GovernanceLogEvent] = []
    private let maxEvents: Int

    public init(maxEvents: Int = 20) {
        self.maxEvents = maxEvents
    }

    public func emit(_ event: GovernanceLogEvent) async {
        recentEvents.append(event)

        // Keep only recent events
        if recentEvents.count > maxEvents {
            recentEvents.removeFirst(recentEvents.count - maxEvents)
        }
    }

    /// Gets recent events filtered for user display.
    public func getUserSummary() -> GovernanceSummary {
        let criticalCount = recentEvents.filter { $0.severity == .critical }.count
        let warningCount = recentEvents.filter { $0.severity == .warning }.count

        // Group by code for summary
        var eventsByCode: [String: Int] = [:]
        for event in recentEvents {
            eventsByCode[event.code, default: 0] += 1
        }

        // Get most recent events for display
        let recentForDisplay = Array(recentEvents.suffix(5).reversed())

        return GovernanceSummary(
            totalEvents: recentEvents.count,
            criticalCount: criticalCount,
            warningCount: warningCount,
            eventsByCode: eventsByCode,
            recentEvents: recentForDisplay
        )
    }

    /// Clears all collected events.
    public func clear() {
        recentEvents.removeAll()
    }
}

// MARK: - Composite Event Sink

/// Routes events to multiple sinks.
public actor CompositeEventSink: GovernanceEventSink {
    private let sinks: [GovernanceEventSink]

    public init(sinks: [GovernanceEventSink]) {
        self.sinks = sinks
    }

    public func emit(_ event: GovernanceLogEvent) async {
        // Emit to all sinks in parallel
        await withTaskGroup(of: Void.self) { group in
            for sink in sinks {
                group.addTask {
                    await sink.emit(event)
                }
            }
        }
    }
}

// MARK: - Summary Models

/// User-facing summary of governance events.
public struct GovernanceSummary: Sendable {
    public let totalEvents: Int
    public let criticalCount: Int
    public let warningCount: Int
    public let eventsByCode: [String: Int]
    public let recentEvents: [GovernanceLogEvent]

    public init(
        totalEvents: Int,
        criticalCount: Int,
        warningCount: Int,
        eventsByCode: [String: Int],
        recentEvents: [GovernanceLogEvent]
    ) {
        self.totalEvents = totalEvents
        self.criticalCount = criticalCount
        self.warningCount = warningCount
        self.eventsByCode = eventsByCode
        self.recentEvents = recentEvents
    }

    /// Returns a simple status string for CLI.
    public var statusString: String {
        if criticalCount > 0 {
            return "🚨 \(criticalCount) critical"
        } else if warningCount > 0 {
            return "⚠️  \(warningCount) warnings"
        } else if totalEvents > 0 {
            return "✅ Normal"
        } else {
            return "⏳ No events yet"
        }
    }

    /// Returns a detailed report for CLI inspect.
    public var detailedReport: String {
        var report = "📊 Governance Events Summary\n"
        report += "===========================\n\n"

        report += "Totals:\n"
        report += "  • Total events: \(totalEvents)\n"
        report += "  • Critical: \(criticalCount)\n"
        report += "  • Warnings: \(warningCount)\n\n"

        if !eventsByCode.isEmpty {
            report += "By event type:\n"
            for (code, count) in eventsByCode.sorted(by: { $0.key < $1.key }) {
                report += "  • \(code): \(count)\n"
            }
            report += "\n"
        }

        if !recentEvents.isEmpty {
            report += "Recent events (newest first):\n"
            for event in recentEvents {
                let icon = event.severity == .critical ? "🚨" : event.severity == .warning ? "⚠️ " : "ℹ️"
                report += "  \(icon) \(event.message)\n"
            }
        }

        return report
    }
}
