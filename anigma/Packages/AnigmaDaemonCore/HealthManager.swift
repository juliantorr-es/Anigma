//
//  HealthManager.swift
//  AnigmaDaemonCore
//
//  Comprehensive health monitoring and metrics collection for the daemon.
//

import Foundation
import CDispatch

/// Detailed health information about the daemon
public struct DaemonHealth: Codable {
    public let status: HealthStatus
    public let uptime: TimeInterval
    public let processInfo: ProcessInfo
    public let memoryInfo: MemoryInfo
    public let jobQueueStats: JobQueueStats
    public let workerPoolStats: WorkerPoolStats
    public let httpServerStats: HTTPServerStats
    public let systemInfo: SystemInfo
    public let lastUpdated: Date
    
    public init(
        status: HealthStatus,
        uptime: TimeInterval,
        processInfo: ProcessInfo,
        memoryInfo: MemoryInfo,
        jobQueueStats: JobQueueStats,
        workerPoolStats: WorkerPoolStats,
        httpServerStats: HTTPServerStats,
        systemInfo: SystemInfo
    ) {
        self.status = status
        self.uptime = uptime
        self.processInfo = processInfo
        self.memoryInfo = memoryInfo
        self.jobQueueStats = jobQueueStats
        self.workerPoolStats = workerPoolStats
        self.httpServerStats = httpServerStats
        self.systemInfo = systemInfo
        self.lastUpdated = Date()
    }
}

/// Health status of the daemon
public enum HealthStatus: String, Codable {
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
    case unknown = "unknown"
}

/// Process information
public struct ProcessInfo: Codable {
    public let pid: pid_t
    public let ppid: pid_t
    public let uid: uid_t
    public let gid: gid_t
    public let executablePath: String
    public let startTime: Date
    
    public init(pid: pid_t, ppid: pid_t, uid: uid_t, gid: gid_t, executablePath: String, startTime: Date) {
        self.pid = pid
        self.ppid = ppid
        self.uid = uid
        self.gid = gid
        self.executablePath = executablePath
        self.startTime = startTime
    }
}

/// Memory usage information
public struct MemoryInfo: Codable {
    public let residentSize: UInt64        // RSS in bytes
    public let virtualSize: UInt64         // Virtual memory in bytes
    public let peakResidentSize: UInt64    // Peak RSS
    public let pageSize: UInt64            // System page size
    public let threadCount: UInt32         // Number of threads
    
    public init(residentSize: UInt64, virtualSize: UInt64, peakResidentSize: UInt64, pageSize: UInt64, threadCount: UInt32) {
        self.residentSize = residentSize
        self.virtualSize = virtualSize
        self.peakResidentSize = peakResidentSize
        self.pageSize = pageSize
        self.threadCount = threadCount
    }
}

/// Job queue statistics
public struct JobQueueStats: Codable {
    public let totalJobs: Int
    public let pendingJobs: Int
    public let runningJobs: Int
    public let completedJobs: Int
    public let failedJobs: Int
    public let averageProcessingTime: TimeInterval
    public let oldestPendingJob: Date?
    
    public init(totalJobs: Int, pendingJobs: Int, runningJobs: Int, completedJobs: Int, failedJobs: Int, averageProcessingTime: TimeInterval, oldestPendingJob: Date?) {
        self.totalJobs = totalJobs
        self.pendingJobs = pendingJobs
        self.runningJobs = runningJobs
        self.completedJobs = completedJobs
        self.failedJobs = failedJobs
        self.averageProcessingTime = averageProcessingTime
        self.oldestPendingJob = oldestPendingJob
    }
}

/// Worker pool statistics
public struct WorkerPoolStats: Codable {
    public let totalWorkers: Int
    public let activeWorkers: Int
    public let idleWorkers: Int
    public let maxWorkers: Int
    public let averageExecutionTime: TimeInterval
    public let totalExecutions: UInt64
    
    public init(totalWorkers: Int, activeWorkers: Int, idleWorkers: Int, maxWorkers: Int, averageExecutionTime: TimeInterval, totalExecutions: UInt64) {
        self.totalWorkers = totalWorkers
        self.activeWorkers = activeWorkers
        self.idleWorkers = idleWorkers
        self.maxWorkers = maxWorkers
        self.averageExecutionTime = averageExecutionTime
        self.totalExecutions = totalExecutions
    }
}

/// HTTP server statistics
public struct HTTPServerStats: Codable {
    public let isRunning: Bool
    public let activeConnections: Int
    public let totalRequests: UInt64
    public let averageResponseTime: TimeInterval
    public let errorRate: Double
    
    public init(isRunning: Bool, activeConnections: Int, totalRequests: UInt64, averageResponseTime: TimeInterval, errorRate: Double) {
        self.isRunning = isRunning
        self.activeConnections = activeConnections
        self.totalRequests = totalRequests
        self.averageResponseTime = averageResponseTime
        self.errorRate = errorRate
    }
}

/// System information
public struct SystemInfo: Codable {
    public let osVersion: String
    public let hostname: String
    public let cpuCount: Int
    public let physicalMemory: UInt64
    public let availableMemory: UInt64
    public let diskSpace: DiskSpaceInfo
    
    public init(osVersion: String, hostname: String, cpuCount: Int, physicalMemory: UInt64, availableMemory: UInt64, diskSpace: DiskSpaceInfo) {
        self.osVersion = osVersion
        self.hostname = hostname
        self.cpuCount = cpuCount
        self.physicalMemory = physicalMemory
        self.availableMemory = availableMemory
        self.diskSpace = diskSpace
    }
}

/// Disk space information
public struct DiskSpaceInfo: Codable {
    public let totalSpace: UInt64
    public let freeSpace: UInt64
    public let availableSpace: UInt64
    
    public init(totalSpace: UInt64, freeSpace: UInt64, availableSpace: UInt64) {
        self.totalSpace = totalSpace
        self.freeSpace = freeSpace
        self.availableSpace = availableSpace
    }
}

/// Manages health monitoring and metrics collection for the daemon
public actor HealthManager {
    
    private let daemonStartTime: Date
    private var healthCheckInterval: TimeInterval = 30.0 // seconds
    private var lastHealthCheck: Date?
    private var healthHistory: [DaemonHealth] = []
    private let maxHistorySize = 100
    
    public init(daemonStartTime: Date = Date()) {
        self.daemonStartTime = daemonStartTime
    }
    
    /// Generate comprehensive health report
    public func generateHealthReport(
        jobQueue: JobQueueProtocol,
        workerPool: WorkerPoolProtocol,
        httpServer: HTTPServerManagerProtocol
    ) async -> DaemonHealth {
        
        let now = Date()
        let uptime = now.timeIntervalSince(daemonStartTime)
        
        // Collect process information
        let processInfo = await collectProcessInfo()
        
        // Collect memory information
        let memoryInfo = await collectMemoryInfo()
        
        // Collect job queue statistics
        let jobQueueStats = await collectJobQueueStats(jobQueue)
        
        // Collect worker pool statistics
        let workerPoolStats = await collectWorkerPoolStats(workerPool)
        
        // Collect HTTP server statistics
        let httpServerStats = await collectHTTPServerStats(httpServer)
        
        // Collect system information
        let systemInfo = await collectSystemInfo()
        
        // Determine overall health status
        let status = determineHealthStatus(
            memoryInfo: memoryInfo,
            jobQueueStats: jobQueueStats,
            workerPoolStats: workerPoolStats,
            httpServerStats: httpServerStats
        )
        
        let health = DaemonHealth(
            status: status,
            uptime: uptime,
            processInfo: processInfo,
            memoryInfo: memoryInfo,
            jobQueueStats: jobQueueStats,
            workerPoolStats: workerPoolStats,
            httpServerStats: httpServerStats,
            systemInfo: systemInfo
        )
        
        // Update history
        updateHealthHistory(health)
        
        return health
    }
    
    /// Get recent health history
    public func getHealthHistory(limit: Int = 10) -> [DaemonHealth] {
        return Array(healthHistory.suffix(limit))
    }
    
    /// Check if daemon is healthy based on recent history
    public func isHealthy() -> Bool {
        guard let latest = healthHistory.last else { return false }
        return latest.status == .healthy || latest.status == .degraded
    }
    
    // MARK: - Private Methods
    
    private func collectProcessInfo() async -> ProcessInfo {
        let pid = getpid()
        let ppid = getppid()
        let uid = getuid()
        let gid = getgid()
        
        let executablePath = CommandLine.arguments.first ?? "unknown"
        
        return ProcessInfo(
            pid: pid,
            ppid: ppid,
            uid: uid,
            gid: gid,
            executablePath: executablePath,
            startTime: daemonStartTime
        )
    }
    
    private func collectMemoryInfo() async -> MemoryInfo {
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
        
        let residentSize = kerr == KERN_SUCCESS ? info.resident_size : 0
        let virtualSize = kerr == KERN_SUCCESS ? info.virtual_size : 0
        let peakResidentSize = kerr == KERN_SUCCESS ? info.resident_size_peak : 0
        
        // Get thread count
        var threadList: thread_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let threadResult = task_threads(mach_task_self(), &threadList, &threadCount)
        let actualThreadCount = threadResult == KERN_SUCCESS ? threadCount : 0
        
        if threadResult == KERN_SUCCESS {
            vm_deallocate(mach_task_self(), vm_address_t(bitPattern: threadList), vm_size_t(threadCount))
        }
        
        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        
        return MemoryInfo(
            residentSize: residentSize,
            virtualSize: virtualSize,
            peakResidentSize: peakResidentSize,
            pageSize: pageSize,
            threadCount: actualThreadCount
        )
    }
    
    private func collectJobQueueStats(_ jobQueue: JobQueueProtocol) async -> JobQueueStats {
        // This would need to be implemented based on the actual JobQueue interface
        return JobQueueStats(
            totalJobs: 0,
            pendingJobs: 0,
            runningJobs: 0,
            completedJobs: 0,
            failedJobs: 0,
            averageProcessingTime: 0.0,
            oldestPendingJob: nil
        )
    }
    
    private func collectWorkerPoolStats(_ workerPool: WorkerPoolProtocol) async -> WorkerPoolStats {
        // This would need to be implemented based on the actual WorkerPool interface
        return WorkerPoolStats(
            totalWorkers: 0,
            activeWorkers: 0,
            idleWorkers: 0,
            maxWorkers: 0,
            averageExecutionTime: 0.0,
            totalExecutions: 0
        )
    }
    
    private func collectHTTPServerStats(_ httpServer: HTTPServerManagerProtocol) async -> HTTPServerStats {
        // This would need to be implemented based on the actual HTTPServerManager interface
        return HTTPServerStats(
            isRunning: true,
            activeConnections: 0,
            totalRequests: 0,
            averageResponseTime: 0.0,
            errorRate: 0.0
        )
    }
    
    private func collectSystemInfo() async -> SystemInfo {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let hostname = ProcessInfo.processInfo.hostName
        let cpuCount = ProcessInfo.processInfo.processorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Get available memory (this is complex, using a placeholder)
        let availableMemory = physicalMemory / 2 // Placeholder
        
        // Get disk space for the vault directory
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentsPath.path)
            let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
            let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
            let availableSpace = attributes[.systemAvailableSize] as? UInt64 ?? freeSpace
            
            let diskSpace = DiskSpaceInfo(
                totalSpace: totalSpace,
                freeSpace: freeSpace,
                availableSpace: availableSpace
            )
            
            return SystemInfo(
                osVersion: osVersion,
                hostname: hostname,
                cpuCount: cpuCount,
                physicalMemory: physicalMemory,
                availableMemory: availableMemory,
                diskSpace: diskSpace
            )
        } catch {
            return SystemInfo(
                osVersion: osVersion,
                hostname: hostname,
                cpuCount: cpuCount,
                physicalMemory: physicalMemory,
                availableMemory: availableMemory,
                diskSpace: DiskSpaceInfo(totalSpace: 0, freeSpace: 0, availableSpace: 0)
            )
        }
    }
    
    private func determineHealthStatus(
        memoryInfo: MemoryInfo,
        jobQueueStats: JobQueueStats,
        workerPoolStats: WorkerPoolStats,
        httpServerStats: HTTPServerStats
    ) -> HealthStatus {
        
        // Check for critical issues
        if !httpServerStats.isRunning {
            return .unhealthy
        }
        
        if memoryInfo.residentSize > 2_147_483_648 { // 2GB
            return .unhealthy
        }
        
        if jobQueueStats.failedJobs > jobQueueStats.completedJobs / 2 {
            return .unhealthy
        }
        
        // Check for degraded conditions
        if memoryInfo.residentSize > 1_073_741_824 { // 1GB
            return .degraded
        }
        
        if jobQueueStats.pendingJobs > 100 {
            return .degraded
        }
        
        if workerPoolStats.activeWorkers == workerPoolStats.totalWorkers && workerPoolStats.totalWorkers > 0 {
            return .degraded
        }
        
        return .healthy
    }
    
    private func updateHealthHistory(_ health: DaemonHealth) {
        healthHistory.append(health)
        
        // Keep only the most recent entries
        if healthHistory.count > maxHistorySize {
            healthHistory.removeFirst(healthHistory.count - maxHistorySize)
        }
        
        lastHealthCheck = Date()
    }
}

// MARK: - Protocol Placeholders

/// Protocol for job queue to collect statistics
public protocol JobQueueProtocol {
    var processedJobCount: Int { get }
    // Add other required methods as needed
}

/// Protocol for worker pool to collect statistics
public protocol WorkerPoolProtocol {
    func stop() async
    // Add other required methods as needed
}

/// Protocol for HTTP server manager to collect statistics
public protocol HTTPServerManagerProtocol {
    var isRunning: Bool { get }
    func stop() async
    // Add other required methods as needed
}