//
//  Capability.swift
//  CapabilityCore
//
//  [Brief description of file purpose]
//

import Foundation
import AnigmaPrimitives

/// The base protocol for all Anigma capabilities.
/// Capabilities are portable contracts that can be fulfilled by different providers.
public protocol Capability: Sendable {
}

/// A provider that implements one or more capabilities.
public protocol CapabilityProvider: Sendable {
    /// Unique identifier for this provider.
    var providerId: String { get }

    /// The set of capabilities supported by this provider.
    /// These should be the capability IDs (e.g., "anigma.capability.pdf.render").
    var supportedCapabilities: [String] { get }
}

/// Error type for capability-related failures.
public enum CapabilityError: Error, Sendable {
    case notFound(String)
    case providerFailed(String, Error)
    case unsupportedOperation(String)
    case invalidInput(String)
}
