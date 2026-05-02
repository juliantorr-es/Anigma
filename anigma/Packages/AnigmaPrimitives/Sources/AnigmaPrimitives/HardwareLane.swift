//
//  HardwareLane.swift
//  AnigmaPrimitives
//
//  Enum representing the different hardware lanes for task scheduling.
//

import Foundation

/// Enum representing the different hardware lanes for task scheduling.
public enum HardwareLane: String, Sendable, Codable {
    case control
    case evidence
    case inference
    case perception
    case native
    
    /// Priority of the lane (higher is more urgent).
    public var priority: Int {
        switch self {
        case .control:
            return 100
        case .evidence:
            return 75
        case .inference:
            return 50
        case .perception:
            return 60
        case .native:
            return 25
        }
    }
}
