import Foundation
import EvidenceContracts
import FoundationContracts
import MediaPipelineContracts

/// Phase 5: Request for saturation pipeline processing
public struct SaturationRequest: Sendable {
    public let surface: MediaSurface
    public let lane: MediaLane
    public let contract: any MediaContract
    public let priority: Int
    public let timestamp: Date
    
    public init(surface: MediaSurface, lane: MediaLane, contract: any MediaContract, priority: Int = 0) {
        self.surface = surface
        self.lane = lane
        self.contract = contract
        self.priority = priority
        self.timestamp = Date()
    }
}

/// Phase 5: Hardware saturation metrics for monitoring
public struct HardwareSaturationMetrics: Sendable {
    public var cpuUtilization: Double = 0.0
    public var gpuUtilization: Double = 0.0
    public var memoryPressure: Double = 0.0
    public var activeRequests: Int = 0
    public var queuedRequests: Int = 0
    public var lastUpdated: Date = Date()
    
    public mutating func update(active: Int, queued: Int) {
        self.activeRequests = active
        self.queuedRequests = queued
        self.lastUpdated = Date()
    }
}

/// The data-plane orchestrator for media saturation lanes.
/// Phase 5: Now includes unified request queuing, backpressure management, and saturation monitoring.
public actor SaturationSubstrate: SaturationSubstrateProtocol {
    private var lanes: [MediaLane: [any Saturable]] = [:]
    private let logger: any GovernanceLogger
    
    // Phase 5: Unified request queue
    private var requestQueue: [SaturationRequest] = []
    private var activeRequests: Int = 0
    private let maxConcurrentRequests: Int
    
    // Phase 5: Hardware saturation monitoring
    public private(set) var saturationMetrics: HardwareSaturationMetrics
    
    // Phase 5: Backpressure configuration
    private let backpressureThreshold: Double // 0.0 to 1.0
    
    public init(
        logger: any GovernanceLogger,
        maxConcurrentRequests: Int = 10,
        backpressureThreshold: Double = 0.8
    ) {
        self.logger = logger
        self.maxConcurrentRequests = maxConcurrentRequests
        self.backpressureThreshold = backpressureThreshold
        self.saturationMetrics = HardwareSaturationMetrics()
    }
    
    public func register(node: any Saturable) {
        lanes[node.lane, default: []].append(node)
    }
    
    /// Phase 5: Returns current hardware saturation metrics
    public func getSaturationMetrics() -> HardwareSaturationMetrics {
        return saturationMetrics
    }
    
    /// Phase 5: Check if system is under backpressure
    public func isUnderBackpressure() -> Bool {
        let utilization = Double(activeRequests) / Double(maxConcurrentRequests)
        return utilization >= backpressureThreshold
    }
    
    /// Phase 5: Update hardware saturation metrics from system monitors
    public func updateHardwareMetrics() {
        // For Phase 5, we implement basic hardware monitoring
        // CPU utilization: Use ProcessInfo for system-level metrics
        // This is a placeholder - full implementation requires platform-specific APIs
        
        // Get current process CPU usage (simplified for Phase 5)
        var cpuUtilization: Double = 0.0
        #if os(macOS)
        // On macOS, we can use host_processor_info or other APIs
        // For Phase 5, use a simplified approach
        cpuUtilization = estimateCPUUtilization()
        #endif
        
        saturationMetrics.cpuUtilization = cpuUtilization
        // GPU and memory metrics would require additional platform-specific implementations
        // For Phase 5, we track request-based metrics
        saturationMetrics.update(active: activeRequests, queued: requestQueue.count)
    }
    
    /// Phase 5: Simple CPU utilization estimation (placeholder for full implementation)
    private func estimateCPUUtilization() -> Double {
        // For Phase 5, return a simplified estimate based on active requests
        // Full implementation would use host_statistics64 or similar APIs
        let loadFactor = Double(activeRequests) / Double(maxConcurrentRequests)
        return min(loadFactor * 1.2, 1.0) // Cap at 100%
    }
    
    /// Phase 5: Enqueue a saturation request for processing
    public func enqueue(request: SaturationRequest) async throws {
        requestQueue.append(request)
        saturationMetrics.update(active: activeRequests, queued: requestQueue.count)
    }
    
    /// Phase 5: Process the next request from the queue
    public func processNextRequest() async throws -> MediaSurface? {
        guard !requestQueue.isEmpty else {
            return nil
        }
        
        // Process requests in FIFO order (priority can be added in future)
        let request = requestQueue.removeFirst()
        
        return try await process(
            surface: request.surface,
            lane: request.lane,
            contract: request.contract
        )
    }
    
    /// Phase 5: Process all pending requests in the queue
    public func processAllRequests() async throws -> [MediaSurface] {
        var results: [MediaSurface] = []
        
        while !requestQueue.isEmpty {
            if isUnderBackpressure() {
                // If backpressure is active, stop processing
                try await logger.log(event: MaterializationEvent(
                    reason: .unsupportedExecutor,
                    outcome: .denied,
                    context: "Backpressure: Pausing queue processing"
                ))
                break
            }
            
            if let result = try await processNextRequest() {
                results.append(result)
            }
            updateHardwareMetrics()
        }
        
        return results
    }
    
    /// Routes a media operation through a saturated lane, emitting materialization events on fallback.
    /// Phase 5: Now uses unified queuing with backpressure management.
    public func process(
        surface: MediaSurface,
        lane: MediaLane,
        contract: any MediaContract
    ) async throws -> MediaSurface {
        // Phase 5: Check backpressure
        if isUnderBackpressure() {
            try await logger.log(event: MaterializationEvent(
                reason: .unsupportedExecutor,
                outcome: .denied,
                context: "Backpressure: System load at \(backpressureThreshold * 100)%"
            ))
            throw MediaError.backpressureActive
        }
        
        guard let pipeline = lanes[lane], !pipeline.isEmpty else {
            // Emit audit governance event if lane is unavailable
            try await logger.log(event: MaterializationEvent(
                reason: .unsupportedExecutor,
                outcome: .denied,
                context: "Lane: \(lane.rawValue)"
            ))
            throw MediaError.laneUnavailable(lane)
        }
        
        activeRequests += 1
        saturationMetrics.update(active: activeRequests, queued: requestQueue.count)
        defer {
            activeRequests -= 1
            saturationMetrics.update(active: activeRequests, queued: requestQueue.count)
        }
        
        var currentSurface = surface
        for node in pipeline {
            currentSurface = try await node.process(surface: currentSurface, contract: contract)
        }
        
        return currentSurface
    }
}

public enum MediaError: Error {
    case laneUnavailable(MediaLane)
    case backpressureActive
}
