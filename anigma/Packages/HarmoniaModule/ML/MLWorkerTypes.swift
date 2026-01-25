//
//  MLWorkerTypes.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

@preconcurrency import Foundation
import ContractsCore

// MARK: - Type Aliases for Canonical Contracts

/// Re-export canonical ML worker types with compatibility shims
public typealias MLWorkerEngine = ContractsCore.MLWorkerEngine
public typealias MLWorkerTask = ContractsCore.MLWorkerTask
public typealias MLArtifactRef = ContractsCore.MLArtifactRef
public typealias MLTaskOptions = ContractsCore.MLTaskOptions
public typealias MLWorkerRequest = ContractsCore.MLWorkerRequest
public typealias MLWorkerResponse = ContractsCore.MLWorkerResponse
public typealias MLWorkerStatus = ContractsCore.MLWorkerStatus
public typealias EmbeddingHeader = ContractsCore.EmbeddingHeader
public typealias EngineMetadata = ContractsCore.EmbeddingRecipe

// MARK: - Legacy Error Type

/// Legacy error type for backward compatibility
public enum MLWorkerError: Error, Sendable {
    case unavailable(String)
}
