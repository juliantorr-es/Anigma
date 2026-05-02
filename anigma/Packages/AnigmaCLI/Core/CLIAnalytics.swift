//
//  CLIAnalytics.swift
//  AnigmaCLICore
//
//  CLI analytics system for Phase 3 thin client migration.
//  Privacy-preserving analytics with opt-in/opt-out support.
//

import Foundation
import TelemetryCore

/// CLI-specific analytics categories
public enum CLIAnalyticsCategory: String, Sendable, CaseIterable {
    case commandUsage = "cli.command_usage"
    case performance = "cli.performance"
    case migration = "cli.migration"
    case error = "cli.error"
    case optimization = "cli.optimization"
    case userExperience = "cli.user_experience"
}

/// CLI command usage metrics
public struct CLICommandMetrics: Sendable, Codable {
    public let commandName: String
    public let executionCount: Int
    public let averageDurationMs: Double
    public let successRate: Double
    public let errorCount: Int
    public let cacheHitRate: Double?
    public let daemonUsageRate: Double?
    
    public init(
        commandName: String,
        executionCount: Int,
        averageDurationMs: Double,
        successRate: Double,
        errorCount: Int,
        cacheHitRate: Double? = nil,
        daemonUsageRate: Double? = nil
    ) {
        self.commandName = commandName
        self.executionCount = executionCount
        self.averageDurationMs = averageDurationMs
        self.successRate = successRate
        self.errorCount = errorCount
        self.cacheHitRate = cacheHitRate
        self.daemonUsageRate = daemonUsageRate
    }
}

/// Performance optimization insights
public struct OptimizationInsight: Sendable, Codable {
    public let id: String
    public let category: String
    public let description: String
    public let impactScore: Double
    public let confidence: Double
    public let suggestedAction: String
    
    public init(
        id: String = UUID().uuidString,
        category: String,
        description: String,
        impactScore: Double,
        confidence: Double,
        suggestedAction: String
    ) {
        self.id = id
        self.category = category
        self.description = description
        self.impactScore = impactScore
        self.confidence = confidence
        self.suggestedAction = suggestedAction
    }
}

/// Analytics configuration with privacy controls
public struct CLIAnalyticsConfiguration: Sendable, Codable {
    public let isEnabled: Bool
    public let collectionLevel: CollectionLevel
    public let anonymizationLevel: AnonymizationLevel
    public let retentionDays: Int
    public let optInRequired: Bool
    
    public enum CollectionLevel: String, Sendable, Codable, CaseIterable {
        case minimal = "minimal"
        case basic = "basic"
        case detailed = "detailed"
        case full = "full"
    }
    
    public enum AnonymizationLevel: String, Sendable, Codable, CaseIterable {
        case anonymous = "anonymous"
        case pseudonymous = "pseudonymous"
        case aggregated = "aggregated"
    }
    
    public init(
        isEnabled: Bool = true,
        collectionLevel: CollectionLevel = .basic,
        anonymizationLevel: AnonymizationLevel = .anonymous,
        retentionDays: Int = 30,
        optInRequired: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.collectionLevel = collectionLevel
        self.anonymizationLevel = anonymizationLevel
        self.retentionDays = retentionDays
        self.optInRequired = optInRequired
    }
    
    public static let `default` = CLIAnalyticsConfiguration()
}

/// Main CLI analytics manager
public actor CLIAnalyticsManager {
    private let telemetryClient: TelemetryClient?
    private var configuration: CLIAnalyticsConfiguration
    private var metricsBuffer: [CLICommandMetrics] = []
    private let sessionId: String?
    private var commandStartTimes: [String: Date] = [:]
    
    public init(
        telemetryClient: TelemetryClient? = nil,
        configuration: CLIAnalyticsConfiguration = .default
    ) {
        self.telemetryClient = telemetryClient
        self.configuration = configuration
        self.sessionId = configuration.isEnabled && (!configuration.optInRequired || Self.hasUserConsent()) ? UUID().uuidString : nil
    }
    
    /// Check if user has provided consent for analytics
    private static func hasUserConsent() -> Bool {
        // Check environment variable first
        if let envConsent = ProcessInfo.processInfo.environment["ANIGMA_ANALYTICS_CONSENT"] {
            return envConsent.lowercased() == "true" || envConsent.lowercased() == "yes"
        }
        
        // Check user defaults
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "anigma.analytics.consent")
    }
    
    /// Record command execution start
    public func recordCommandStart(_ command: String) {
        guard configuration.isEnabled, Self.hasUserConsent() else { return }
        commandStartTimes[command] = Date()
        
        // Emit start event
        Task {
            _ = await telemetryClient?.emit(
                category: .performance,
                name: "cli.command_start",
                privacyClassification: .restricted,
                values: [
                    "command": .string(command),
                    "session_id": .string(sessionId ?? "anonymous")
                ]
            )
        }
    }
    
    /// Record command execution completion
    public func recordCommandCompletion(
        _ command: String,
        success: Bool,
        errorMessage: String? = nil,
        additionalMetrics: [String: TelemetryValue] = [:]
    ) async {
        guard configuration.isEnabled, Self.hasUserConsent() else { return }
        
        let startTime = commandStartTimes[command]
        let duration = startTime.map { Date().timeIntervalSince($0) * 1000 } ?? 0.0
        
        // Build metrics
        var values: [String: TelemetryValue] = [
            "command": .string(command),
            "success": .boolean(success),
            "duration_ms": .double(duration),
            "session_id": .string(sessionId ?? "anonymous")
        ]
        
        if let errorMessage = errorMessage {
            values["error_message"] = .string(errorMessage)
        }
        
        // Add additional metrics
        additionalMetrics.forEach { values[$0.key] = $0.value }
        
        // Emit completion event
        _ = await telemetryClient?.emit(
            category: .performance,
            name: "cli.command_completion",
            privacyClassification: .restricted,
            values: values
        )
        
        // Update metrics buffer
        await updateCommandMetrics(
            command: command,
            duration: duration,
            success: success,
            errorMessage: errorMessage
        )
        
        // Clean up
        commandStartTimes.removeValue(forKey: command)
    }
    
    /// Record performance metric
    public func recordPerformanceMetric(
        _ metricName: String,
        value: Double,
        unit: String? = nil,
        tags: [String: String] = [:]
    ) async {
        guard configuration.isEnabled, Self.hasUserConsent() else { return }
        
        var values: [String: TelemetryValue] = [
            "metric_name": .string(metricName),
            "value": .double(value),
            "session_id": .string(sessionId ?? "anonymous")
        ]
        
        if let unit = unit {
            values["unit"] = .string(unit)
        }
        
        tags.forEach { values["tag_\($0.key)"] = .string($0.value) }
        
        _ = await telemetryClient?.emit(
            category: .performance,
            name: "cli.performance_metric",
            privacyClassification: .restricted,
            values: values
        )
    }
    
    /// Record cache hit/miss
    public func recordCacheEvent(
        cacheType: String,
        hit: Bool,
        keyHash: String? = nil,
        sizeBytes: Int? = nil
    ) async {
        guard configuration.isEnabled, Self.hasUserConsent() else { return }
        
        var values: [String: TelemetryValue] = [
            "cache_type": .string(cacheType),
            "hit": .boolean(hit),
            "session_id": .string(sessionId ?? "anonymous")
        ]
        
        if let keyHash = keyHash {
            values["key_hash"] = .string(keyHash)
        }
        
        if let sizeBytes = sizeBytes {
            values["size_bytes"] = .integer(sizeBytes)
        }
        
        _ = await telemetryClient?.emit(
            category: .performance,
            name: "cli.cache_event",
            privacyClassification: .restricted,
            values: values
        )
    }
    
    /// Record daemon usage
    public func recordDaemonUsage(
        command: String,
        usedDaemon: Bool,
        fallbackReason: String? = nil,
        latencyMs: Double? = nil
    ) async {
        guard configuration.isEnabled, Self.hasUserConsent() else { return }
        
        var values: [String: TelemetryValue] = [
            "command": .string(command),
            "used_daemon": .boolean(usedDaemon),
            "session_id": .string(sessionId ?? "anonymous")
        ]
        
        if let fallbackReason = fallbackReason {
            values["fallback_reason"] = .string(fallbackReason)
        }
        
        if let latencyMs = latencyMs {
            values["latency_ms"] = .double(latencyMs)
        }
        
        _ = await telemetryClient?.emit(
            category: .performance,
            name: "cli.daemon_usage",
            privacyClassification: .restricted,
            values: values
        )
    }
    
    /// Record migration event
    public func recordMigrationEvent(
        phase: String,
        step: String,
        success: Bool,
        durationMs: Double? = nil,
        itemsProcessed: Int? = nil,
        errorMessage: String? = nil
    ) async {
        guard configuration.isEnabled, Self.hasUserConsent() else { return }
        
        var values: [String: TelemetryValue] = [
            "phase": .string(phase),
            "step": .string(step),
            "success": .boolean(success),
            "session_id": .string(sessionId ?? "anonymous")
        ]
        
        if let durationMs = durationMs {
            values["duration_ms"] = .double(durationMs)
        }
        
        if let itemsProcessed = itemsProcessed {
            values["items_processed"] = .integer(itemsProcessed)
        }
        
        if let errorMessage = errorMessage {
            values["error_message"] = .string(errorMessage)
        }
        
        _ = await telemetryClient?.emit(
            category: .workflow,
            name: "cli.migration_event",
            privacyClassification: .restricted,
            values: values
        )
    }
    
    /// Generate optimization insights from collected metrics
    public func generateOptimizationInsights() async -> [OptimizationInsight] {
        guard !metricsBuffer.isEmpty else { return [] }
        
        var insights: [OptimizationInsight] = []
        
        // Analyze command performance
        let commandGroups = Dictionary(grouping: metricsBuffer) { $0.commandName }
        
        for (command, metrics) in commandGroups {
            let avgDuration = metrics.map { $0.averageDurationMs }.reduce(0, +) / Double(metrics.count)
            let avgSuccessRate = metrics.map { $0.successRate }.reduce(0, +) / Double(metrics.count)
            
            // Identify slow commands
            if avgDuration > 1000 { // > 1 second
                insights.append(OptimizationInsight(
                    category: "performance",
                    description: "Command '\(command)' has average execution time of \(Int(avgDuration))ms",
                    impactScore: 0.7,
                    confidence: 0.8,
                    suggestedAction: "Consider caching, parallelization, or daemon optimization"
                ))
            }
            
            // Identify error-prone commands
            if avgSuccessRate < 0.9 { // < 90% success rate
                insights.append(OptimizationInsight(
                    category: "reliability",
                    description: "Command '\(command)' has success rate of \(Int(avgSuccessRate * 100))%",
                    impactScore: 0.9,
                    confidence: 0.85,
                    suggestedAction: "Investigate error patterns and improve error handling"
                ))
            }
        }
        
        return insights
    }
    
    /// Get aggregated command metrics
    public func getCommandMetrics() -> [CLICommandMetrics] {
        return metricsBuffer
    }
    
    /// Clear collected metrics (for privacy)
    public func clearMetrics() {
        metricsBuffer.removeAll()
        commandStartTimes.removeAll()
    }
    
    /// Update configuration
    public func updateConfiguration(_ newConfig: CLIAnalyticsConfiguration) {
        self.configuration = newConfig
        
        if !newConfig.isEnabled || (newConfig.optInRequired && !Self.hasUserConsent()) {
            clearMetrics()
        }
    }
    
    /// Export analytics data (anonymized)
    public func exportAnalyticsData() -> Data? {
        guard configuration.isEnabled, Self.hasUserConsent() else { return nil }
        
        let export = AnalyticsExport(
            sessionId: sessionId ?? "anonymous",
            metrics: metricsBuffer,
            configuration: configuration,
            timestamp: Date()
        )
        
        return try? JSONEncoder().encode(export)
    }
    
    // MARK: - Private Methods
    
    private func updateCommandMetrics(
        command: String,
        duration: Double,
        success: Bool,
        errorMessage: String?
    ) async {
        // Find existing metrics for this command
        if let index = metricsBuffer.firstIndex(where: { $0.commandName == command }) {
            let existing = metricsBuffer[index]
            
            // Update running averages
            let newCount = existing.executionCount + 1
            let newAvgDuration = (existing.averageDurationMs * Double(existing.executionCount) + duration) / Double(newCount)
            let newSuccessRate = existing.successRate * Double(existing.executionCount) / Double(newCount) + 
                                (success ? 1.0 : 0.0) / Double(newCount)
            let newErrorCount = existing.errorCount + (errorMessage != nil ? 1 : 0)
            
            metricsBuffer[index] = CLICommandMetrics(
                commandName: command,
                executionCount: newCount,
                averageDurationMs: newAvgDuration,
                successRate: newSuccessRate,
                errorCount: newErrorCount,
                cacheHitRate: existing.cacheHitRate,
                daemonUsageRate: existing.daemonUsageRate
            )
        } else {
            // Create new metrics entry
            metricsBuffer.append(CLICommandMetrics(
                commandName: command,
                executionCount: 1,
                averageDurationMs: duration,
                successRate: success ? 1.0 : 0.0,
                errorCount: errorMessage != nil ? 1 : 0,
                cacheHitRate: nil,
                daemonUsageRate: nil
            ))
        }
    }
}

/// Analytics export structure
private struct AnalyticsExport: Sendable, Codable {
    let sessionId: String
    let metrics: [CLICommandMetrics]
    let configuration: CLIAnalyticsConfiguration
    let timestamp: Date
}

/// Global analytics manager instance
public actor GlobalCLIAnalytics {
    private static var sharedManager: CLIAnalyticsManager?
    
    public static func initialize(
        telemetryClient: TelemetryClient? = nil,
        configuration: CLIAnalyticsConfiguration = .default
    ) {
        sharedManager = CLIAnalyticsManager(
            telemetryClient: telemetryClient,
            configuration: configuration
        )
    }
    
    public static func shared() -> CLIAnalyticsManager? {
        return sharedManager
    }
    
    public static func recordCommandStart(_ command: String) {
        Task {
            await sharedManager?.recordCommandStart(command)
        }
    }
    
    public static func recordCommandCompletion(
        _ command: String,
        success: Bool,
        errorMessage: String? = nil,
        additionalMetrics: [String: TelemetryValue] = [:]
    ) async {
        await sharedManager?.recordCommandCompletion(
            command,
            success: success,
            errorMessage: errorMessage,
            additionalMetrics: additionalMetrics
        )
    }
}

/// Convenience extensions for common analytics patterns
extension CLIAnalyticsManager {
    /// Record command execution with automatic timing
    public func withCommandAnalytics<T>(
        _ command: String,
        operation: () async throws -> T
    ) async throws -> T {
        recordCommandStart(command)
        
        do {
            let result = try await operation()
            await recordCommandCompletion(command, success: true)
            return result
        } catch {
            await recordCommandCompletion(
                command,
                success: false,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }
    
    /// Record performance of a block of code
    public func measurePerformance<T>(
        _ operationName: String,
        operation: () async throws -> T
    ) async throws -> T {
        let startTime = Date()
        
        do {
            let result = try await operation()
            let duration = Date().timeIntervalSince(startTime) * 1000
            
            await recordPerformanceMetric(
                "\(operationName)_duration",
                value: duration,
                unit: "ms"
            )
            
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            
            await recordPerformanceMetric(
                "\(operationName)_error_duration",
                value: duration,
                unit: "ms"
            )
            
            throw error
        }
    }
}
