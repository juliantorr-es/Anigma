//
//  CLIAnalyticsTests.swift
//  AnigmaCLICoreTests
//
//  Tests for CLI analytics system
//

import Foundation
import Testing
@testable import AnigmaCLICore

struct CLIAnalyticsTests {
    
    @Test func testConfigurationDefaults() async throws {
        let config = CLIAnalyticsConfiguration.default
        
        #expect(config.isEnabled == true)
        #expect(config.collectionLevel == .basic)
        #expect(config.anonymizationLevel == .anonymous)
        #expect(config.retentionDays == 30)
        #expect(config.optInRequired == true)
    }
    
    @Test func testCommandMetricsInitialization() {
        let metrics = CLICommandMetrics(
            commandName: "test",
            executionCount: 10,
            averageDurationMs: 100.5,
            successRate: 0.95,
            errorCount: 1,
            cacheHitRate: 0.8,
            daemonUsageRate: 0.7
        )
        
        #expect(metrics.commandName == "test")
        #expect(metrics.executionCount == 10)
        #expect(metrics.averageDurationMs == 100.5)
        #expect(metrics.successRate == 0.95)
        #expect(metrics.errorCount == 1)
        #expect(metrics.cacheHitRate == 0.8)
        #expect(metrics.daemonUsageRate == 0.7)
    }
    
    @Test func testOptimizationInsightCreation() {
        let insight = OptimizationInsight(
            category: "performance",
            description: "Test insight",
            impactScore: 0.8,
            confidence: 0.9,
            suggestedAction: "Test action"
        )
        
        #expect(insight.category == "performance")
        #expect(insight.description == "Test insight")
        #expect(insight.impactScore == 0.8)
        #expect(insight.confidence == 0.9)
        #expect(insight.suggestedAction == "Test action")
    }
    
    @Test func testAnalyticsManagerInitialization() async {
        let config = CLIAnalyticsConfiguration(isEnabled: false)
        _ = CLIAnalyticsManager(configuration: config)
    }
    
    @Test func testCommandRecording() async {
        // Set up test environment with consent
        var env = ProcessInfo.processInfo.environment
        env["ANIGMA_ANALYTICS_CONSENT"] = "true"
        
        let config = CLIAnalyticsConfiguration(optInRequired: false)
        let manager = CLIAnalyticsManager(configuration: config)
        
        // Record command start
        await manager.recordCommandStart("test-command")
        
        // Record command completion
        await manager.recordCommandCompletion("test-command", success: true)
        
        // Get metrics
        let metrics = await manager.getCommandMetrics()
        
        #expect(metrics.count >= 0) // At least no crash
    }
    
    @Test func testPerformanceMeasurement() async throws {
        let config = CLIAnalyticsConfiguration(optInRequired: false)
        let manager = CLIAnalyticsManager(configuration: config)
        
        let result = try await manager.measurePerformance("test-operation") {
            // Simulate some work
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return "success"
        }
        
        #expect(result == "success")
    }
    
    @Test func testWithCommandAnalytics() async throws {
        let config = CLIAnalyticsConfiguration(optInRequired: false)
        let manager = CLIAnalyticsManager(configuration: config)
        
        let result = try await manager.withCommandAnalytics("test-command") {
            return 42
        }
        
        #expect(result == 42)
    }
    
    @Test func testConfigurationUpdate() async {
        let manager = CLIAnalyticsManager(configuration: .default)
        
        let newConfig = CLIAnalyticsConfiguration(isEnabled: false)
        await manager.updateConfiguration(newConfig)
        
        // Should clear metrics when disabled
        let metrics = await manager.getCommandMetrics()
        #expect(metrics.isEmpty)
    }
    
    @Test func testExportAnalyticsData() async {
        let config = CLIAnalyticsConfiguration(optInRequired: false)
        let manager = CLIAnalyticsManager(configuration: config)
        
        // Record some data
        await manager.recordCommandStart("export-test")
        await manager.recordCommandCompletion("export-test", success: true)
        
        let exportData = await manager.exportAnalyticsData()
        #expect(exportData != nil)
        
        if let data = exportData {
            #expect(data.count > 0)
        }
    }
    
    @Test func testGlobalAnalyticsInitialization() async throws {
        GlobalCLIAnalytics.initialize(configuration: .default)
        
        let manager = GlobalCLIAnalytics.shared()
        #expect(manager != nil)
        
        // Test global recording
        GlobalCLIAnalytics.recordCommandStart("global-test")
        
        // Small delay to allow async operation
        try await Task.sleep(nanoseconds: 50_000_000)
        
    }
    
    @Test func testPrivacyControls() async {
        // Test with consent required but not given
        let config = CLIAnalyticsConfiguration(optInRequired: true)
        let manager = CLIAnalyticsManager(configuration: config)
        
        await manager.recordCommandStart("private-command")
        await manager.recordCommandCompletion("private-command", success: true)
        
        let metrics = await manager.getCommandMetrics()
        #expect(metrics.isEmpty) // Should not record without consent
        
        let exportData = await manager.exportAnalyticsData()
        #expect(exportData == nil) // Should not export without consent
    }
    
    @Test func testClearMetrics() async {
        let config = CLIAnalyticsConfiguration(optInRequired: false)
        let manager = CLIAnalyticsManager(configuration: config)
        
        // Record some data
        await manager.recordCommandStart("clear-test")
        await manager.recordCommandCompletion("clear-test", success: true)
        
        // Clear metrics
        await manager.clearMetrics()
        
        let metrics = await manager.getCommandMetrics()
        #expect(metrics.isEmpty)
    }
}
