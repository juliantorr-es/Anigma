import AnigmaPrimitives

import AnigmaPrimitives

//
//  BrandingComponents.swift
//  PolytroposModule
//
//  Components for artist/series branding and motion graphics.
//

import AnigmaCore
import Foundation

// MARK: - Branding Profile Component

/// Artist or series branding configuration.
public struct BrandingProfileComponent: Component, Codable {
    /// Unique profile identifier.
    public let id: UUID

    /// Profile name (e.g., "Artist Name", "Show Name").
    public var name: String

    /// Primary brand color (hex).
    public var primaryColor: String

    /// Secondary brand color (hex).
    public var secondaryColor: String

    /// Accent color (hex).
    public var accentColor: String

    /// Text color (hex).
    public var textColor: String

    /// Background color (hex).
    public var backgroundColor: String

    /// Primary font name.
    public var primaryFont: String

    /// Secondary font name.
    public var secondaryFont: String

    /// Logo image asset path.
    public var logoPath: String?

    /// Watermark image asset path.
    public var watermarkPath: String?

    /// Watermark position.
    public var watermarkPosition: WatermarkPosition

    /// Watermark opacity.
    public var watermarkOpacity: Double

    /// Social media handles.
    public var socialHandles: [SocialPlatform: String]

    /// Lower third template configuration.
    public var lowerThirdConfig: LowerThirdConfig?

    /// Intro card configuration.
    public var introConfig: IntroOutroConfig?

    /// Outro card configuration.
    public var outroConfig: IntroOutroConfig?

    public init(
        id: UUID = UUID(),
        name: String,
        primaryColor: String = "#FFFFFF",
        secondaryColor: String = "#000000",
        accentColor: String = "#FF0000",
        textColor: String = "#FFFFFF",
        backgroundColor: String = "#000000",
        primaryFont: String = "SF Pro Display",
        secondaryFont: String = "SF Pro Text",
        logoPath: String? = nil,
        watermarkPath: String? = nil,
        watermarkPosition: WatermarkPosition = .bottomRight,
        watermarkOpacity: Double = 0.6,
        socialHandles: [SocialPlatform: String] = [:],
        lowerThirdConfig: LowerThirdConfig? = nil,
        introConfig: IntroOutroConfig? = nil,
        outroConfig: IntroOutroConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.primaryFont = primaryFont
        self.secondaryFont = secondaryFont
        self.logoPath = logoPath
        self.watermarkPath = watermarkPath
        self.watermarkPosition = watermarkPosition
        self.watermarkOpacity = watermarkOpacity
        self.socialHandles = socialHandles
        self.lowerThirdConfig = lowerThirdConfig
        self.introConfig = introConfig
        self.outroConfig = outroConfig
    }
}

/// Watermark position options.
public enum WatermarkPosition: String, Codable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
    case custom
}

/// Social media platforms.
public enum SocialPlatform: String, Codable, Sendable, CaseIterable {
    case instagram
    case tiktok
    case twitter
    case youtube
    case facebook
    case twitch
    case threads
    case bluesky
    case mastodon
    case website
}

// MARK: - Lower Third Configuration

/// Configuration for lower third graphics.
public struct LowerThirdConfig: Codable, Sendable {
    /// Style preset.
    public var style: LowerThirdStyle

    /// Position from bottom (normalized 0-1).
    public var bottomOffset: Double

    /// Animation style.
    public var animation: LowerThirdAnimation

    /// Display duration in seconds.
    public var displayDuration: TimeInterval

    /// Show social handle.
    public var showSocialHandle: Bool

    /// Which social platform to feature.
    public var featuredPlatform: SocialPlatform?

    public init(
        style: LowerThirdStyle = .modern,
        bottomOffset: Double = 0.1,
        animation: LowerThirdAnimation = .slideIn,
        displayDuration: TimeInterval = 5.0,
        showSocialHandle: Bool = true,
        featuredPlatform: SocialPlatform? = .instagram
    ) {
        self.style = style
        self.bottomOffset = bottomOffset
        self.animation = animation
        self.displayDuration = displayDuration
        self.showSocialHandle = showSocialHandle
        self.featuredPlatform = featuredPlatform
    }
}

/// Lower third visual styles.
public enum LowerThirdStyle: String, Codable, Sendable {
    case minimal      // Text only, no background
    case modern       // Rounded pill background
    case classic      // Rectangle with accent bar
    case bold         // Full-width bar
    case elegant      // Thin underline
    case custom
}

/// Lower third animation styles.
public enum LowerThirdAnimation: String, Codable, Sendable {
    case none
    case fadeIn
    case slideIn
    case slideUp
    case wipeIn
    case typewriter
    case pop
}

// MARK: - Intro/Outro Configuration

/// Configuration for intro or outro cards.
public struct IntroOutroConfig: Codable, Sendable {
    /// Card type.
    public var cardType: CardType

    /// Duration in seconds.
    public var duration: TimeInterval

    /// Background style.
    public var backgroundStyle: BackgroundStyle

    /// Whether to show logo.
    public var showLogo: Bool

    /// Whether to show event info.
    public var showEventInfo: Bool

    /// Whether to show social handles.
    public var showSocialHandles: Bool

    /// Custom text fields.
    public var customFields: [String: String]

    public init(
        cardType: CardType = .simple,
        duration: TimeInterval = 3.0,
        backgroundStyle: BackgroundStyle = .solid,
        showLogo: Bool = true,
        showEventInfo: Bool = true,
        showSocialHandles: Bool = false,
        customFields: [String: String] = [:]
    ) {
        self.cardType = cardType
        self.duration = duration
        self.backgroundStyle = backgroundStyle
        self.showLogo = showLogo
        self.showEventInfo = showEventInfo
        self.showSocialHandles = showSocialHandles
        self.customFields = customFields
    }
}

/// Card layout types.
public enum CardType: String, Codable, Sendable {
    case simple       // Logo + text centered
    case split        // Logo left, text right
    case overlay      // Logo over video blur
    case minimal      // Text only
    case custom
}

/// Background style for cards.
public enum BackgroundStyle: String, Codable, Sendable {
    case solid        // Solid color
    case gradient     // Gradient
    case blur         // Blurred video frame
    case transparent  // No background
    case custom
}

// MARK: - Caption Style Component

/// Caption/subtitle styling configuration.
public struct CaptionStyleComponent: Component, Codable {
    /// Caption style preset.
    public var style: CaptionStyle

    /// Font name.
    public var fontName: String

    /// Font size (points).
    public var fontSize: Double

    /// Text color (hex).
    public var textColor: String

    /// Background color (hex, optional).
    public var backgroundColor: String?

    /// Background opacity.
    public var backgroundOpacity: Double

    /// Outline/stroke color (hex).
    public var outlineColor: String?

    /// Outline width.
    public var outlineWidth: Double

    /// Shadow settings.
    public var shadowEnabled: Bool

    /// Position from bottom (normalized 0-1).
    public var bottomOffset: Double

    /// Maximum characters per line.
    public var maxCharsPerLine: Int

    /// Maximum lines.
    public var maxLines: Int

    /// Word-by-word highlighting (karaoke style).
    public var wordHighlighting: Bool

    public init(
        style: CaptionStyle = .modern,
        fontName: String = "SF Pro Display Bold",
        fontSize: Double = 48,
        textColor: String = "#FFFFFF",
        backgroundColor: String? = nil,
        backgroundOpacity: Double = 0.7,
        outlineColor: String? = "#000000",
        outlineWidth: Double = 2,
        shadowEnabled: Bool = true,
        bottomOffset: Double = 0.15,
        maxCharsPerLine: Int = 40,
        maxLines: Int = 2,
        wordHighlighting: Bool = false
    ) {
        self.style = style
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth
        self.shadowEnabled = shadowEnabled
        self.bottomOffset = bottomOffset
        self.maxCharsPerLine = maxCharsPerLine
        self.maxLines = maxLines
        self.wordHighlighting = wordHighlighting
    }
}

/// Caption style presets.
public enum CaptionStyle: String, Codable, Sendable {
    case classic      // White text, black outline
    case modern       // Bold, minimal shadow
    case boxed        // Text with background box
    case karaoke      // Word-by-word highlighting
    case minimal      // Thin, elegant
    case bold         // Heavy, high contrast
    case custom
}
