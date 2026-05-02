import Foundation
import CapsuleCore
import TelemetryCore
import DocumentIRKit

/// Render plan for converting DocumentIR to visual output
public struct RenderPlan: Codable, Sendable, Equatable {
    public let id: String
    public let documentID: String
    public let renderType: RenderType
    public let layout: Layout
    public var elements: [RenderElement]
    public let metadata: RenderMetadata
    
    public init(
        id: String,
        documentID: String,
        renderType: RenderType,
        layout: Layout,
        elements: [RenderElement] = [],
        metadata: RenderMetadata = RenderMetadata()
    ) {
        self.id = id
        self.documentID = documentID
        self.renderType = renderType
        self.layout = layout
        self.elements = elements
        self.metadata = metadata
    }
}

/// Types of rendering supported
public enum RenderType: String, Codable, Sendable {
    case pdf
    case html
    case markdown
    case plainText
    case canvas
    case print
}

/// Layout configuration for rendering
public struct Layout: Codable, Sendable, Equatable {
    public let pageSize: PageSize
    public let margins: Margins
    public let orientation: Orientation
    public let columns: Int
    
    public init(
        pageSize: PageSize = .a4,
        margins: Margins = .standard,
        orientation: Orientation = .portrait,
        columns: Int = 1
    ) {
        self.pageSize = pageSize
        self.margins = margins
        self.orientation = orientation
        self.columns = columns
    }
}

/// Page size definitions
public enum PageSize: String, Codable, Sendable {
    case a3
    case a4
    case a5
    case letter
    case legal
    
    public var dimensions: (width: Double, height: Double) {
        switch self {
        case .a3: return (842.0, 1191.0)
        case .a4: return (595.0, 842.0)
        case .a5: return (420.0, 595.0)
        case .letter: return (612.0, 792.0)
        case .legal: return (612.0, 1008.0)
        }
    }
}

/// Page margins
public struct Margins: Codable, Sendable, Equatable {
    public let top: Double
    public let right: Double
    public let bottom: Double
    public let left: Double
    
    public static let standard = Margins(top: 72, right: 72, bottom: 72, left: 72)
    public static let narrow = Margins(top: 36, right: 36, bottom: 36, left: 36)
    public static let wide = Margins(top: 108, right: 108, bottom: 108, left: 108)
    
    public init(top: Double, right: Double, bottom: Double, left: Double) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }
}

/// Page orientation
public enum Orientation: String, Codable, Sendable {
    case portrait
    case landscape
}

/// Render elements in the plan
public enum RenderElement: Codable, Sendable, Equatable {
    case text(TextElement)
    case image(ImageElement)
    case shape(ShapeElement)
    case container(ContainerElement)
    case lineBreak
    case pageBreak
}

/// Text rendering element
public struct TextElement: Codable, Sendable, Equatable {
    public let id: String
    public let content: String
    public let frame: CGRect
    public let style: TextStyle
    public let alignment: TextAlignment
    
    public init(
        id: String,
        content: String,
        frame: CGRect,
        style: TextStyle = TextStyle(),
        alignment: TextAlignment = .left
    ) {
        self.id = id
        self.content = content
        self.frame = frame
        self.style = style
        self.alignment = alignment
    }
}

/// Image rendering element
public struct ImageElement: Codable, Sendable, Equatable {
    public let id: String
    public let source: String
    public let frame: CGRect
    public let scaling: ImageScaling
    public let altText: String?
    
    public init(
        id: String,
        source: String,
        frame: CGRect,
        scaling: ImageScaling = .fit,
        altText: String? = nil
    ) {
        self.id = id
        self.source = source
        self.frame = frame
        self.scaling = scaling
        self.altText = altText
    }
}

/// Shape rendering element
public struct ShapeElement: Codable, Sendable, Equatable {
    public let id: String
    public let type: ShapeType
    public let frame: CGRect
    public let fill: Color?
    public let stroke: Stroke?
    
    public init(
        id: String,
        type: ShapeType,
        frame: CGRect,
        fill: Color? = nil,
        stroke: Stroke? = nil
    ) {
        self.id = id
        self.type = type
        self.frame = frame
        self.fill = fill
        self.stroke = stroke
    }
}

/// Container rendering element
public struct ContainerElement: Codable, Sendable, Equatable {
    public let id: String
    public let type: ContainerType
    public let frame: CGRect
    public var children: [RenderElement]
    public let style: ContainerStyle?
    
    public init(
        id: String,
        type: ContainerType,
        frame: CGRect,
        children: [RenderElement] = [],
        style: ContainerStyle? = nil
    ) {
        self.id = id
        self.type = type
        self.frame = frame
        self.children = children
        self.style = style
    }
}

/// Text style for rendering
public struct TextStyle: Codable, Sendable, Equatable {
    public let fontFamily: String
    public let fontSize: Double
    public let fontWeight: FontWeight
    public let fontStyle: FontStyle
    public let color: Color
    public let lineHeight: Double
    
    public init(
        fontFamily: String = "Helvetica",
        fontSize: Double = 12.0,
        fontWeight: FontWeight = .regular,
        fontStyle: FontStyle = .normal,
        color: Color = .black,
        lineHeight: Double = 1.2
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.color = color
        self.lineHeight = lineHeight
    }
}

/// Font weight
public enum FontWeight: String, Codable, Sendable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

/// Font style
public enum FontStyle: String, Codable, Sendable {
    case normal
    case italic
    case oblique
}

/// Text alignment
public enum TextAlignment: String, Codable, Sendable {
    case left
    case center
    case right
    case justify
}

/// Image scaling
public enum ImageScaling: String, Codable, Sendable {
    case fit
    case fill
    case stretch
    case none
}

/// Shape types
public enum ShapeType: String, Codable, Sendable {
    case rectangle
    case circle
    case ellipse
    case line
    case polygon
}

/// Container types
public enum ContainerType: String, Codable, Sendable {
    case paragraph
    case list
    case table
    case section
    case page
    case cell
}

/// Container style
public struct ContainerStyle: Codable, Sendable, Equatable {
    public let backgroundColor: Color?
    public let borderColor: Color?
    public let borderWidth: Double
    public let cornerRadius: Double
    public let padding: Margins
    
    public init(
        backgroundColor: Color? = nil,
        borderColor: Color? = nil,
        borderWidth: Double = 0.0,
        cornerRadius: Double = 0.0,
        padding: Margins = Margins(top: 0, right: 0, bottom: 0, left: 0)
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
}

/// Color representation
public struct Color: Codable, Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    
    public static let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
    public static let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)
    
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = max(0, min(1, red))
        self.green = max(0, min(1, green))
        self.blue = max(0, min(1, blue))
        self.alpha = max(0, min(1, alpha))
    }
    
    public init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: cleaned)
        
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        
        let red = Double((color >> 16) & 0xFF) / 255.0
        let green = Double((color >> 8) & 0xFF) / 255.0
        let blue = Double(color & 0xFF) / 255.0
        let alpha = cleaned.count > 6 ? Double((color >> 24) & 0xFF) / 255.0 : 1.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

/// Stroke definition
public struct Stroke: Codable, Sendable, Equatable {
    public let color: Color
    public let width: Double
    public let dashPattern: [Double]?
    
    public init(color: Color, width: Double, dashPattern: [Double]? = nil) {
        self.color = color
        self.width = width
        self.dashPattern = dashPattern
    }
}

/// Rectangle for positioning
public struct CGRect: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    public static let zero = CGRect(x: 0, y: 0, width: 0, height: 0)
}

/// Render metadata
public struct RenderMetadata: Codable, Sendable, Equatable {
    public let createdDate: Date
    public let version: String
    public let generator: String
    public let properties: [String: AnyCodable]
    
    public init(
        createdDate: Date = Date(),
        version: String = "1.0.0",
        generator: String = "DocumentRenderKit",
        properties: [String: AnyCodable] = [:]
    ) {
        self.createdDate = createdDate
        self.version = version
        self.generator = generator
        self.properties = properties
    }
}

/// Type-erased codable for heterogeneous property dictionaries (re-export from DocumentIRKit)
public typealias AnyCodable = DocumentIRKit.AnyCodable