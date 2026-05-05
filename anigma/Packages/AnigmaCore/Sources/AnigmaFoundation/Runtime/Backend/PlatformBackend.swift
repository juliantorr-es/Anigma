//
//  PlatformBackend.swift
//  RuntimeCore
//
//  PlatformBackend protocol for PlatformRuntime governance.
//  Part of td-358315: Define backend readiness gates.
//  Tier 2 - Runtime layer: Concrete backend orchestration.
//

import Foundation
import AnigmaFoundation
import BackendReadinessContracts
import PersistenceContracts
import RendererBackendContracts

/// Protocol for backends that integrate with PlatformRuntime
public protocol PlatformBackend: Sendable {
    /// Unique identifier for this backend
    var backendId: BackendId { get }
    
    /// Capability contract for this backend
    var contract: BackendCapabilityContract { get }
    
    /// Initialize the backend
    func initialize() async throws
    
    /// Shutdown the backend
    func shutdown() async
    
    /// Execute an operation with context
    func execute<
        Operation: BackendOperation,
        Result
    >(
        _ operation: Operation,
        context: ExecutionContext
    ) async throws -> Result
}

/// Extension to provide default backend ID for common backend types
public extension PlatformBackend {
    static var defaultBackendId: BackendId {
        BackendId(rawValue: "backend-\(UUID().uuidString)")
    }
}

/// Concrete backend implementation example
public struct ConcretePlatformBackend: PlatformBackend {
    public let backendId: BackendId
    public let contract: BackendCapabilityContract
    
    public init(backendId: BackendId, contract: BackendCapabilityContract) {
        self.backendId = backendId
        self.contract = contract
    }
    
    public func initialize() async throws {
        // Backend-specific initialization
    }
    
    public func shutdown() async {
        // Backend-specific shutdown
    }
    
    public func execute<Operation: BackendOperation, Result>(_ operation: Operation, context: ExecutionContext) async throws -> Result {
        // Execute operation with governance context
        // In real implementation, this would call backend-specific logic
        throw RuntimeLifecycleError.unimplemented(message: "execute(operation:context:) must be implemented by concrete backend")
    }
}

/// Database backend implementation (wraps DatabaseExecutor)
public struct DatabasePlatformBackend: PlatformBackend {
    public let backendId: BackendId
    public let contract: BackendCapabilityContract
    private let databaseExecutor: any DatabaseExecutor
    
    public init(databaseExecutor: any DatabaseExecutor) {
        self.backendId = .databaseBackend()
        self.contract = BackendCapabilityContract(
            backendId: .databaseBackend(),
            kind: .database,
            contractId: "database.v1",
            contractVersion: 1,
            supportedOperations: ["query", "mutate", "transaction"]
        )
        self.databaseExecutor = databaseExecutor
    }
    
    public func initialize() async throws {
        try await databaseExecutor.open()
    }
    
    public func shutdown() async {
        await databaseExecutor.close()
    }
    
    public func execute<Operation: BackendOperation, Result>(_ operation: Operation, context: ExecutionContext) async throws -> Result {
        // This would be implemented based on specific operation type
        // For now, this is a placeholder implementation
        throw RuntimeLifecycleError.unimplemented(message: "DatabasePlatformBackend.execute(operation:context:) not yet implemented for operation type: \(operation.operationType)")
    }
}

/// Renderer backend implementation (wraps RendererBackendContract)
/// 
/// This backend wraps a renderer backend that conforms to RendererBackendContract,
/// allowing PlatformRuntime to manage renderer backends through a Tier 1-safe contract.
/// The concrete renderer implementation lives in PolytroposModule, which conforms
/// its RendererBackend protocol to RendererBackendContract.
/// 
/// Part of td-ebd744: Restore RendererBackend through contract extraction / dependency inversion.
public struct RendererPlatformBackend: PlatformBackend {
    public let backendId: BackendId
    public let contract: BackendCapabilityContract
    private let rendererBackend: any RendererBackendContract
    
    public init(rendererBackend: any RendererBackendContract) {
        self.backendId = .rendererBackend()
        self.contract = BackendCapabilityContract(
            backendId: .rendererBackend(),
            kind: .renderer,
            contractId: "renderer.v1",
            contractVersion: 1,
            supportedOperations: ["video-render", "audio-render", "preview"]
        )
        self.rendererBackend = rendererBackend
    }
    
    public func initialize() async throws {
        // Renderer backend initialization: verify availability through the contract
        _ = await rendererBackend.isAvailable()
    }
    
    public func shutdown() async {
        // Renderer backend shutdown
    }
    
    public func execute<Operation: BackendOperation, Result>(_ operation: Operation, context: ExecutionContext) async throws -> Result {
        // This would be implemented based on specific operation type
        // For now, this is a placeholder implementation
        fatalError("RendererPlatformBackend.execute(operation:context:) not yet implemented for operation type: \(operation.operationType)")
    }
}
