//
//  HardwareAuthorityProtocol.swift
//  HardwareAuthorityContracts
//
//  Portable contract types for Hardware Authority.
//  Contains ONLY protocol definitions, data types, and constants.
//  Zero native dependencies. Zero implementation.
//

import Foundation
import AnigmaPrimitives

// MARK: - Hardware Lane Types

/// Enum representing the different hardware lanes for task scheduling.
/// These map to physical compute resources: CPU, GPU, ANE, SIMD.
public enum HardwareLaneType: String, Sendable, Codable {
    case control    // CPU: Governance, Auth, State
    case inference  // GPU: Tensor Ops, LLM
    case perception // ANE: OCR, Layout, Embeddings
    case native     // CPU/SIMD: Deterministic fallback
}

// MARK: - Task Priority

/// Priority levels for compute tasks.
public enum TaskPriority: Int, Sendable, Codable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}

// MARK: - Compute Task

/// A portable representation of a compute task to be dispatched to a hardware lane.
/// Contains no platform-specific types or native handles.
public struct ComputeTask: Sendable {
    public let type: HardwareLaneType
    public let priority: TaskPriority
    public let projectID: ProjectID
    public let buffer: Data // Placeholder for SharedBuffer - portable Data representation
    
    public init(type: HardwareLaneType, priority: TaskPriority, projectID: ProjectID, buffer: Data) {
        self.type = type
        self.priority = priority
        self.projectID = projectID
        self.buffer = buffer
    }
}

// MARK: - Hardware Authority Protocol

/// Protocol defining the contract for hardware-backed task execution.
/// Implementations coordinate dispatch across available hardware lanes
/// with saturation-aware backpressure.
public protocol HardwareAuthority: Actor {
    /// The authority signals when specific lanes have capacity.
    /// - Parameter lane: The hardware lane to monitor
    /// - Returns: An async stream that yields available capacity counts
    func capacityStream(for lane: HardwareLaneType) -> AsyncStream<Int>
    
    /// Dispatches a task to the optimal hardware lane.
    /// - Parameter task: The compute task to execute
    /// - Returns: Result data from the execution
    /// - Throws: HardwareError if the lane is saturated or execution fails
    func dispatch(_ task: ComputeTask) async throws -> Data
}

// MARK: - Hardware Errors

/// Errors that can occur during hardware execution.
public enum HardwareError: Error, LocalizedError {
    /// The specified hardware lane has no available capacity.
    case saturated(lane: HardwareLaneType)
    
    public var errorDescription: String? {
        switch self {
        case .saturated(let lane):
            return "Hardware Saturated: No available slots in \(lane.rawValue) lane."
        }
    }
}
