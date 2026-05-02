//
//  LanePriorityScheduler.swift
//  SaturationKit
//
//  Hardware Lane Priority Scheduler for fair Unified Memory bandwidth allocation.
//  Implements OperatingMode-driven bandwidth quotas across control, inference, perception, and evidence lanes.
//
//  Key Features:
//  - Fair bandwidth allocation based on OperatingMode policy
//  - Per-lane throughput tracking and measurement
//  - Graceful throttling under contention
//  - Thermal-aware quota reduction
//  - Observability metrics for debugging
//

import Foundation
import AnigmaPrimitives

/// Hardware lanes scheduled by the saturation policy.
public enum HardwareLaneType: String, Sendable, Codable, CaseIterable {
    case control
    case inference
    case perception
    case native
}

/// Bandwidth allocation policy per scheduler mode.
struct BandwidthPolicy: Sendable {
    let mode: LanePriorityMode
    var allocations: [HardwareLaneType: Double] // 0.0–1.0 ratio
    
    static func policy(for mode: LanePriorityMode) -> BandwidthPolicy {
        switch mode {
        case .readOnly:
            return BandwidthPolicy(mode: .readOnly, allocations: [
                .control: 0.40,
                .inference: 0.40,
                .perception: 0.10,
                .native: 0.10  // Fallback lane
            ])
        case .assistive:
            return BandwidthPolicy(mode: .assistive, allocations: [
                .control: 0.30,
                .inference: 0.50,
                .perception: 0.10,
                .native: 0.10
            ])
        case .autopilot:
            return BandwidthPolicy(mode: .autopilot, allocations: [
                .control: 0.20,
                .inference: 0.60,
                .perception: 0.10,
                .native: 0.10
            ])
        case .emergency:
            return BandwidthPolicy(mode: .emergency, allocations: [
                .control: 0.60,
                .inference: 0.20,
                .perception: 0.10,
                .native: 0.10
            ])
        }
    }
}

/// Scheduler policy mode used to avoid a dependency cycle with AnigmaCore.
public enum LanePriorityMode: String, Sendable, Codable, CaseIterable {
    case readOnly
    case assistive
    case autopilot
    case emergency
}

/// Represents a bandwidth lease issued to a mission
public struct BandwidthLease: Sendable, Identifiable {
    public let id: UUID
    public let missionId: UUID
    public let lane: HardwareLaneType
    public let quotaGB_s: Double
    public let leaseStartTime: Date
    public let timeoutSeconds: Double
    
    public var isExpired: Bool {
        Date().timeIntervalSince(leaseStartTime) > timeoutSeconds
    }
    
    init(missionId: UUID, lane: HardwareLaneType, quotaGB_s: Double, timeout: Double = 60.0) {
        self.id = UUID()
        self.missionId = missionId
        self.lane = lane
        self.quotaGB_s = quotaGB_s
        self.leaseStartTime = Date()
        self.timeoutSeconds = timeout
    }
}

/// Lane-specific metrics for observability
public struct LaneMetrics: Sendable {
    public let lane: HardwareLaneType
    public let allocatedQuotaGB_s: Double
    public let observedThroughputGB_s: Double
    public let utilizationRatio: Double  // observed / allocated
    public let activeLeases: Int
    public let throttleEvents: Int
    public let timestamp: Date
}

/// Lane Priority Scheduler: Fair bandwidth allocation across hardware lanes
public actor LanePriorityScheduler {
    // Configuration
    private let totalBandwidthGB_s: Double  // M2 Max: 400 GB/s
    
    // Current state
    private var operatingMode: LanePriorityMode = .readOnly
    private var bandwidthQuotas: [HardwareLaneType: Double] = [:]  // GB/s per lane
    private var observedThroughput: [HardwareLaneType: Double] = [
        .control: 0,
        .inference: 0,
        .perception: 0,
        .native: 0
    ]
    
    // Lease management
    private var activeLeasesPerLane: [HardwareLaneType: [BandwidthLease]] = [
        .control: [],
        .inference: [],
        .perception: [],
        .native: []
    ]
    
    // Throttling state
    private var throttleCountPerLane: [HardwareLaneType: Int] = [
        .control: 0,
        .inference: 0,
        .perception: 0,
        .native: 0
    ]
    
    private var gpuTemperatureCelsius: Double = 50.0
    
    public init(totalBandwidth: Double = 400.0, operatingMode: LanePriorityMode = .readOnly) {
        self.totalBandwidthGB_s = totalBandwidth
        self.operatingMode = operatingMode
        
        // Initialize quotas based on the requested mode.
        let policy = BandwidthPolicy.policy(for: operatingMode)
        for lane in HardwareLaneType.allCases {
            bandwidthQuotas[lane] = (policy.allocations[lane] ?? 0.1) * totalBandwidth
        }
    }
    
    // MARK: - Public API
    
    /// Allocate bandwidth for a new mission
    /// Throws if lane is saturated (backpressure)
    public func allocateFor(
        missionId: UUID,
        lane: HardwareLaneType,
        estimatedThroughputGB_s: Double,
        timeoutSeconds: Double = 60.0
    ) async throws -> BandwidthLease {
        let currentUtilization = observedThroughput[lane] ?? 0
        let quota = bandwidthQuotas[lane] ?? 0
        
        // Check if allocation would exceed quota
        let wouldOvershoot = (currentUtilization + estimatedThroughputGB_s) > quota
        
        if wouldOvershoot {
            throttleCountPerLane[lane, default: 0] += 1
            throw LanePriorityError.laneSaturated(
                lane: lane,
                requestedGB_s: estimatedThroughputGB_s,
                availableGB_s: max(0, quota - currentUtilization)
            )
        }
        
        // Create and record lease
        let lease = BandwidthLease(
            missionId: missionId,
            lane: lane,
            quotaGB_s: estimatedThroughputGB_s,
            timeout: timeoutSeconds
        )
        
        activeLeasesPerLane[lane, default: []].append(lease)
        
        return lease
    }
    
    /// Release bandwidth when mission completes
    public func release(lease: BandwidthLease) async {
        activeLeasesPerLane[lease.lane, default: []]
            .removeAll { $0.id == lease.id }
    }
    
    /// Update OperatingMode and recalculate bandwidth quotas
    public func updateOperatingMode(_ mode: LanePriorityMode) async {
        self.operatingMode = mode
        let policy = BandwidthPolicy.policy(for: mode)
        
        for lane in HardwareLaneType.allCases {
            bandwidthQuotas[lane] = (policy.allocations[lane] ?? 0.1) * totalBandwidthGB_s
        }
    }

    /// Convenience bridge for string-based governance surfaces.
    public func updateOperatingMode(rawValue: String) async throws {
        guard let mode = LanePriorityMode(rawValue: rawValue) else {
            throw LanePriorityError.invalidLane
        }
        await updateOperatingMode(mode)
    }
    
    /// Update GPU temperature (called by thermal monitoring)
    public func updateGPUTemperature(_ temperatureCelsius: Double) async {
        self.gpuTemperatureCelsius = temperatureCelsius
        
        // Reduce GPU lanes if thermal event
        if temperatureCelsius > 90 {
            let thermalReduction = 0.5  // Reduce to 50% if too hot
            bandwidthQuotas[.inference] = (bandwidthQuotas[.inference] ?? 0) * thermalReduction
            bandwidthQuotas[.perception] = (bandwidthQuotas[.perception] ?? 0) * thermalReduction
        }
    }
    
    /// Measure and update observed throughput (called periodically)
    /// In real implementation, this would query Metal performance counters
    public func measureAndAdjust() async {
        // Calculate observed throughput as sum of active lease quotas
        for lane in HardwareLaneType.allCases {
            let activeLeaseThroughput = (activeLeasesPerLane[lane] ?? [])
                .filter { !$0.isExpired }
                .reduce(0) { $0 + $1.quotaGB_s }
            
            observedThroughput[lane] = activeLeaseThroughput
        }
    }
    
    /// Get current metrics for all lanes
    public func getMetrics() -> [LaneMetrics] {
        var metrics: [LaneMetrics] = []
        
        for lane in HardwareLaneType.allCases {
            let allocated = bandwidthQuotas[lane] ?? 0
            let observed = observedThroughput[lane] ?? 0
            let utilization = allocated > 0 ? observed / allocated : 0
            let throttles = throttleCountPerLane[lane] ?? 0
            let activeLeases = (activeLeasesPerLane[lane] ?? []).filter { !$0.isExpired }.count
            
            metrics.append(LaneMetrics(
                lane: lane,
                allocatedQuotaGB_s: allocated,
                observedThroughputGB_s: observed,
                utilizationRatio: utilization,
                activeLeases: activeLeases,
                throttleEvents: throttles,
                timestamp: Date()
            ))
        }
        
        return metrics
    }
    
    /// Check and clean up expired leases
    public func cleanupExpiredLeases() async {
        for lane in HardwareLaneType.allCases {
            activeLeasesPerLane[lane] = (activeLeasesPerLane[lane] ?? [])
                .filter { !$0.isExpired }
        }
    }
    
    /// Get current bandwidth quota for a lane (for observability)
    public func quota(for lane: HardwareLaneType) -> Double {
        bandwidthQuotas[lane] ?? 0
    }
    
    /// Get current observed throughput for a lane (for observability)
    public func observedThroughput(for lane: HardwareLaneType) -> Double {
        observedThroughput[lane] ?? 0
    }
}

// MARK: - Error Types

public enum LanePriorityError: Error, LocalizedError {
    case laneSaturated(lane: HardwareLaneType, requestedGB_s: Double, availableGB_s: Double)
    case leaseExpired(leaseId: UUID)
    case invalidLane
    
    public var errorDescription: String? {
        switch self {
        case .laneSaturated(let lane, let requested, let available):
            return "Lane \(lane.rawValue) saturated: requested \(String(format: "%.1f", requested)) GB/s, available \(String(format: "%.1f", available)) GB/s"
        case .leaseExpired(let leaseId):
            return "Bandwidth lease \(leaseId) has expired"
        case .invalidLane:
            return "Invalid hardware lane specified"
        }
    }
}
