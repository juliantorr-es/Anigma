import Foundation
import CoreGraphics

public struct GlyphInfo: Sendable, Identifiable {
    public let id: Int
    public let advance: CGFloat
    public let bounds: CGRect

    public init(id: Int, advance: CGFloat, bounds: CGRect) {
        self.id = id
        self.advance = advance
        self.bounds = bounds
    }
}
