//
//  ColorGrading.swift
//  PolytroposModule
//
//  Professional color grading components and services.
//  Phase 3 of Polytropos Pro roadmap.
//

import AnigmaCore
import AnigmaPrimitives
import Foundation

// MARK: - Color Grade Component

/// Color grade settings for a clip or global adjustment.
public struct ColorGradeComponent: Component, Codable {
    public let id: UUID

    /// Human-readable name.
    public var name: String

    /// Whether this is a global grade or clip-specific.
    public var scope: ColorGradeScope

    /// Primary color corrections (lift/gamma/gain).
    public var primaryCorrection: PrimaryColorCorrection

    /// Color wheels (shadows/midtones/highlights).
    public var colorWheels: ColorWheelSettings

    /// Curves adjustments.
    public var curves: CurveSettings

    /// HSL adjustments.
    public var hslAdjustments: HSLSettings

    /// White balance.
    public var whiteBalance: WhiteBalanceSettings

    /// LUT reference (if using external LUT).
    public var lutReference: LUTReference?

    /// Film emulation preset (if any).
    public var filmEmulation: FilmEmulationPreset?

    /// Whether this grade is enabled.
    public var isEnabled: Bool

    /// Blend amount (0-1).
    public var blendAmount: Double

    public init(
        id: UUID = UUID(),
        name: String = "Color Grade",
        scope: ColorGradeScope = .clip,
        primaryCorrection: PrimaryColorCorrection = .neutral,
        colorWheels: ColorWheelSettings = .neutral,
        curves: CurveSettings = .linear,
        hslAdjustments: HSLSettings = .neutral,
        whiteBalance: WhiteBalanceSettings = .neutral,
        lutReference: LUTReference? = nil,
        filmEmulation: FilmEmulationPreset? = nil,
        isEnabled: Bool = true,
        blendAmount: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.primaryCorrection = primaryCorrection
        self.colorWheels = colorWheels
        self.curves = curves
        self.hslAdjustments = hslAdjustments
        self.whiteBalance = whiteBalance
        self.lutReference = lutReference
        self.filmEmulation = filmEmulation
        self.isEnabled = isEnabled
        self.blendAmount = blendAmount
    }
}

/// Color grade scope.
public enum ColorGradeScope: String, Codable, Sendable {
    case clip           // Applied to single clip
    case scene          // Applied to scene
    case timeline       // Applied to entire timeline
    case adjustment     // Adjustment layer style
}

// MARK: - Primary Color Correction

/// Lift/Gamma/Gain style color correction.
public struct PrimaryColorCorrection: Codable, Sendable {
    /// Exposure adjustment (-5 to +5 stops).
    public var exposure: Double

    /// Contrast (-100 to +100).
    public var contrast: Double

    /// Highlights recovery (-100 to +100).
    public var highlights: Double

    /// Shadows recovery (-100 to +100).
    public var shadows: Double

    /// Whites point (-100 to +100).
    public var whites: Double

    /// Blacks point (-100 to +100).
    public var blacks: Double

    /// Saturation (-100 to +100).
    public var saturation: Double

    /// Vibrance (-100 to +100).
    public var vibrance: Double

    public static let neutral = PrimaryColorCorrection()

    public init(
        exposure: Double = 0,
        contrast: Double = 0,
        highlights: Double = 0,
        shadows: Double = 0,
        whites: Double = 0,
        blacks: Double = 0,
        saturation: Double = 0,
        vibrance: Double = 0
    ) {
        self.exposure = exposure
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.whites = whites
        self.blacks = blacks
        self.saturation = saturation
        self.vibrance = vibrance
    }
}

// MARK: - Color Wheels

/// Color wheel adjustments for shadows/midtones/highlights.
public struct ColorWheelSettings: Codable, Sendable {
    /// Lift (shadows) color adjustment.
    public var lift: ColorWheelValue

    /// Gamma (midtones) color adjustment.
    public var gamma: ColorWheelValue

    /// Gain (highlights) color adjustment.
    public var gain: ColorWheelValue

    /// Offset (overall) color adjustment.
    public var offset: ColorWheelValue

    public static let neutral = ColorWheelSettings()

    public init(
        lift: ColorWheelValue = .neutral,
        gamma: ColorWheelValue = .neutral,
        gain: ColorWheelValue = .neutral,
        offset: ColorWheelValue = .neutral
    ) {
        self.lift = lift
        self.gamma = gamma
        self.gain = gain
        self.offset = offset
    }
}

/// Individual color wheel value.
public struct ColorWheelValue: Codable, Sendable {
    /// Hue angle (0-360).
    public var hue: Double

    /// Saturation (0-1).
    public var saturation: Double

    /// Master level adjustment (-1 to +1).
    public var master: Double

    public static let neutral = ColorWheelValue(hue: 0, saturation: 0, master: 0)

    public init(hue: Double = 0, saturation: Double = 0, master: Double = 0) {
        self.hue = hue
        self.saturation = saturation
        self.master = master
    }
}

// MARK: - Curves

/// Curve adjustments for precise control.
public struct CurveSettings: Codable, Sendable {
    /// RGB master curve.
    public var rgb: CurvePoints

    /// Red channel curve.
    public var red: CurvePoints

    /// Green channel curve.
    public var green: CurvePoints

    /// Blue channel curve.
    public var blue: CurvePoints

    /// Hue vs Hue curve.
    public var hueVsHue: CurvePoints

    /// Hue vs Saturation curve.
    public var hueVsSat: CurvePoints

    /// Hue vs Luma curve.
    public var hueVsLuma: CurvePoints

    public static let linear = CurveSettings()

    public init(
        rgb: CurvePoints = .linear,
        red: CurvePoints = .linear,
        green: CurvePoints = .linear,
        blue: CurvePoints = .linear,
        hueVsHue: CurvePoints = .linear,
        hueVsSat: CurvePoints = .linear,
        hueVsLuma: CurvePoints = .linear
    ) {
        self.rgb = rgb
        self.red = red
        self.green = green
        self.blue = blue
        self.hueVsHue = hueVsHue
        self.hueVsSat = hueVsSat
        self.hueVsLuma = hueVsLuma
    }
}

/// Points defining a curve.
public struct CurvePoints: Codable, Sendable {
    /// Control points (x, y normalized 0-1).
    public var points: [CurvePoint]

    public static let linear = CurvePoints(points: [
        CurvePoint(x: 0, y: 0),
        CurvePoint(x: 1, y: 1)
    ])

    public init(points: [CurvePoint]) {
        self.points = points
    }
}

/// Single curve control point.
public struct CurvePoint: Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - HSL Adjustments

/// Hue/Saturation/Luminance per-color adjustments.
public struct HSLSettings: Codable, Sendable {
    public var red: HSLChannelAdjustment
    public var orange: HSLChannelAdjustment
    public var yellow: HSLChannelAdjustment
    public var green: HSLChannelAdjustment
    public var aqua: HSLChannelAdjustment
    public var blue: HSLChannelAdjustment
    public var purple: HSLChannelAdjustment
    public var magenta: HSLChannelAdjustment

    public static let neutral = HSLSettings()

    public init(
        red: HSLChannelAdjustment = .neutral,
        orange: HSLChannelAdjustment = .neutral,
        yellow: HSLChannelAdjustment = .neutral,
        green: HSLChannelAdjustment = .neutral,
        aqua: HSLChannelAdjustment = .neutral,
        blue: HSLChannelAdjustment = .neutral,
        purple: HSLChannelAdjustment = .neutral,
        magenta: HSLChannelAdjustment = .neutral
    ) {
        self.red = red
        self.orange = orange
        self.yellow = yellow
        self.green = green
        self.aqua = aqua
        self.blue = blue
        self.purple = purple
        self.magenta = magenta
    }
}

/// HSL adjustment for a single color channel.
public struct HSLChannelAdjustment: Codable, Sendable {
    /// Hue shift (-180 to +180 degrees).
    public var hue: Double

    /// Saturation adjustment (-100 to +100).
    public var saturation: Double

    /// Luminance adjustment (-100 to +100).
    public var luminance: Double

    public static let neutral = HSLChannelAdjustment(hue: 0, saturation: 0, luminance: 0)

    public init(hue: Double = 0, saturation: Double = 0, luminance: Double = 0) {
        self.hue = hue
        self.saturation = saturation
        self.luminance = luminance
    }
}

// MARK: - White Balance

/// White balance settings.
public struct WhiteBalanceSettings: Codable, Sendable {
    /// Color temperature (2000K - 11000K).
    public var temperature: Double

    /// Tint (green-magenta, -150 to +150).
    public var tint: Double

    /// Auto white balance applied.
    public var isAuto: Bool

    public static let neutral = WhiteBalanceSettings(temperature: 5500, tint: 0, isAuto: false)

    public init(temperature: Double = 5500, tint: Double = 0, isAuto: Bool = false) {
        self.temperature = temperature
        self.tint = tint
        self.isAuto = isAuto
    }
}

// MARK: - LUT Support

/// Reference to an external LUT file.
public struct LUTReference: Codable, Sendable {
    public var lutId: UUID
    public var name: String
    public var path: String
    public var lutType: LUTType
    public var intensity: Double // 0-1 blend

    public init(
        lutId: UUID = UUID(),
        name: String,
        path: String,
        lutType: LUTType,
        intensity: Double = 1.0
    ) {
        self.lutId = lutId
        self.name = name
        self.path = path
        self.lutType = lutType
        self.intensity = intensity
    }
}

/// LUT file types.
public enum LUTType: String, Codable, Sendable {
    case cube       // .cube format
    case icc        // ICC profile
    case dctl       // DaVinci CTL
    case custom     // Custom format
}

// MARK: - Film Emulation

/// Film emulation presets.
public enum FilmEmulationPreset: String, Codable, Sendable {
    // Classic film stocks
    case kodakPortra400
    case kodakPortra800
    case kodakEktar100
    case kodakGold200
    case kodakVision3

    case fujiPro400H
    case fujiVelvia50
    case fujiProvia100
    case fujiSuperia400

    case ilfordHP5
    case ilfordDelta100
    case kodakTriX400

    // Cinematic looks
    case cinematic_teal_orange
    case cinematic_bleach_bypass
    case cinematic_cross_process
    case cinematic_faded

    // Vintage/retro
    case vintage_70s
    case vintage_80s
    case vintage_polaroid
    case vintage_vhs

    public var displayName: String {
        switch self {
        case .kodakPortra400: return "Kodak Portra 400"
        case .kodakPortra800: return "Kodak Portra 800"
        case .kodakEktar100: return "Kodak Ektar 100"
        case .kodakGold200: return "Kodak Gold 200"
        case .kodakVision3: return "Kodak Vision3"
        case .fujiPro400H: return "Fuji Pro 400H"
        case .fujiVelvia50: return "Fuji Velvia 50"
        case .fujiProvia100: return "Fuji Provia 100"
        case .fujiSuperia400: return "Fuji Superia 400"
        case .ilfordHP5: return "Ilford HP5+ B&W"
        case .ilfordDelta100: return "Ilford Delta 100 B&W"
        case .kodakTriX400: return "Kodak Tri-X 400 B&W"
        case .cinematic_teal_orange: return "Cinematic Teal & Orange"
        case .cinematic_bleach_bypass: return "Bleach Bypass"
        case .cinematic_cross_process: return "Cross Process"
        case .cinematic_faded: return "Faded Film"
        case .vintage_70s: return "70s Vintage"
        case .vintage_80s: return "80s Vintage"
        case .vintage_polaroid: return "Polaroid"
        case .vintage_vhs: return "VHS"
        }
    }
}

// MARK: - Scopes Component

/// Video scopes for color analysis.
public struct ScopesComponent: Component, Codable {
    /// Timeline entity reference.
    public var timelineId: EntityId

    /// Which scopes are enabled.
    public var enabledScopes: Set<ScopeType>

    /// Scope display settings.
    public var displaySettings: ScopeDisplaySettings

    public init(
        timelineId: EntityId,
        enabledScopes: Set<ScopeType> = [.waveform, .parade],
        displaySettings: ScopeDisplaySettings = .init()
    ) {
        self.timelineId = timelineId
        self.enabledScopes = enabledScopes
        self.displaySettings = displaySettings
    }
}

/// Types of video scopes.
public enum ScopeType: String, Codable, Sendable {
    case waveform       // Luma waveform
    case parade         // RGB parade
    case vectorscope    // Color vectorscope
    case histogram      // RGB histogram
}

/// Scope display settings.
public struct ScopeDisplaySettings: Codable, Sendable {
    public var brightness: Double
    public var showGrid: Bool
    public var showLabels: Bool
    public var colorMode: ScopeColorMode

    public init(
        brightness: Double = 1.0,
        showGrid: Bool = true,
        showLabels: Bool = true,
        colorMode: ScopeColorMode = .rgb
    ) {
        self.brightness = brightness
        self.showGrid = showGrid
        self.showLabels = showLabels
        self.colorMode = colorMode
    }
}

/// Scope color modes.
public enum ScopeColorMode: String, Codable, Sendable {
    case rgb        // Color display
    case luma       // Monochrome luma
    case yCbCr      // YCbCr colorspace
}

// MARK: - Color Grading Service

/// Service for applying and managing color grades.
public actor ColorGradingService {

    private let world: World

    public init(world: World) {
        self.world = world
    }

    /// Creates a new color grade.
    public func createColorGrade(
        name: String,
        scope: ColorGradeScope = .clip
    ) async throws -> EntityId {
        let entity = await world.createEntity()
        let grade = ColorGradeComponent(name: name, scope: scope)
        await world.addComponent(grade, to: entity)
        return entity
    }

    /// Applies a color grade to a clip.
    public func applyGrade(
        gradeId: EntityId,
        to clipSegmentId: UUID,
        in timelineId: EntityId
    ) async throws {
        // Implementation would update the clip's colorGradeId
        await Logger.shared.info(
            "Applied grade \(gradeId) to clip \(clipSegmentId)",
            category: "ColorGrading"
        )
    }

    /// Auto white balance for a clip.
    public func autoWhiteBalance(for assetId: EntityId) async throws -> WhiteBalanceSettings {
        // Implementation would analyze the clip and return optimal settings
        return WhiteBalanceSettings(temperature: 5600, tint: 5, isAuto: true)
    }

    /// Auto exposure correction for a clip.
    public func autoExposure(for assetId: EntityId) async throws -> Double {
        // Implementation would analyze the clip and return exposure adjustment
        return 0.0
    }

    /// Copies grade from one clip to another.
    public func copyGrade(
        from sourceClipId: UUID,
        to targetClipIds: [UUID],
        in timelineId: EntityId
    ) async throws {
        await Logger.shared.info(
            "Copied grade from \(sourceClipId) to \(targetClipIds.count) clips",
            category: "ColorGrading"
        )
    }

    /// Generates scope data for a frame.
    public func generateScopeData(
        for timelineId: EntityId,
        at time: TimeInterval,
        scopeType: ScopeType
    ) async throws -> ScopeData {
        // Implementation would render the frame and analyze it
        return ScopeData(scopeType: scopeType, values: [], timestamp: time)
    }
}

/// Scope analysis data.
public struct ScopeData: Sendable {
    public var scopeType: ScopeType
    public var values: [Double] // Normalized scope values
    public var timestamp: TimeInterval
}

// MARK: - Built-in Color Presets

/// Built-in color grade presets.
public enum BuiltInColorPresets {

    /// Standard correction preset.
    public static let standardCorrection = ColorGradeComponent(
        name: "Standard Correction",
        scope: .clip,
        primaryCorrection: PrimaryColorCorrection(
            exposure: 0,
            contrast: 10,
            highlights: -10,
            shadows: 10,
            whites: 0,
            blacks: 0,
            saturation: 5,
            vibrance: 10
        )
    )

    /// Cinematic teal and orange.
    public static let cinematicTealOrange = ColorGradeComponent(
        name: "Cinematic Teal & Orange",
        scope: .clip,
        primaryCorrection: PrimaryColorCorrection(
            exposure: 0,
            contrast: 15,
            highlights: -5,
            shadows: 5,
            saturation: -10,
            vibrance: 15
        ),
        colorWheels: ColorWheelSettings(
            lift: ColorWheelValue(hue: 180, saturation: 0.1, master: -0.02),
            gamma: ColorWheelValue(hue: 0, saturation: 0, master: 0),
            gain: ColorWheelValue(hue: 30, saturation: 0.08, master: 0.02)
        ),
        filmEmulation: .cinematic_teal_orange
    )

    /// Faded film look.
    public static let fadedFilm = ColorGradeComponent(
        name: "Faded Film",
        scope: .clip,
        primaryCorrection: PrimaryColorCorrection(
            exposure: 0.3,
            contrast: -15,
            shadows: 20,
            saturation: -20,
            vibrance: -10
        ),
        filmEmulation: .cinematic_faded
    )

    /// Black and white.
    public static let blackAndWhite = ColorGradeComponent(
        name: "Black & White",
        scope: .clip,
        primaryCorrection: PrimaryColorCorrection(
            contrast: 20,
            saturation: -100
        )
    )

    /// All built-in presets.
    public static let allPresets: [ColorGradeComponent] = [
        standardCorrection,
        cinematicTealOrange,
        fadedFilm,
        blackAndWhite
    ]
}
