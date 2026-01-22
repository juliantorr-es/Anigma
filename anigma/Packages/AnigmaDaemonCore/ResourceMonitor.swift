//
//  ResourceMonitor.swift
//  AnigmaDaemonCore
//
//  Resource monitoring and throttling for daemon process management.
//

import Foundation
import CDispatch

/// Resource usage thresholds for monitoring
public struct ResourceThresholds {
    public let maxMemoryMB: UInt64
    public let maxCPUPercent: Double
    public let maxDiskUsagePercent: Double
    public let maxThreadCount: UInt32
    public let memoryWarningThreshold: Double
    public let cpuWarningThreshold: Double
    
    public init(
        maxMemoryMB: UInt64 = 2048,
        maxCPUPercent: Double = 80.0,
        maxDiskUsagePercent: Double = 90.0,
        maxThreadCount: UInt32 = 100,
        memoryWarningThreshold: Double = 0.8,
        cpuWarningThreshold: Double = 0.7
    ) {
        self.maxMemoryMB = maxMemoryMB
        self.maxCPUPercent = maxCPUPercent
        self.maxDiskUsagePercent = maxDiskUsagePercent
        self.maxThreadCount = maxThreadCount
        self.memoryWarningThreshold = memoryWarningThreshold
        self.cpuWarningThreshold = cpuWarningThreshold
    }
}

/// Resource monitoring event
public enum ResourceEvent {
    case memoryWarning(usage: UInt64, threshold: UInt64)
    case cpuWarning(usage: Double, threshold: Double)
    case diskWarning(usage: Double, threshold: Double)
    case threadWarning(count: UInt32, threshold: UInt32)
    case memoryCritical(usage: UInt64, threshold: UInt64)
    case cpuCritical(usage: Double, threshold: Double)
    case resourceUsageNormal
}

/// Monitors system resources and triggers throttling when thresholds are exceeded
public actor ResourceMonitor {
    
    private let thresholds: ResourceThresholds
    private let monitoringInterval: TimeInterval
    private var monitoringTask: Task<Void, Never>?
    private var eventHandlers: [(ResourceEvent) async -> Void] = []
    
    // Resource state tracking
    private var currentMemoryUsage: UInt64 = 0
    private var currentCPUUsage: Double = 0.0
    private var currentDiskUsage: Double = 0.0
    private var currentThreadCount: UInt32 = 0
    
    // Historical data for trend analysis
    private var memoryHistory: [UInt64] = []
    private var cpuHistory: [Double] = []
    private let maxHistorySize = 60 // Keep 60 data points
    
    // Throttling state
    private var isThrottlingEnabled: Bool = false
    private var throttleStartTime: Date?
    private var throttleDuration: TimeInterval = 300 // 5 minutes
    
    public init(
        thresholds: ResourceThresholds = ResourceThresholds(),
        monitoringInterval: TimeInterval = 10.0 // Check every 10 seconds
    ) {
        self.thresholds = thresholds
        self.monitoringInterval = monitoringInterval
    }
    
    /// Start resource monitoring
    public func startMonitoring() {
        guard monitoringTask == nil else { return }
        
        monitoringTask = Task {
            await runMonitoringLoop()
        }
    }
    
    /// Stop resource monitoring
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    /// Register an event handler
    public func registerEventHandler(_ handler: @escaping (ResourceEvent) async -> Void) {
        eventHandlers.append(handler)
    }
    
    /// Get current resource usage
    public func getCurrentUsage() -> ResourceUsage {
        return ResourceUsage(
            memoryUsage: currentMemoryUsage,
            cpuUsage: currentCPUUsage,
            diskUsage: currentDiskUsage,
            threadCount: currentThreadCount,
            isThrottling: isThrottlingEnabled
        )
    }
    
    /// Get resource usage trends
    public func getUsageTrends() -> ResourceTrends {
        return ResourceTrends(
            memoryTrend: calculateTrend(memoryHistory),
            cpuTrend: calculateTrend(cpuHistory),
            averageMemory: memoryHistory.isEmpty ? 0 : Double(memoryHistory.reduce(0, +)) / Double(memoryHistory.count),
            averageCPU: cpuHistory.isEmpty ? 0 : cpuHistory.reduce(0, +) / Double(cpuHistory.count)
        )
    }
    
    /// Force resource cleanup
    public func performCleanup() async {
        await triggerMemoryCleanup()
        
        // Send normal usage event
        await emitEvent(.resourceUsageNormal)
    }
    
    // MARK: - Private Methods
    
    private func runMonitoringLoop() async {
        while !Task.isCancelled {
            await collectResourceMetrics()
            await checkThresholds()
            await updateHistory()
            
            // Check if we can stop throttling
            if isThrottlingEnabled {
                await checkThrottleTimeout()
            }
            
            try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
        }
    }
    
    private func collectResourceMetrics() async {
        // Collect memory usage
        currentMemoryUsage = await getMemoryUsage()
        
        // Collect CPU usage
        currentCPUUsage = await getCPUUsage()
        
        // Collect disk usage
        currentDiskUsage = await getDiskUsage()
        
        // Collect thread count
        currentThreadCount = await getThreadCount()
    }
    
    private func checkThresholds() async {
        let maxMemoryBytes = thresholds.maxMemoryMB * 1024 * 1024
        
        // Check memory thresholds
        if currentMemoryUsage > maxMemoryBytes {
            await emitEvent(.memoryCritical(usage: currentMemoryUsage, threshold: maxMemoryBytes))
            await enableThrottling()
        } else if currentMemoryUsage > maxMemoryBytes * thresholds.memoryWarningThreshold {
            await emitEvent(.memoryWarning(usage: currentMemoryUsage, threshold: maxMemoryBytes))
        }
        
        // Check CPU thresholds
        if currentCPUUsage > thresholds.maxCPUPercent {
            await emitEvent(.cpuCritical(usage: currentCPUUsage, threshold: thresholds.maxCPUPercent))
            await enableThrottling()
        } else if currentCPUUsage > thresholds.maxCPUPercent * thresholds.cpuWarningThreshold {
            await emitEvent(.cpuWarning(usage: currentCPUUsage, threshold: thresholds.maxCPUPercent))
        }
        
        // Check disk thresholds
        if currentDiskUsage > thresholds.maxDiskUsagePercent {
            await emitEvent(.diskWarning(usage: currentDiskUsage, threshold: thresholds.maxDiskUsagePercent))
        }
        
        // Check thread count
        if currentThreadCount > thresholds.maxThreadCount {
            await emitEvent(.threadWarning(count: currentThreadCount, threshold: thresholds.maxThreadCount))
        }
        
        // Check if usage is back to normal
        if currentMemoryUsage < maxMemoryBytes * thresholds.memoryWarningThreshold * 0.8 &&
           currentCPUUsage < thresholds.maxCPUPercent * thresholds.cpuWarningThreshold * 0.8 {
            await emitEvent(.resourceUsageNormal)
            await disableThrottling()
        }
    }
    
    private func updateHistory() async {
        memoryHistory.append(currentMemoryUsage)
        cpuHistory.append(currentCPUUsage)
        
        // Keep history size limited
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }
        if cpuHistory.count > maxHistorySize {
            cpuHistory.removeFirst()
        }
    }
    
    private func enableThrottling() async {
        if !isThrottlingEnabled {
            isThrottlingEnabled = true
            throttleStartTime = Date()
            print("⚠️  Resource throttling enabled due to high resource usage")
        }
    }
    
    private func disableThrottling() async {
        if isThrottlingEnabled {
            isThrottlingEnabled = false
            throttleStartTime = nil
            print("✅ Resource throttling disabled - usage back to normal")
        }
    }
    
    private func checkThrottleTimeout() async {
        guard let startTime = throttleStartTime else { return }
        
        if Date().timeIntervalSince(startTime) > throttleDuration {
            await disableThrottling()
        }
    }
    
    private func emitEvent(_ event: ResourceEvent) async {
        for handler in eventHandlers {
            await handler(event)
        }
    }
    
    // MARK: - Resource Collection Methods
    
    private func getMemoryUsage() async -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getCPUUsage() async -> Double {
        // Get current CPU times
        var info = processor_info_array_t(bitPattern: 0)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCpus,
            &info,
            &numCpuInfo
        )
        
        guard result == KERN_SUCCESS,
              let cpuInfo = info else { return 0.0 }
        
        defer {
            vm_deallocate(mach_task_self(), vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))
        }
        
        // Calculate CPU usage from user, system, and idle times
        var totalUser: UInt32 = 0
        var totalSystem: UInt32 = 0
        var totalIdle: UInt32 = 0
        
        for i in 0..<Int(numCpus) {
            let base = i * Int32(MemoryLayout<processor_cpu_load_info>.size) / Int32(MemoryLayout<integer_t>.size)
            totalUser += cpuInfo[Int(base) + CPU_STATE_USER]
            totalSystem += cpuInfo[Int(base) + CPU_STATE_SYSTEM]
            totalIdle += cpuInfo[Int(base) + CPU_STATE_IDLE]
        }
        
        let totalTicks = totalUser + totalSystem + totalIdle
        let usedTicks = totalUser + totalSystem
        
        return totalTicks > 0 ? Double(usedTicks) / Double(totalTicks) * 100.0 : 0.0
    }
    
    private func getDiskUsage() async -> Double {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentsPath.path)
            let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
            let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
            
            return totalSpace > 0 ? Double(totalSpace - freeSpace) / Double(totalSpace) * 100.0 : 0.0
        } catch {
            return 0.0
        }
    }
    
    private func getThreadCount() async -> UInt32 {
        var threadList: thread_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self(), &threadList, &threadCount)
        
        defer {
            if result == KERN_SUCCESS {
                vm_deallocate(mach_task_self(), vm_address_t(bitPattern: threadList), vm_size_t(threadCount))
            }
        }
        
        return result == KERN_SUCCESS ? threadCount : 0
    }
    
    private func triggerMemoryCleanup() async {
        // Force garbage collection
        autoreleasepool {
            // Cleanup autorelease pool
        }
        
        // Signal to worker pools to reduce activity
        // This would be integrated with the actual worker pool
    }
    
    private func calculateTrend<T: Numeric>(_ values: [T]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        
        // Simple linear regression to detect trend
        let n = Double(values.count)
        let x = Array(0..<values.count).map { Double($0) }
        let y = values.map { Double($0 as! Int) }
        
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        
        return slope
    }
}

// MARK: - Supporting Types

/// Current resource usage snapshot
public struct ResourceUsage {
    public let memoryUsage: UInt64
    public let cpuUsage: Double
    public let diskUsage: Double
    public let threadCount: UInt32
    public let isThrottling: Bool
    
    public var memoryUsageMB: Double {
        return Double(memoryUsage) / (1024 * 1024)
    }
}

/// Resource usage trends over time
public struct ResourceTrends {
    public let memoryTrend: Double // Positive = increasing, Negative = decreasing
    public let cpuTrend: Double
    public let averageMemory: Double
    public let averageCPU: Double
}

// CPU state constants
let CPU_STATE_USER = 0
let CPU_STATE_SYSTEM = 1
let CPU_STATE_IDLE = 2
let CPU_STATE_NICE = 3