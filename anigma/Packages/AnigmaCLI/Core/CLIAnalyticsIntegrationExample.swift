//
//  CLIAnalyticsIntegrationExample.swift
//  AnigmaCLICore
//
//  Example integration of CLI analytics with existing commands
//

import Foundation
import TelemetryCore

/// Example: Enhanced CLI command with analytics
public actor AnalyticsEnhancedCommand {
    private let analyticsManager: CLIAnalyticsManager
    
    public init(analyticsManager: CLIAnalyticsManager) {
        self.analyticsManager = analyticsManager
    }
    
    /// Example command with full analytics integration
    public func executeEnhancedCommand(
        _ command: String,
        arguments: [String] = []
    ) async throws -> String {
        // Record command start
        await analyticsManager.recordCommandStart(command)
        
        // Measure performance of the entire operation
        let result = try await analyticsManager.measurePerformance("\(command)_execution") {
            // Simulate command execution
            try await simulateCommandExecution(command, arguments: arguments)
        }
        
        // Record command completion with success
        await analyticsManager.recordCommandCompletion(command, success: true)
        
        return result
    }
    
    /// Example with daemon usage tracking
    public func executeWithDaemonTracking(
        _ command: String,
        useDaemon: Bool
    ) async throws -> String {
        let startTime = Date()
        
        do {
            let result: String
            let fallbackReason: String?
            
            if useDaemon {
                // Try daemon execution
                do {
                    result = try await executeViaDaemon(command)
                    fallbackReason = nil
                } catch {
                    // Fallback to local execution
                    result = try await executeLocally(command)
                    fallbackReason = error.localizedDescription
                }
            } else {
                result = try await executeLocally(command)
                fallbackReason = nil
            }
            
            let latency = Date().timeIntervalSince(startTime) * 1000
            
            // Record daemon usage
            await analyticsManager.recordDaemonUsage(
                command: command,
                usedDaemon: useDaemon,
                fallbackReason: fallbackReason,
                latencyMs: latency
            )
            
            // Record command completion
            await analyticsManager.recordCommandCompletion(command, success: true)
            
            return result
        } catch {
            let latency = Date().timeIntervalSince(startTime) * 1000
            
            // Record daemon usage even on error
            await analyticsManager.recordDaemonUsage(
                command: command,
                usedDaemon: useDaemon,
                fallbackReason: error.localizedDescription,
                latencyMs: latency
            )
            
            // Record command completion with error
            await analyticsManager.recordCommandCompletion(
                command,
                success: false,
                errorMessage: error.localizedDescription
            )
            
            throw error
        }
    }
    
    /// Example with cache performance tracking
    public func executeWithCacheTracking(
        _ command: String,
        cacheKey: String
    ) async throws -> String {
        let cacheType = "command_cache"
        let keyHash = String(cacheKey.hashValue)
        
        // Check cache
        if let cached = await checkCache(cacheKey) {
            // Record cache hit
            await analyticsManager.recordCacheEvent(
                cacheType: cacheType,
                hit: true,
                keyHash: keyHash
            )
            return cached
        }
        
        // Record cache miss
        await analyticsManager.recordCacheEvent(
            cacheType: cacheType,
            hit: false,
            keyHash: keyHash
        )
        
        // Execute command
        let result = try await executeEnhancedCommand(command)
        
        // Store in cache
        await storeInCache(cacheKey, value: result)
        
        return result
    }
    
    /// Example migration tracking
    public func executeMigrationWithAnalytics(
        phase: String,
        steps: [String]
    ) async throws -> MigrationResult {
        var successfulSteps = 0
        var totalDuration: Double = 0
        
        for step in steps {
            let stepStart = Date()
            
            do {
                try await executeMigrationStep(step)
                let stepDuration = Date().timeIntervalSince(stepStart) * 1000
                
                // Record successful migration step
                await analyticsManager.recordMigrationEvent(
                    phase: phase,
                    step: step,
                    success: true,
                    durationMs: stepDuration,
                    itemsProcessed: 1
                )
                
                successfulSteps += 1
                totalDuration += stepDuration
            } catch {
                let stepDuration = Date().timeIntervalSince(stepStart) * 1000
                
                // Record failed migration step
                await analyticsManager.recordMigrationEvent(
                    phase: phase,
                    step: step,
                    success: false,
                    durationMs: stepDuration,
                    errorMessage: error.localizedDescription
                )
                
                throw error
            }
        }
        
        return MigrationResult(
            phase: phase,
            successfulSteps: successfulSteps,
            totalSteps: steps.count,
            totalDurationMs: totalDuration
        )
    }
    
    /// Generate and display optimization insights
    public func displayOptimizationInsights() async {
        let insights = await analyticsManager.generateOptimizationInsights()
        
        if insights.isEmpty {
            print("No optimization insights available yet.")
            print("Run more commands to generate insights.")
            return
        }
        
        print("Optimization Insights:")
        print("=====================")
        
        for (index, insight) in insights.enumerated() {
            print("\n\(index + 1). \(insight.category.uppercased())")
            print("   Description: \(insight.description)")
            print("   Impact Score: \(String(format: "%.1f", insight.impactScore)) / 1.0")
            print("   Confidence: \(String(format: "%.0f", insight.confidence * 100))%")
            print("   Suggested Action: \(insight.suggestedAction)")
        }
        
        // Sort by impact score
        let topInsights = insights.sorted { $0.impactScore > $1.impactScore }
        
        if let topInsight = topInsights.first {
            print("\nTop Recommendation:")
            print("-------------------")
            print("\(topInsight.suggestedAction)")
            print("(Impact: \(String(format: "%.0f", topInsight.impactScore * 100))%, Confidence: \(String(format: "%.0f", topInsight.confidence * 100))%)")
        }
    }
    
    /// Export analytics report
    public func exportAnalyticsReport() async throws -> URL {
        guard let data = await analyticsManager.exportAnalyticsData() else {
            throw AnalyticsError.noDataAvailable
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "anigma-analytics-\(timestamp).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        try data.write(to: url)
        return url
    }
    
    // MARK: - Private Methods
    
    private func simulateCommandExecution(_ command: String, arguments: [String]) async throws -> String {
        // Simulate some work
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Simulate occasional errors
        if command == "error-prone" && Bool.random() {
            throw CommandError.simulationError("Simulated error for testing")
        }
        
        return "Result for \(command) with args: \(arguments.joined(separator: " "))"
    }
    
    private func executeViaDaemon(_ command: String) async throws -> String {
        // Simulate daemon execution
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Simulate occasional daemon errors
        if Bool.random(withProbability: 0.1) {
            throw DaemonError.connectionFailed("Simulated daemon connection error")
        }
        
        return "Daemon result for \(command)"
    }
    
    private func executeLocally(_ command: String) async throws -> String {
        // Simulate local execution (usually slower)
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        return "Local result for \(command)"
    }
    
    private func checkCache(_ key: String) async -> String? {
        // Simulate cache check
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // 50% cache hit rate for simulation
        return Bool.random() ? "Cached value for \(key)" : nil
    }
    
    private func storeInCache(_ key: String, value: String) async {
        // Simulate cache storage
        try? await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds
    }
    
    private func executeMigrationStep(_ step: String) async throws {
        // Simulate migration step
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Simulate occasional step failure
        if step == "risky-step" && Bool.random(withProbability: 0.2) {
            throw MigrationError.stepFailed("Simulated migration step failure")
        }
    }
}

// MARK: - Supporting Types

public struct MigrationResult: Sendable {
    public let phase: String
    public let successfulSteps: Int
    public let totalSteps: Int
    public let totalDurationMs: Double
    
    public var successRate: Double {
        Double(successfulSteps) / Double(totalSteps)
    }
}

public enum CommandError: Error, Sendable {
    case simulationError(String)
}

public enum DaemonError: Error, Sendable {
    case connectionFailed(String)
}

public enum MigrationError: Error, Sendable {
    case stepFailed(String)
}

public enum AnalyticsError: Error, Sendable {
    case noDataAvailable
}

// MARK: - Utility Extensions

extension Bool {
    static func random(withProbability probability: Double) -> Bool {
        Double.random(in: 0...1) < probability
    }
}

// MARK: - Usage Example

public struct CLIAnalyticsUsageExample {
    public static func demonstrate() async {
        print("CLI Analytics System Demo")
        print("========================")
        
        // Initialize analytics manager
        let config = CLIAnalyticsConfiguration(
            isEnabled: true,
            collectionLevel: .detailed,
            anonymizationLevel: .anonymous,
            optInRequired: false
        )
        
        let analyticsManager = CLIAnalyticsManager(configuration: config)
        let enhancedCommand = AnalyticsEnhancedCommand(analyticsManager: analyticsManager)
        
        // Execute commands with analytics
        do {
            print("\n1. Executing basic command with analytics...")
            let result1 = try await enhancedCommand.executeEnhancedCommand("plan", arguments: ["--verbose"])
            print("   Result: \(result1)")
            
            print("\n2. Executing command with daemon tracking...")
            let result2 = try await enhancedCommand.executeWithDaemonTracking("run", useDaemon: true)
            print("   Result: \(result2)")
            
            print("\n3. Executing command with cache tracking...")
            let result3 = try await enhancedCommand.executeWithCacheTracking("search", cacheKey: "query:test")
            print("   Result: \(result3)")
            
            print("\n4. Executing migration with analytics...")
            let migrationResult = try await enhancedCommand.executeMigrationWithAnalytics(
                phase: "phase-2",
                steps: ["backup", "migrate-data", "validate", "cleanup"]
            )
            print("   Migration completed: \(migrationResult.successfulSteps)/\(migrationResult.totalSteps) steps")
            print("   Success rate: \(String(format: "%.1f", migrationResult.successRate * 100))%")
            print("   Total duration: \(String(format: "%.1f", migrationResult.totalDurationMs))ms")
            
            print("\n5. Generating optimization insights...")
            await enhancedCommand.displayOptimizationInsights()
            
            print("\n6. Exporting analytics data...")
            let exportURL = try await enhancedCommand.exportAnalyticsReport()
            print("   Exported to: \(exportURL.path)")
            
        } catch {
            print("Error during demo: \(error)")
        }
        
        print("\nDemo completed!")
    }
}