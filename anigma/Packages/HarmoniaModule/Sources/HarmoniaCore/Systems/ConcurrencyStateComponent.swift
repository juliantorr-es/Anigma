import Foundation
import AnigmaCore
import AnigmaPrimitives

/// Minimal concurrency state component used by SlotManagementSystem.
public struct ConcurrencyStateComponent: Component, Sendable {
    public enum Pressure: String, Codable, Sendable {
        case low
        case medium
        case high
        case critical
    }

    public var modelKind: String
    public var limit: Int
    public var inFlight: Int
    public var waiting: Int
    public var lastUpdated: Date

    public init(modelKind: String, limit: Int, inFlight: Int, waiting: Int, lastUpdated: Date) {
        self.modelKind = modelKind
        self.limit = limit
        self.inFlight = inFlight
        self.waiting = waiting
        self.lastUpdated = lastUpdated
    }

    public var pressure: Pressure {
        if waiting > limit {
            return .critical
        }
        if inFlight >= limit && waiting > 0 {
            return .high
        }
        if utilization > 0.7 {
            return .medium
        }
        return .low
    }

    public var utilization: Double {
        Double(inFlight) / Double(max(1, limit))
    }
}
