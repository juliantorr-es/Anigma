//
//  ASTWorkerMetrics.swift
//  AnigmaASTServices
//
//  Performance metrics collection for AST worker operations.
//

import Foundation

// MARK: - Metrics Collector

/// Collects performance metrics for AST operations
class ASTWorkerMetricsCollector {
    private var operationMetrics: [String: OperationMetrics] = [:]
    private let lock = NSLock()
    private var operationCount = 0
    
    struct OperationMetrics {
        let operationId: String
        let task: ASTTaskKind
        var startTime: Date?
        var endTime: Date?
        var filesProcessed: Int?
        var nodesProcessed: Int?
        var cacheHits: Int?
        var cacheMisses: Int?
        var memoryUsed: Int?
        var success: Bool?
        
        var duration: TimeInterval? {
            guard let start = startTime, let end = endTime else { return nil }
            return end.timeIntervalSince(start)
        }
        
        var cacheHitRate: Double? {
            guard let hits = cacheHits, let misses = cacheMisses else { return nil }
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : nil
        }
    }
    
    func startOperation(operationId: String, task: ASTTaskKind, fileCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        operationMetrics[operationId] = OperationMetrics(
            operationId: operationId,
            task: task,
            startTime: Date()
        )
    }
    
    func endOperation(
        operationId: String,
        success: Bool,
        filesProcessed: Int? = nil,
        nodesProcessed: Int? = nil,
        cacheHits: Int? = nil,
        cacheMisses: Int? = nil,
        memoryUsed: Int? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        guard var metrics = operationMetrics[operationId] else { return }
        metrics.endTime = Date()
        metrics.success = success
        metrics.filesProcessed = filesProcessed
        metrics.nodesProcessed = nodesProcessed
        metrics.cacheHits = cacheHits
        metrics.cacheMisses = cacheMisses
        metrics.memoryUsed = memoryUsed
        operationMetrics[operationId] = metrics
        
        // Log metrics
        logMetrics(metrics)
        
        operationCount += 1
        if operationCount % 10 == 0 {
            logCacheStatistics()
        }
    }
    
    private func logMetrics(_ metrics: OperationMetrics) {
        let durationStr = metrics.duration.map { String(format: "%.2fms", $0 * 1000) } ?? "N/A"
        let hitRateStr = metrics.cacheHitRate.map { String(format: "%.1f%%", $0 * 100) } ?? "N/A"
        
        print("[ASTWorkerMetrics] \(metrics.task.rawValue): \(durationStr), files: \(metrics.filesProcessed ?? 0), cache: \(hitRateStr), success: \(metrics.success ?? false)")
    }
    
    func logCacheStatistics() {
        // Aggregate cache statistics across all operations
        var totalHits = 0
        var totalMisses = 0
        var taskStats: [String: (hits: Int, misses: Int)] = [:]
        
        for metrics in operationMetrics.values {
            if let hits = metrics.cacheHits, let misses = metrics.cacheMisses {
                totalHits += hits
                totalMisses += misses
                
                let taskKey = metrics.task.rawValue
                var stats = taskStats[taskKey] ?? (0, 0)
                stats.hits += hits
                stats.misses += misses
                taskStats[taskKey] = stats
            }
        }
        
        let totalOps = totalHits + totalMisses
        let overallHitRate = totalOps > 0 ? Double(totalHits) / Double(totalOps) * 100 : 0
        
        print("[ASTWorkerCache] Overall: hits=\(totalHits), misses=\(totalMisses), hitRate=\(String(format: "%.1f", overallHitRate))%")
        
        for (task, stats) in taskStats {
            let taskTotal = stats.hits + stats.misses
            let taskHitRate = taskTotal > 0 ? Double(stats.hits) / Double(taskTotal) * 100 : 0
            print("[ASTWorkerCache] \(task): hits=\(stats.hits), misses=\(stats.misses), hitRate=\(String(format: "%.1f", taskHitRate))%")
        }
    }
    
    func getMetricsSummary() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        
        var summary: [String: Any] = [:]
        var taskStats: [String: [String: Any]] = [:]
        
        for metrics in operationMetrics.values {
            let taskKey = metrics.task.rawValue
            var taskStat = taskStats[taskKey] ?? [
                "count": 0,
                "totalDuration": 0.0,
                "successCount": 0,
                "totalFiles": 0,
                "totalNodes": 0
            ]
            
            taskStat["count"] = (taskStat["count"] as? Int ?? 0) + 1
            
            if let duration = metrics.duration {
                taskStat["totalDuration"] = (taskStat["totalDuration"] as? Double ?? 0.0) + duration
            }
            
            if metrics.success == true {
                taskStat["successCount"] = (taskStat["successCount"] as? Int ?? 0) + 1
            }
            
            if let files = metrics.filesProcessed {
                taskStat["totalFiles"] = (taskStat["totalFiles"] as? Int ?? 0) + files
            }
            
            if let nodes = metrics.nodesProcessed {
                taskStat["totalNodes"] = (taskStat["totalNodes"] as? Int ?? 0) + nodes
            }
            
            taskStats[taskKey] = taskStat
        }
        
        // Compute averages
        for (taskKey, var taskStat) in taskStats {
            let count = taskStat["count"] as? Int ?? 1
            let totalDuration = taskStat["totalDuration"] as? Double ?? 0.0
            let totalFiles = taskStat["totalFiles"] as? Int ?? 0
            let totalNodes = taskStat["totalNodes"] as? Int ?? 0
            
            taskStat["avgDuration"] = totalDuration / Double(count)
            taskStat["avgFilesPerOp"] = Double(totalFiles) / Double(count)
            taskStat["avgNodesPerOp"] = Double(totalNodes) / Double(count)
            
            taskStats[taskKey] = taskStat
        }
        
        summary["tasks"] = taskStats
        summary["totalOperations"] = operationMetrics.count
        summary["cacheEntries"] = 0 // TODO: Get from SwiftAstLens
        
        return summary
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        operationMetrics.removeAll()
        operationCount = 0
    }
}

// MARK: - Performance Utilities

/// Performance measurement utilities
struct ASTPerformance {
    /// Measure execution time of a block
    static func measure<T>(_ name: String, _ block: () throws -> T) rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            print("[ASTPerformance] \(name): \(String(format: "%.2f", duration * 1000))ms")
        }
        return try block()
    }
    
    /// Measure async execution time
    static func measureAsync<T>(_ name: String, _ block: () async throws -> T) async rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            print("[ASTPerformance] \(name): \(String(format: "%.2f", duration * 1000))ms")
        }
        return try await block()
    }
    
    /// Get current memory usage in bytes
    static func currentMemoryUsage() -> Int? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        return Int(info.resident_size)
    }
}