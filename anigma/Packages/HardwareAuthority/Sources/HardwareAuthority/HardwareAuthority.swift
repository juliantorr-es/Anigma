//
//  HardwareAuthority.swift
//  HardwareAuthority
//
//  Saturation-Aware Compute Mesh for Anigma.
//  Implements Hardware Lanes (GPU, ANE, CPU) and pull-based backpressure.
//

import Foundation
import AnigmaPrimitives
import HardwareAuthorityContracts

public actor SaturationHardwareAuthority: HardwareAuthority {
    private var laneCapacities: [HardwareLaneType: Int] = [
        .control: 100,
        .inference: 4,   // e.g. GPU queue depth
        .perception: 16, // e.g. ANE batch size
        .native: 32
    ]
    
    private var continuations: [HardwareLaneType: [AsyncStream<Int>.Continuation]] = [:]

    public init() {}

    public func capacityStream(for lane: HardwareLaneType) -> AsyncStream<Int> {
        return AsyncStream { continuation in
            if continuations[lane] == nil { continuations[lane] = [] }
            continuations[lane]?.append(continuation)
            
            // Initial signal
            continuation.yield(laneCapacities[lane] ?? 0)
        }
    }

    public func dispatch(_ task: ComputeTask) async throws -> Data {
        let currentCapacity = laneCapacities[task.type] ?? 0
        
        // 1. Backpressure Check
        guard currentCapacity > 0 else {
            // In a real implementation, we would suspend the producer here
            // using a checkedContinuation until capacity is released.
            print("Backpressure: Lane \(task.type.rawValue) is saturated.")
            throw HardwareError.saturated(lane: task.type)
        }
        
        // 2. Consume Capacity
        laneCapacities[task.type] = currentCapacity - 1
        notifyCapacityChange(for: task.type)
        
        defer {
            // 3. Release Capacity
            laneCapacities[task.type] = (laneCapacities[task.type] ?? 0) + 1
            notifyCapacityChange(for: task.type)
        }
        
        // 4. Hardware Routing
        return try await executeOnHardware(task)
    }
    
    private func executeOnHardware(_ task: ComputeTask) async throws -> Data {
        switch task.type {
        case .control:
            print("Routing to CPU (Control Lane)")
        case .inference:
            print("Routing to GPU (Inference Lane)")
        case .perception:
            print("Routing to ANE (Perception Lane)")
        case .native:
            print("Routing to CPU/SIMD (Native Lane)")
        }
        
        // Simulate hardware latency
        try await Task.sleep(for: .milliseconds(100))
        return Data()
    }
    
    private func notifyCapacityChange(for lane: HardwareLaneType) {
        let newCapacity = laneCapacities[lane] ?? 0
        continuations[lane]?.forEach { $0.yield(newCapacity) }
    }
}
