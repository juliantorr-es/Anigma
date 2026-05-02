//
//  AnigmaFoundation.swift
//  AnigmaFoundation
//

import Foundation
@_exported import AnigmaPrimitives

/// Fundamental protocols for authorities.
public protocol BaseAuthority: Sendable {
    var id: String { get }
}
