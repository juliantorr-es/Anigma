import Foundation

public struct ANEAnyPayload: Sendable, CustomStringConvertible {
    public let base: any Sendable
    
    public init(_ base: any Sendable) {
        self.base = base
    }
    
    public var description: String {
        String(reflecting: base)
    }
}
