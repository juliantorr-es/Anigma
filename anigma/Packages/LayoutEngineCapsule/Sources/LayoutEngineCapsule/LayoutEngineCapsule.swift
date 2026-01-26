import Foundation
import CapsuleCore

public final class LayoutEngineCapsule: IdentifiableCapsule {
    private let wrapper: LayoutEngineCapsuleWrapper
    
    public init(config: LayoutEngineConfig) throws {
        self.wrapper = try LayoutEngineCapsuleWrapper(config: config)
    }
    
    public func analyzePDF(_ data: Data) throws -> [PageLayout] {
        return try wrapper.analyzePDF(data)
    }
}
