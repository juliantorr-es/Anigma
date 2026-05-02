//
//  ExecutionAuthority.swift
//  ExecutionCore
//
//  Governed Orchestrator for Anigma Tasks.
//  Coordinates HardwareAuthority for compute and DatabaseAuthority for receipts.
//

import Foundation
import AnigmaPrimitives
import DatabaseCore
import HardwareAuthority

public enum JobState: String, Sendable, Codable {
    case pending
    case running
    case completed
    case failed
}

public struct JobID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public protocol ExecutionAuthority: Actor {
    /// Submits a job to the governed execution pipeline.
    func submitJob(
        kind: String,
        lane: HardwareLaneType,
        parameters: DatabaseCore.AnyCodable
    ) async throws -> JobID
    
    /// Checks status of a job.
    func getJobStatus(jobId: JobID) async throws -> JobState
}

public actor GovernedExecutionAuthority: ExecutionAuthority {
    private let database: DatabaseAuthority
    private let hardware: HardwareAuthority
    
    // In-memory job state for fast tracking
    private var jobStates: [JobID: JobState] = [:]

    public init(database: DatabaseAuthority, hardware: HardwareAuthority) {
        self.database = database
        self.hardware = hardware
    }

    public func submitJob(
        kind: String,
        lane: HardwareLaneType,
        parameters: DatabaseCore.AnyCodable
    ) async throws -> JobID {
        let identity = try CorrelationIDContext.required
        let jobId = JobID()
        jobStates[jobId] = .pending
        
        // 1. Record Job Intent (Governance)
        _ = try await database.recordAudit(
            principal: identity.principalID,
            operation: "job.submit",
            entity: jobId.rawValue.uuidString,
            payload: parameters
        )
        
        // 2. Offload to Hardware Authority (Saturation-Aware)
        Task {
            do {
                try await self.runJob(jobId: jobId, lane: lane, parameters: parameters)
            } catch {
                print("Job Failed: \(jobId.rawValue) - \(error.localizedDescription)")
            }
        }
        
        return jobId
    }

    public func getJobStatus(jobId: JobID) async throws -> JobState {
        return jobStates[jobId] ?? .failed
    }
    
    private func runJob(jobId: JobID, lane: HardwareLaneType, parameters: DatabaseCore.AnyCodable) async throws {
        let identity = try CorrelationIDContext.required
        jobStates[jobId] = .running
        
        // Dispatch to hardware lane
        let task = ComputeTask(
            type: lane,
            priority: .medium,
            projectID: identity.projectID,
            buffer: Data() // Shared buffer logic would go here
        )
        
        _ = try await hardware.dispatch(task)
        
        // Terminal State
        jobStates[jobId] = .completed
        
        // 3. Finalize Job Receipt
        _ = try await database.recordAudit(
            principal: identity.principalID,
            operation: "job.complete",
            entity: jobId.rawValue.uuidString,
            payload: .dictionary(["status": .string("success")])
        )
    }
}
