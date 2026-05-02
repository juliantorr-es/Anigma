import Foundation
import CoreGraphics

public struct FontMetrics: Sendable {
    public let ascender: CGFloat
    public let descender: CGFloat
    public let leading: CGFloat

    public init(ascender: CGFloat, descender: CGFloat, leading: CGFloat) {
        self.ascender = ascender
        self.descender = descender
        self.leading = leading
    }
}
