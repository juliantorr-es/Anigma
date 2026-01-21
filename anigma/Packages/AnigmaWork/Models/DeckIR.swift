import Foundation

public struct DeckIR: Codable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var slides: [DeckSlide]

    public init(id: UUID = UUID(), title: String, slides: [DeckSlide] = []) {
        self.id = id
        self.title = title
        self.slides = slides
    }
}

public struct DeckSlide: Codable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var layers: [DeckLayer]

    public init(id: UUID = UUID(), title: String, layers: [DeckLayer] = []) {
        self.id = id
        self.title = title
        self.layers = layers
    }
}

public struct DeckLayer: Codable, Sendable, Identifiable {
    public let id: UUID
    public var type: DeckLayerType
    public var frame: DeckFrame

    public init(id: UUID = UUID(), type: DeckLayerType, frame: DeckFrame) {
        self.id = id
        self.type = type
        self.frame = frame
    }
}

public enum DeckLayerType: Codable, Sendable {
    case text(content: String, style: String?)
    case image(assetId: String)
    case chart(viewSpecId: String)
    case shape(type: String)
}

public struct DeckFrame: Codable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
