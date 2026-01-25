//
//  Phase9Metrics.swift
//  HarmoniaModule
//
//  Integer-based metrics calculation for Phase 9.0 deterministic loop.
//  Avoids floating point arithmetic to maintain determinism.
//

@preconcurrency import Foundation
import AnigmaPrimitives

/// Integer-based metric set for deterministic reporting.
/// Uses (numerator, denominator) pairs instead of floating point ratios.
public struct Phase9MetricSet: Codable, Sendable {
    public let timestamp: Int64 // Sequence number, not wall-clock time
    public let metrics: [String: MetricValue]

    public init(metrics: [String: MetricValue] = [:], timestamp: Int64 = 0) {
        self.timestamp = timestamp
        self.metrics = metrics
    }

    /// Get a metric value, returning 0 if not found
    public func get(_ key: String) -> MetricValue {
        return metrics[key] ?? .integer(0)
    }

    /// Calculate rate as (count, total) pair
    public func rateOf(_ metric: String) -> MetricValue {
        switch get(metric) {
        case .integer(let value), .total(let value), .count(let value):
            return .rate(count: value, total: value)
        case .rate(let count, let total):
            return .rate(count: count, total: total)
        default:
            return .rate(count: 0, total: 1)
        }
    }
}

/// Metric value that is always integer-based to maintain determinism.
public enum MetricValue: Codable, Sendable {
    case integer(Int)
    case total(Int)
    case count(Int)
    case rate(count: Int, total: Int)
    case min(Int, Int)
    case max(Int, Int)
    case distribution([String: Int])

    // Convert to canonical JSON representation
    public var canonicalEncoded: [String: Any] {
        switch self {
        case .integer(let value):
            return ["type": "integer", "value": value]
        case .total(let value):
            return ["type": "total", "value": value]
        case .count(let value):
            return ["type": "count", "value": value]
        case .rate(let count, let total):
            return ["type": "rate", "count": count, "total": total]
        case .min(let value1, let value2):
            return ["type": "min", "value1": value1, "value2": value2]
        case .max(let value1, let value2):
            return ["type": "max", "value1": value1, "value2": value2]
        case .distribution(let dict):
            return ["type": "distribution", "values": dict]
        }
    }
}

/// Calculator for computing Phase 9 metrics from IR data
public actor Phase9MetricsCalculator {

    /// Compute metrics for a bounded improvement target
    public func computeMetrics(
        forTargetType targetType: String,
        targetId: String,
        from irStore: IRStore,
        policyVersion: String
    ) async throws -> Phase9MetricSet {

        let traces = try await getRelevantTraces(for: targetId, from: irStore)
        let policyViolations = try await getPoliciesViolated(for: targetId, from: irStore)
        let toolInvocations = await getToolInvocations(for: targetId, from: irStore)

        var metrics: [String: MetricValue] = [:]

        // Count successful operations
        let successfulOps = countSuccessful(traces)
        metrics["success_count"] = .integer(successfulOps)

        // Count failed operations
        let failedOps = countFailed(traces)
        metrics["error_count"] = .integer(failedOps)

        // Count total operations
        let totalOps = successfulOps + failedOps
        metrics["operation_count"] = .total(totalOps)

        // Count policy violations
        metrics["policy_violations"] = .integer(policyViolations.count)

        // Calculate success rate as integer ratio
        metrics["success_rate"] = .rate(count: successfulOps, total: totalOps)

        // Tool invocation metrics
        let buildOps = countToolInvoke(of: "swift_build", in: toolInvocations)
        let testOps = countToolInvoke(of: "swift_test", in: toolInvocations)
        metrics["build_runs"] = .integer(buildOps)
        metrics["test_runs"] = .integer(testOps)

        // Add metrics metadata for reproducibility
        metrics["policy_version"] = .integer(policyVersion.hashValue)
        metrics["snapshot_timestamp"] = .total(Int(Date().timeIntervalSince1970))

        return Phase9MetricSet(metrics: metrics, timestamp: 0) // Timestamp will be set properly
    }

    /// Count successful traces from governance events
    private func countSuccessful(_ traces: [IRTrace]) -> Int {
        return traces.filter { trace in
            if trace.eventType == "tool_completed" {
                return trace.details["status"] == "success"
            } else if trace.eventType == "state_transition_approved" {
                return true // All transitions that complete are successful
            } else if trace.eventType == "job_completed" {
                return trace.details["status"] == "success"
            }
            return false
        }.count
    }

    /// Count failed traces from governance events
    private func countFailed(_ traces: [IRTrace]) -> Int {
        return traces.filter { trace in
            if trace.eventType == "tool_completed" {
                return trace.details["status"] == "failed"
            } else if trace.eventType == "job_completed" {
                return trace.details["status"] == "failed"
            }
            return false
        }.count
    }

    /// Count how many times a specific tool was invoked
    private func countToolInvoke(of toolName: String, in toolInvocations: [String: Int]) -> Int {
        return toolInvocations[toolName] ?? 0
    }

    /// Get relevant traces for the target
    private func getRelevantTraces(for targetId: String, from irStore: IRStore) async throws -> [IRTrace] {
        return await irStore.getTracesByEventType("tool_completed")
    }

    /// Get policy violations for the target
    private func getPoliciesViolated(for targetId: String, from irStore: IRStore) async throws -> [IRPolicy] {
        // This would find all policies where this target violated the rule
        // For Phase 9.0, we just return a count in metrics
        return []
    }

    /// Get tool invocation counts for the target
    private func getToolInvocations(for targetId: String, from irStore: IRStore) async -> [String: Int] {
        let completedTraces = await irStore.getTracesByEventType("tool_completed")
        let invokedTraces = await irStore.getTracesByEventType("tool_invoked")
        let traces = completedTraces + invokedTraces

        var counts: [String: Int] = [:]
        for trace in traces {
            if !targetId.isEmpty {
                let targetMatch = trace.sourceEntity == targetId
                    || trace.details["target_id"] == targetId
                    || trace.details["targetId"] == targetId
                if !targetMatch {
                    continue
                }
            }

            let toolName = trace.details["tool_name"]
                ?? trace.details["toolName"]
                ?? trace.details["tool"]
                ?? trace.details["name"]

            guard let toolName, !toolName.isEmpty else {
                continue
            }
            counts[toolName, default: 0] += 1
        }

        return counts
    }
}

/// Snapshot hash generator for creating deterministic identifiers of workspace state
public struct WorkspaceSnapshotHash {

    /// Generate a deterministic hash of the current workspace state
    /// for the files related to the target
    public static func generate(for targetId: String, files: [String]) throws -> String {
        var buffer = Data()

        // Add targetId to make the hash target-specific
        if let prefixData = "target-\(targetId)\n".data(using: .utf8) {
            buffer.append(prefixData)
        }

        // Add normalized file contents in deterministic order
        for file in files.sorted() {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: file)) {
                let normalized = InputNormalizer.normalize(data)
                buffer.append(normalized)
            }
        }

        return BLAKE3Digest.hex(of: buffer)
    }
}

/// Extender to handle metric creation from traces
extension Phase9MetricsCalculator {

    /// Calculate metrics from trace data directly
    public func calculateMetricsFromTraces(_ traces: [IRTrace]) -> Phase9MetricSet {
        let successfulOps = countSuccessful(traces)
        let failedOps = countFailed(traces)
        let totalOps = successfulOps + failedOps

        var metrics: [String: MetricValue] = [:]
        metrics["success_count"] = .integer(successfulOps)
        metrics["error_count"] = .integer(failedOps)
        metrics["operation_count"] = .total(totalOps)
        metrics["success_rate"] = .rate(count: successfulOps, total: totalOps)

        return Phase9MetricSet(metrics: metrics)
    }
}
