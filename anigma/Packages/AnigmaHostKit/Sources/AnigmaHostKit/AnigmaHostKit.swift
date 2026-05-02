/// AnigmaHostKit provides platform integration for Anigma, including resource detection,
/// allocation, and process lifecycle management across macOS, Linux, and Docker.

import Foundation

/// Platform type enumeration
public enum HostPlatform: Sendable {
    case macOS(String) // version
    case linux(String) // distribution
    case docker
}

/// Host system information
public struct HostInfo: Sendable {
    public let platform: HostPlatform
    public let cpuCount: Int
    public let memoryBytes: UInt64
    public let availableMemoryBytes: UInt64
    
    public init(
        platform: HostPlatform,
        cpuCount: Int,
        memoryBytes: UInt64,
        availableMemoryBytes: UInt64
    ) {
        self.platform = platform
        self.cpuCount = cpuCount
        self.memoryBytes = memoryBytes
        self.availableMemoryBytes = availableMemoryBytes
    }
}

/// Resource allocation configuration
public struct ResourceAllocation {
    public let cpuCores: Int
    public let memoryMB: UInt64
    public let timeoutSeconds: TimeInterval
    
    public init(
        cpuCores: Int = 1,
        memoryMB: UInt64 = 512,
        timeoutSeconds: TimeInterval = 300
    ) {
        self.cpuCores = cpuCores
        self.memoryMB = memoryMB
        self.timeoutSeconds = timeoutSeconds
    }
}

/// Host manager for system integration
public actor HostManager {
    public nonisolated let hostInfo: HostInfo
    
    public init() async {
        self.hostInfo = Self.detectHost()
    }
    
    /// Detect current host configuration
    private static func detectHost() -> HostInfo {
        let platform = detectPlatform()
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        
        // For now, use simple heuristic for available memory
        let availableMemory = memoryBytes / 2
        
        return HostInfo(
            platform: platform,
            cpuCount: cpuCount,
            memoryBytes: memoryBytes,
            availableMemoryBytes: availableMemory
        )
    }
    
    /// Detect platform type
    private static func detectPlatform() -> HostPlatform {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        
        #if os(macOS)
        return .macOS(osVersion)
        #elseif os(Linux)
        return .linux(osVersion)
        #else
        return .docker
        #endif
    }
    
    /// Get current host information
    public nonisolated func getHostInfo() -> HostInfo {
        hostInfo
    }
    
    /// Allocate resources for a task
    public nonisolated func allocateResources(for task: String) -> ResourceAllocation {
        let cpuCores = max(1, hostInfo.cpuCount / 2)
        let memoryMB = max(512, hostInfo.availableMemoryBytes / (1024 * 1024) / 2)
        
        return ResourceAllocation(
            cpuCores: cpuCores,
            memoryMB: memoryMB,
            timeoutSeconds: 300
        )
    }
}

/// Process lifecycle manager
public actor ProcessLifecycleManager {
    public enum ProcessState {
        case idle
        case running(pid: Int32)
        case completed(exitCode: Int32)
        case failed(error: Error)
    }
    
    private var state: ProcessState = .idle
    
    public init() {}
    
    /// Start a process
    public func startProcess(_ executablePath: String, arguments: [String]) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        try process.run()
        
        state = .running(pid: process.processIdentifier)
        return process.processIdentifier
    }
    
    /// Wait for process completion
    public func waitForCompletion() async -> Int32? {
        switch state {
        case .running(let pid):
            // In real implementation, would wait for process
            state = .completed(exitCode: 0)
            return 0
        case .completed(let exitCode):
            return exitCode
        default:
            return nil
        }
    }
    
    /// Get current process state
    public func getCurrentState() -> ProcessState {
        state
    }
    
    /// Terminate process
    public func terminate() async {
        if case .running(let pid) = state {
            let process = Process()
            process.launchPath = "/bin/kill"
            process.arguments = [String(pid)]
            try? process.run()
            state = .completed(exitCode: -1)
        }
    }
}
