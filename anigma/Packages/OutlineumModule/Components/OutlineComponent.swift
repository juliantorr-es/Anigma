//
//  OutlineComponent.swift
//  OutlineumModule
//
//  Ported from: Outlineum/backend/outlineum/ecs/components/outline_components.py
//
//  Stores paths to generated outline variants (kids/adult, raster/vector).
//

import AnigmaCore
import Foundation

/// Stores generated outline variants for an image entity.
///
/// Outlineum generates two variants:
/// - **Kids outline**: Thick lines, simplified shapes (low-detail coloring book)
/// - **Adult outline**: Detailed lines, more complexity
///
/// Each variant has:
/// - Raster: Intermediate BMP for Potrace
/// - Vector: Final SVG output
public struct OutlineComponent: Component, Codable {
    // MARK: - Kids Outline (Simplified)

    /// Path to kids outline raster (BMP, intermediate).
    public var kidsOutlineRaster: String?

    /// Path to kids outline vector (SVG, final).
    public var kidsOutlineVector: String?

    // MARK: - Adult Outline (Detailed)

    /// Path to adult outline raster (BMP, intermediate).
    public var adultOutlineRaster: String?

    /// Path to adult outline vector (SVG, final).
    public var adultOutlineVector: String?

    // MARK: - Metadata

    /// When outlines were generated.
    public var generatedAt: Date?

    /// Processing duration in milliseconds.
    public var processingDurationMs: Int64?

    /// Any errors during generation.
    public var errors: [String] = []

    public init(
        kidsOutlineRaster: String? = nil,
        kidsOutlineVector: String? = nil,
        adultOutlineRaster: String? = nil,
        adultOutlineVector: String? = nil,
        generatedAt: Date? = nil,
        processingDurationMs: Int64? = nil,
        errors: [String] = []
    ) {
        self.kidsOutlineRaster = kidsOutlineRaster
        self.kidsOutlineVector = kidsOutlineVector
        self.adultOutlineRaster = adultOutlineRaster
        self.adultOutlineVector = adultOutlineVector
        self.generatedAt = generatedAt
        self.processingDurationMs = processingDurationMs
        self.errors = errors
    }

    /// Whether kids outline was successfully generated.
    public var hasKidsOutline: Bool {
        kidsOutlineVector != nil
    }

    /// Whether adult outline was successfully generated.
    public var hasAdultOutline: Bool {
        adultOutlineVector != nil
    }

    /// Whether any outline was successfully generated.
    public var hasAnyOutline: Bool {
        hasKidsOutline || hasAdultOutline
    }
}
