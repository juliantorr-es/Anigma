//
//  RendererBackendContracts.swift
//  RendererBackendContracts
//
//  Minimal Tier 1-safe contract for renderer backend integration with PlatformBackend.
//  Part of td-ebd744: Restore RendererBackend through contract extraction.
//
//  This module provides a minimal portable contract that allows AnigmaFoundation's
//  PlatformBackend to reference renderer backend capabilities without creating
//  dependency cycles with PolytroposModule.
//
//  Tier Classification: Tier 1 (Constitutional/Contract Layer)
//  - Only Foundation types
//  - Sendable-compatible
//  - No framework dependencies
//  - No implementation types
//

import Foundation

/// Minimal contract for a renderer backend that can be used by PlatformBackend.
/// 
/// This protocol provides only the portable surface needed for backend readiness
/// integration. Concrete renderer implementations in PolytroposModule conform to this
/// contract, allowing AnigmaFoundation to depend on the contract without depending
/// on PolytroposModule's implementation details.
///
/// - Note: This is intentionally minimal to maintain Tier 1 safety.
///         Full renderer capabilities remain in PolytroposModule's RendererBackend protocol.
public protocol RendererBackendContract: Sendable {
    /// Check if this renderer backend is available on the current system.
    /// 
    /// - Returns: `true` if the backend can be initialized and used, `false` otherwise.
    func isAvailable() async -> Bool
}
