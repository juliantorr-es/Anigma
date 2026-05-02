import Foundation

public struct Color: Sendable, Hashable, Codable {
    public enum Space: String, Sendable, Hashable, Codable {
        case sRGB
        case linearRGB
        case hsl
    }

    public let c1: Double
    public let c2: Double
    public let c3: Double
    public let alpha: Double
    public let space: Space

    public init(_ c1: Double, _ c2: Double, _ c3: Double, alpha: Double = 1.0, space: Space) {
        self.c1 = c1
        self.c2 = c2
        self.c3 = c3
        self.alpha = alpha
        self.space = space
    }

    // Convenience for sRGB/Linear
    public var red: Double {
        switch space {
        case .sRGB, .linearRGB: return c1
        case .hsl: return converted(to: .sRGB).c1
        }
    }

    public var green: Double {
        switch space {
        case .sRGB, .linearRGB: return c2
        case .hsl: return converted(to: .sRGB).c2
        }
    }

    public var blue: Double {
        switch space {
        case .sRGB, .linearRGB: return c3
        case .hsl: return converted(to: .sRGB).c3
        }
    }

    // Convenience for HSL
    public var hue: Double {
        switch space {
        case .hsl: return c1
        case .sRGB, .linearRGB: return converted(to: .hsl).c1
        }
    }

    public var saturation: Double {
        switch space {
        case .hsl: return c2
        case .sRGB, .linearRGB: return converted(to: .hsl).c2
        }
    }

    public var lightness: Double {
        switch space {
        case .hsl: return c3
        case .sRGB, .linearRGB: return converted(to: .hsl).c3
        }
    }
}

// MARK: - Conversion Logic

extension Color {
    public func converted(to targetSpace: Space) -> Color {
        if self.space == targetSpace { return self }

        switch (self.space, targetSpace) {
        case (.sRGB, .linearRGB):
            return Color(sRGBToLinear(c1), sRGBToLinear(c2), sRGBToLinear(c3), alpha: alpha, space: .linearRGB)
        case (.linearRGB, .sRGB):
            return Color(linearToSRGB(c1), linearToSRGB(c2), linearToSRGB(c3), alpha: alpha, space: .sRGB)
        case (.sRGB, .hsl):
            let (h, s, l) = rgbToHSL(r: c1, g: c2, b: c3)
            return Color(h, s, l, alpha: alpha, space: .hsl)
        case (.hsl, .sRGB):
            let (r, g, b) = hslToRGB(h: c1, s: c2, l: c3)
            return Color(r, g, b, alpha: alpha, space: .sRGB)
        case (.linearRGB, .hsl):
            let srgb = self.converted(to: .sRGB)
            return srgb.converted(to: .hsl)
        case (.hsl, .linearRGB):
            let srgb = self.converted(to: .sRGB)
            return srgb.converted(to: .linearRGB)
        default:
            return self
        }
    }

    // MARK: - Helpers

    private func sRGBToLinear(_ c: Double) -> Double {
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private func linearToSRGB(_ c: Double) -> Double {
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }

    private func rgbToHSL(r: Double, g: Double, b: Double) -> (Double, Double, Double) {
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let delta = maxC - minC

        var h: Double = 0
        var s: Double = 0
        let l: Double = (maxC + minC) / 2.0

        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC)

            if maxC == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6.0
        }

        return (h, s, l)
    }

    private func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
        if s == 0 {
            return (l, l, l)
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        let r = hueToRGB(p: p, q: q, t: h + 1/3)
        let g = hueToRGB(p: p, q: q, t: h)
        let b = hueToRGB(p: p, q: q, t: h - 1/3)

        return (r, g, b)
    }

    private func hueToRGB(p: Double, q: Double, t: Double) -> Double {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1/6 { return p + (q - p) * 6 * t }
        if t < 1/2 { return q }
        if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
        return p
    }
}

// MARK: - Constants

extension Color {
    public static let clear = Color(0, 0, 0, alpha: 0, space: .sRGB)
    public static let black = Color(0, 0, 0, space: .sRGB)
    public static let white = Color(1, 1, 1, space: .sRGB)
    public static let gray  = Color(0.5, 0.5, 0.5, space: .sRGB)
    public static let red   = Color(1, 0, 0, space: .sRGB)
    public static let green = Color(0, 1, 0, space: .sRGB)
    public static let blue  = Color(0, 0, 1, space: .sRGB)
    public static let cyan  = Color(0, 1, 1, space: .sRGB)
    public static let magenta = Color(1, 0, 1, space: .sRGB)
    public static let yellow = Color(1, 1, 0, space: .sRGB)
    public static let orange = Color(1, 0.5, 0, space: .sRGB)
    public static let purple = Color(0.5, 0, 0.5, space: .sRGB)
}
