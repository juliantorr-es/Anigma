//
//  PatternDetectors.swift
//  AnigmaCore
//
//  Concrete pattern detectors for reflexive analytics.
//

import Foundation
import ContractsCore

/// Detector for repeated failure patterns
public struct RepeatedFailureDetector: PatternDetector {
    public let patternType: PatternType = .repeatedFailure

    public func detect(in traces: [NormalizedTrace]) async throws -> [DetectedPattern] {
        var detected: [DetectedPattern] = []

        // Group traces by fingerprint
        let fingerprintGroups = Dictionary(grouping: traces) { trace in
            trace.fingerprint
        }

        // Look for repeated failures
        for (fingerprint, group) in fingerprintGroups {
            let failureTraces = group.filter { trace in
                trace.originalTrace.output?.status == .failed ||
                trace.originalTrace.decision.rejectionReason != nil
            }

            // Need at least 3 failures to detect pattern
            guard failureTraces.count >= 3 else { continue }

            // Check if failures are recent (within 24 hours)
            let now = Date()
            let recentFailures = failureTraces.filter { trace in
                now.timeIntervalSince(trace.timestamp) <= 24 * 60 * 60
            }

            guard recentFailures.count >= 3 else { continue }

            // Calculate pattern confidence
            let confidence = calculateFailureConfidence(recentFailures)

            let pattern = DetectedPattern(
                id: PatternId.generate(),
                type: .repeatedFailure,
                confidence: confidence,
                description: "Repeated failure pattern detected: \(recentFailures.count) failures with fingerprint '\(fingerprint)'",
                affectedTraces: recentFailures.map { $0.id },
                metadata: PatternMetadata(
                    frequency: recentFailures.count,
                    severity: .high,
                    firstOccurrence: recentFailures.map { $0.timestamp }.min() ?? now,
                    lastOccurrence: recentFailures.map { $0.timestamp }.max() ?? now,
                    context: [
                        "fingerprint": fingerprint,
                        "failure_rate": "\(recentFailures.count)/\(group.count)",
                        "time_span": "\(formatTimeSpan(recentFailures))"
                    ]
                )
            )

            detected.append(pattern)
        }

        return detected
    }

    private func calculateFailureConfidence(_ failures: [NormalizedTrace]) -> Double {
        // Higher confidence for more frequent failures
        let frequencyScore = min(Double(failures.count) / 10.0, 1.0)

        // Higher confidence for shorter time spans
        let timeSpan = calculateTimeSpan(failures)
        let timeScore = timeSpan > 0 ? max(1.0 - (timeSpan / (24 * 60 * 60)), 0.1) : 0.5

        return (frequencyScore + timeScore) / 2.0
    }

    private func calculateTimeSpan(_ traces: [NormalizedTrace]) -> TimeInterval {
        guard traces.count >= 2 else { return 0 }

        let timestamps = traces.map { $0.timestamp }.sorted()
        return timestamps.last!.timeIntervalSince(timestamps.first!)
    }

    private func formatTimeSpan(_ traces: [NormalizedTrace]) -> String {
        let span = calculateTimeSpan(traces)
        if span < 60 {
            return "\(Int(span))s"
        } else if span < 3600 {
            return "\(Int(span / 60))m"
        } else {
            return "\(Int(span / 3600))h"
        }
    }
}

/// Detector for policy violation patterns
public struct PolicyViolationDetector: PatternDetector {
    public let patternType: PatternType = .policyViolation

    public func detect(in traces: [NormalizedTrace]) async throws -> [DetectedPattern] {
        var detected: [DetectedPattern] = []

        // Group violations by policy
        let violationGroups = Dictionary(grouping: traces.filter { trace in
            !trace.originalTrace.decision.policyViolations.isEmpty
        }) { trace in
            trace.originalTrace.decision.policyViolations.first?.policy ?? "unknown"
        }

        // Look for patterns in violations
        for (policy, tracesWithViolations) in violationGroups {
            guard tracesWithViolations.count >= 2 else { continue }

            // Sort by timestamp for trend analysis
            let sortedTraces = tracesWithViolations.sorted { $0.timestamp < $1.timestamp }

            // Check if violations are increasing
            let isIncreasing = isIncreasingTrend(sortedTraces)

            // Check severity escalation
            let severityEscalation = hasSeverityEscalation(sortedTraces)

            // Only detect pattern if there's a concerning trend
            guard isIncreasing || severityEscalation else { continue }

            let confidence = calculateViolationConfidence(sortedTraces)

            let pattern = DetectedPattern(
                id: PatternId.generate(),
                type: .policyViolation,
                confidence: confidence,
                description: "Policy violation pattern: \(sortedTraces.count) violations of policy '\(policy)'",
                affectedTraces: sortedTraces.map { $0.id },
                metadata: PatternMetadata(
                    frequency: sortedTraces.count,
                    severity: severityEscalation ? .high : .medium,
                    firstOccurrence: sortedTraces.first?.timestamp ?? Date(),
                    lastOccurrence: sortedTraces.last?.timestamp ?? Date(),
                    context: [
                        "policy": policy,
                        "is_increasing": "\(isIncreasing)",
                        "severity_escalation": "\(severityEscalation)",
                        "violation_types": sortedTraces.flatMap { $0.originalTrace.decision.policyViolations.map { $0.rule } }.joined(separator: ",")
                    ]
                )
            )

            detected.append(pattern)
        }

        return detected
    }

    private func isIncreasingTrend(_ violations: [NormalizedTrace]) -> Bool {
        guard violations.count >= 3 else { return false }

        // Check if time between violations is decreasing
        var decreasingCount = 0
        for i in 1..<violations.count {
            let currentGap = violations[i].timestamp.timeIntervalSince(violations[i - 1].timestamp)
            let previousGap = i > 1 ? violations[i - 1].timestamp.timeIntervalSince(violations[i - 2].timestamp) : currentGap

            if currentGap < previousGap {
                decreasingCount += 1
            }
        }

        return decreasingCount >= violations.count / 2
    }

    private func hasSeverityEscalation(_ violations: [NormalizedTrace]) -> Bool {
        guard violations.count >= 2 else { return false }

        let severities = violations.compactMap { trace in
            trace.originalTrace.decision.policyViolations.first?.severity
        }

        // Check if any violation is more severe than previous
        for i in 1..<severities.count {
            if compareSeverity(severities[i], severities[i - 1]) == .orderedDescending {
                return true
            }
        }

        return false
    }

    private func compareSeverity(_ s1: PolicySeverity, _ s2: PolicySeverity) -> ComparisonResult {
        let severityOrder: [PolicySeverity] = [.info, .warning, .error, .critical]
        guard let i1 = severityOrder.firstIndex(of: s1),
              let i2 = severityOrder.firstIndex(of: s2) else {
            return .orderedSame
        }

        if i1 < i2 { return .orderedAscending }
        if i1 > i2 { return .orderedDescending }
        return .orderedSame
    }

    private func calculateViolationConfidence(_ violations: [NormalizedTrace]) -> Double {
        // Higher confidence for more violations
        let frequencyScore = min(Double(violations.count) / 5.0, 1.0)

        // Higher confidence for severity escalation
        let hasEscalation = hasSeverityEscalation(violations)
        let escalationScore = hasEscalation ? 0.3 : 0.0

        // Higher confidence for increasing trend
        let isIncreasing = isIncreasingTrend(violations)
        let trendScore = isIncreasing ? 0.2 : 0.0

        return min(frequencyScore + escalationScore + trendScore, 1.0)
    }
}

/// Detector for performance degradation patterns
public struct PerformanceDegradationDetector: PatternDetector {
    public let patternType: PatternType = .performanceDegradation

    public func detect(in traces: [NormalizedTrace]) async throws -> [DetectedPattern] {
        var detected: [DetectedPattern] = []

        // Group traces by step type or operation
        let operationGroups = Dictionary(grouping: traces) { trace in
            trace.originalTrace.input.stepId.value.prefix(5)  // Group by step prefix
        }

        // Look for performance degradation within each operation group
        for (operation, group) in operationGroups {
            guard group.count >= 5 else { continue }

            // Sort by timestamp
            let sortedTraces = group.sorted { $0.timestamp < $1.timestamp }

            // Calculate performance trend
            let performanceTrend = calculatePerformanceTrend(sortedTraces)

            // Check if performance is degrading
            guard performanceTrend.isDegradation else { continue }

            let confidence = calculatePerformanceConfidence(sortedTraces, trend: performanceTrend)

            let pattern = DetectedPattern(
                id: PatternId.generate(),
                type: .performanceDegradation,
                confidence: confidence,
                description: "Performance degradation in operation '\(operation)': \(performanceTrend.description)",
                affectedTraces: sortedTraces.map { $0.id },
                metadata: PatternMetadata(
                    frequency: sortedTraces.count,
                    severity: .medium,
                    firstOccurrence: sortedTraces.first?.timestamp ?? Date(),
                    lastOccurrence: sortedTraces.last?.timestamp ?? Date(),
                    context: [
                        "operation": String(operation),
                        "trend_slope": "\(performanceTrend.slope)",
                        "trend_correlation": "\(performanceTrend.correlation)",
                        "avg_duration": "\(performanceTrend.averageDuration)",
                        "recent_duration": "\(performanceTrend.recentDuration)"
                    ]
                )
            )

            detected.append(pattern)
        }

        return detected
    }

    private func calculatePerformanceTrend(_ traces: [NormalizedTrace]) -> PerformanceTrend {
        let durations = traces.compactMap { $0.originalTrace.output?.metrics.duration }
        let recentDurations = Array(durations.suffix(3))
        let olderDurations = Array(durations.prefix(durations.count - 3))

        guard recentDurations.count >= 2 && olderDurations.count >= 2 else {
            return PerformanceTrend(isDegradation: false, slope: 0, correlation: 0, averageDuration: durations.reduce(0, +) / Double(durations.count), recentDuration: durations.last ?? 0)
        }

        let recentAvg = recentDurations.reduce(0, +) / Double(recentDurations.count)
        let olderAvg = olderDurations.reduce(0, +) / Double(olderDurations.count)

        // Simple linear regression to detect trend
        let slope = recentAvg - olderAvg
        let correlation = calculateCorrelation(recentDurations, olderDurations)

        return PerformanceTrend(
            isDegradation: slope > 0.1,  // 10% increase
            slope: slope,
            correlation: correlation,
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            recentDuration: durations.last ?? 0
        )
    }

    private func calculateCorrelation(_ recent: [Double], _ older: [Double]) -> Double {
        // Simple correlation calculation
        guard recent.count == older.count else { return 0 }

        let recentMean = recent.reduce(0, +) / Double(recent.count)
        let olderMean = older.reduce(0, +) / Double(older.count)

        let recentVar = recent.map { pow($0 - recentMean, 2) }.reduce(0, +) / Double(recent.count)
        let olderVar = older.map { pow($0 - olderMean, 2) }.reduce(0, +) / Double(older.count)

        guard recentVar > 0 && olderVar > 0 else { return 0 }

        // Simple correlation coefficient
        let covariance = zip(recent, older).map { ($0.0 - recentMean) * ($0.1 - olderMean) }.reduce(0, +) / Double(recent.count)
        return covariance / (sqrt(recentVar) * sqrt(olderVar))
    }

    private func calculatePerformanceConfidence(_ traces: [NormalizedTrace], trend: PerformanceTrend) -> Double {
        // Higher confidence for stronger degradation
        let degradationStrength = abs(trend.slope)
        let strengthScore = min(degradationStrength / 1.0, 1.0)

        // Higher confidence for more consistent trend
        let consistencyScore = abs(trend.correlation)

        // Higher confidence for more data points
        let dataScore = min(Double(traces.count) / 10.0, 1.0)

        return (strengthScore + consistencyScore + dataScore) / 3.0
    }
}

/// Detector for resource exhaustion patterns
public struct ResourceExhaustionDetector: PatternDetector {
    public let patternType: PatternType = .resourceExhaustion

    public func detect(in traces: [NormalizedTrace]) async throws -> [DetectedPattern] {
        var detected: [DetectedPattern] = []

        // Look for resource exhaustion events and their originating TraceId
        let exhaustionEventsWithTraceId = traces.flatMap { trace in
            trace.normalizedEvents.filter { (event: NormalizedEvent) -> Bool in
                event.category == .resource &&
                (event.originalEvent.type == .resourceExhausted || event.originalEvent.type == .timeout)
            }.map { ($0, trace.id) }
        }

        // Group by resource type
        let resourceGroups = Dictionary(grouping: exhaustionEventsWithTraceId) { (tuple: (event: NormalizedEvent, traceId: TraceId)) in
            tuple.event.data["resource_type"] ?? "unknown"
        }

        // Look for patterns in resource exhaustion
        for (resourceType, eventsWithTraceId) in resourceGroups {
            guard eventsWithTraceId.count >= 2 else { continue }

            // eventsWithTraceId is now [(NormalizedEvent, TraceId)]
            // Sort by timestamp
            let sortedEventsWithTraceId = eventsWithTraceId.sorted { $0.0.timestamp < $1.0.timestamp }

            // isResourceExhaustionIncreasing and calculateResourceConfidence need to be updated to accept [(NormalizedEvent, TraceId)]
            let isIncreasing = isResourceExhaustionIncreasing(sortedEventsWithTraceId.map { $0.0 }) // pass only NormalizedEvent

            // Calculate pattern confidence
            let confidence = calculateResourceConfidence(sortedEventsWithTraceId.map { $0.0 }) // pass only NormalizedEvent

            let pattern = DetectedPattern(
                id: PatternId.generate(),
                type: .resourceExhaustion,
                confidence: confidence,
                description: "Resource exhaustion pattern for '\(resourceType)': \(eventsWithTraceId.count) events",
                affectedTraces: sortedEventsWithTraceId.map { $0.1 }, // map to TraceId
                metadata: PatternMetadata(
                    frequency: eventsWithTraceId.count,
                    severity: .high,
                    firstOccurrence: sortedEventsWithTraceId.first?.0.timestamp ?? Date(),
                    lastOccurrence: sortedEventsWithTraceId.last?.0.timestamp ?? Date(),
                    context: [
                        "resource_type": resourceType,
                        "is_increasing": "\(isIncreasing)",
                        "avg_time_to_exhaustion": "\(calculateAverageTimeToExhaustion(sortedEventsWithTraceId.map { $0.0 }))"
                    ]
                )
            )

            detected.append(pattern)
        }

        return detected
    }

    private func isResourceExhaustionIncreasing(_ events: [NormalizedEvent]) -> Bool {
        guard events.count >= 2 else { return false }

        // Check if time to exhaustion is decreasing
        var decreasingCount = 0
        for i in 1..<events.count {
            let currentDuration = events[i].duration
            let previousDuration = events[i - 1].duration

            if currentDuration < previousDuration {
                decreasingCount += 1
            }
        }

        return decreasingCount >= events.count / 2
    }

    private func calculateResourceConfidence(_ events: [NormalizedEvent]) -> Double {
        // Higher confidence for more events
        let frequencyScore = min(Double(events.count) / 3.0, 1.0)

        // Higher confidence for increasing trend
        let isIncreasing = isResourceExhaustionIncreasing(events)
        let trendScore = isIncreasing ? 0.3 : 0.0

        // Higher confidence for shorter times to exhaustion
        let avgTimeToExhaustion = calculateAverageTimeToExhaustion(events)
        let timeScore = avgTimeToExhaustion > 0 ? max(1.0 - (avgTimeToExhaustion / 300.0), 0.1) : 0.5

        return (frequencyScore + trendScore + timeScore) / 3.0
    }

    private func calculateAverageTimeToExhaustion(_ events: [NormalizedEvent]) -> Double {
        let durations = events.map { $0.duration }.filter { $0 > 0 }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }
}

/// Detector for quarantine patterns
public struct QuarantinePatternDetector: PatternDetector {
    public let patternType: PatternType = .quarantinePattern

    public func detect(in traces: [NormalizedTrace]) async throws -> [DetectedPattern] {
        var detected: [DetectedPattern] = []

        // Look for quarantine events and their originating TraceId
        let quarantineEventsWithTraceId = traces.flatMap { trace in
            trace.normalizedEvents.filter { (event: NormalizedEvent) -> Bool in
                event.originalEvent.type == .quarantineTriggered
            }.map { ($0, trace.id) }
        }

        // Group by entity or step
        let entityGroups = Dictionary(grouping: quarantineEventsWithTraceId) { (tuple: (event: NormalizedEvent, traceId: TraceId)) in
            tuple.event.data["entity_id"] ?? tuple.event.data["step_id"] ?? "unknown"
        }

        // Look for repeated quarantine of same entity
        for (entity, eventsWithTraceId) in entityGroups {
            guard eventsWithTraceId.count >= 2 else { continue }

            // eventsWithTraceId is now [(NormalizedEvent, TraceId)]
            // Sort by timestamp
            let sortedEventsWithTraceId = eventsWithTraceId.sorted { $0.0.timestamp < $1.0.timestamp }

            let isFrequent = isQuarantineFrequent(sortedEventsWithTraceId.map { $0.0 })
            let confidence = calculateQuarantineConfidence(sortedEventsWithTraceId.map { $0.0 })

            let pattern = DetectedPattern(
                id: PatternId.generate(),
                type: .quarantinePattern,
                confidence: confidence,
                description: "Frequent quarantine pattern for entity '\(entity)': \(eventsWithTraceId.count) quarantines",
                affectedTraces: sortedEventsWithTraceId.map { $0.1 },
                metadata: PatternMetadata(
                    frequency: eventsWithTraceId.count,
                    severity: .medium,
                    firstOccurrence: sortedEventsWithTraceId.first?.0.timestamp ?? Date(),
                    lastOccurrence: sortedEventsWithTraceId.last?.0.timestamp ?? Date(),
                    context: [
                        "entity_id": entity,
                        "is_frequent": "\(isFrequent)",
                        "avg_quarantine_duration": "\(calculateAverageQuarantineDuration(sortedEventsWithTraceId.map { $0.0 }))"
                    ]
                )
            )

            detected.append(pattern)
        }

        return detected
    }

    private func isQuarantineFrequent(_ events: [NormalizedEvent]) -> Bool {
        guard events.count >= 2 else { return false }

        // Check if time between quarantines is decreasing
        var frequentCount = 0
        for i in 1..<events.count {
            let currentGap = events[i].timestamp.timeIntervalSince(events[i - 1].timestamp)
            if currentGap < 3600 {  // Less than 1 hour
                frequentCount += 1
            }
        }

        return frequentCount >= events.count / 2
    }

    private func calculateQuarantineConfidence(_ events: [NormalizedEvent]) -> Double {
        // Higher confidence for more quarantines
        let frequencyScore = min(Double(events.count) / 3.0, 1.0)

        // Higher confidence for frequent quarantines
        let isFrequent = isQuarantineFrequent(events)
        let frequencyBonus = isFrequent ? 0.2 : 0.0

        return min(frequencyScore + frequencyBonus, 1.0)
    }

    private func calculateAverageQuarantineDuration(_ events: [NormalizedEvent]) -> Double {
        let durations = events.compactMap { event in
            event.data["quarantine_duration"].flatMap(Double.init)
        }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }
}

// MARK: - Supporting Types

/// Performance trend analysis
internal struct PerformanceTrend {
    let isDegradation: Bool
    let slope: Double
    let correlation: Double
    let averageDuration: Double
    let recentDuration: Double

    init(isDegradation: Bool, slope: Double, correlation: Double, averageDuration: Double, recentDuration: Double) {
        self.isDegradation = isDegradation
        self.slope = slope
        self.correlation = correlation
        self.averageDuration = averageDuration
        self.recentDuration = recentDuration
    }

    var description: String {
        if isDegradation {
            return "Degrading (slope: \(String(format: "%.2f", slope)), correlation: \(String(format: "%.2f", correlation)))"
        } else {
            return "Stable (slope: \(String(format: "%.2f", slope)), correlation: \(String(format: "%.2f", correlation)))"
        }
    }
}
