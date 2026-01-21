import Foundation

/// System for detecting anomalies in analytics data
public final class AnomalyScanSystem {
    private let failureRateThreshold: Double
    private let latencyThreshold: Double  // in milliseconds
    private let minSampleSize: Int

    public init(
        failureRateThreshold: Double = 0.3,  // 30% failure rate triggers warning
        latencyThreshold: Double = 5000.0,   // 5s p95 latency triggers warning
        minSampleSize: Int = 10              // Minimum runs to consider
    ) {
        self.failureRateThreshold = failureRateThreshold
        self.latencyThreshold = latencyThreshold
        self.minSampleSize = minSampleSize
    }

    public func scanForAnomalies(
        rollups: [AnalyticsRollupComponent],
        database: ContextumDatabase
    ) async throws -> [AnomalyComponent] {
        var anomalies: [AnomalyComponent] = []

        for rollup in rollups {
            // Skip if insufficient data
            guard rollup.totalRuns >= minSampleSize else { continue }

            // Detector 1: High failure rate
            let failureRate = Double(rollup.totalRuns - rollup.successfulRuns) / Double(rollup.totalRuns)
            if failureRate > failureRateThreshold {
                let severity: AnomalyComponent.Severity = failureRate > 0.5 ? .critical : .warning

                anomalies.append(AnomalyComponent(
                    detectorID: "high_failure_rate",
                    windowStart: rollup.windowStart,
                    windowEnd: rollup.windowEnd,
                    groupKeyHash: rollup.groupKeyHash,
                    anomalySpecHash: "failure_rate_\(Int(failureRateThreshold * 100))",
                    subjectKey: rollup.agentID ?? rollup.taxonomy ?? "unknown",
                    severity: severity,
                    evidenceRollupIDs: [rollup.receiptID],
                    reportArtifactHash: rollup.reportArtifactHash,
                    receiptID: "anomaly_\(UUID().uuidString)"
                ))
            }

            // Detector 2: High latency
            if rollup.latencyP95 > latencyThreshold {
                let severity: AnomalyComponent.Severity = rollup.latencyP95 > latencyThreshold * 2 ? .critical : .warning

                anomalies.append(AnomalyComponent(
                    detectorID: "high_latency",
                    windowStart: rollup.windowStart,
                    windowEnd: rollup.windowEnd,
                    groupKeyHash: rollup.groupKeyHash,
                    anomalySpecHash: "latency_p95_\(Int(latencyThreshold))",
                    subjectKey: rollup.agentID ?? rollup.taxonomy ?? "unknown",
                    severity: severity,
                    evidenceRollupIDs: [rollup.receiptID],
                    reportArtifactHash: rollup.reportArtifactHash,
                    receiptID: "anomaly_\(UUID().uuidString)"
                ))
            }

            // Detector 3: Failure code concentration
            // If one error code dominates (>50% of failures), that's suspicious
            if let failureCodes = rollup.failureCodes {
                let totalFailures = rollup.totalRuns - rollup.successfulRuns
                if totalFailures > 0 {
                    let maxFailureCount = failureCodes.values.max() ?? 0
                    let concentration = Double(maxFailureCount) / Double(totalFailures)

                    if concentration > 0.5 && maxFailureCount > 5 {
                        let dominantCode = failureCodes.max { $0.value < $1.value }?.key ?? "unknown"

                        anomalies.append(AnomalyComponent(
                            detectorID: "failure_code_concentration",
                            windowStart: rollup.windowStart,
                            windowEnd: rollup.windowEnd,
                            groupKeyHash: rollup.groupKeyHash,
                            anomalySpecHash: "failure_concentration_50pct",
                            subjectKey: dominantCode,
                            severity: .warning,
                            evidenceRollupIDs: [rollup.receiptID],
                            reportArtifactHash: rollup.reportArtifactHash,
                            receiptID: "anomaly_\(UUID().uuidString)"
                        ))
                    }
                }
            }
        }

        if !anomalies.isEmpty {
            print("⚠️ [AnomalyS canSystem] Detected \(anomalies.count) anomalies:")
            for anomaly in anomalies {
                print("   - [\(anomaly.severity.rawValue.uppercased())] \(anomaly.detectorID) for \(anomaly.subjectKey)")
            }
        }

        return anomalies
    }
}
