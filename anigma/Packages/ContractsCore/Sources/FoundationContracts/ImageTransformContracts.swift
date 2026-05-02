//
//  ImageTransformContracts.swift
//  FoundationContracts
//
//  Phase 3: Image Transform Contracts
//  Contracts for CoreImage-based image processing operations.
//
//  See POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md Part 5
//

import Foundation
import AnigmaPrimitives

// MARK: - Image Transform Contracts

/// Contract for applying a CoreImage filter to an image.
/// Supports all built-in CIFilter types.
public struct ImageFilterContract: MediaContract {
    public static let id = ContractID(name: "media.image.filter", major: 0, minor: 1, schemaHash: "coreimage-filter")
    
    public let sourceImage: ImageSurfaceReference
    public let filterName: String
    public let targetWidth: Int
    public let targetHeight: Int
    
    public var mediaKind: String { "image" }
    
    public init(
        sourceImage: ImageSurfaceReference,
        filterName: String,
        targetWidth: Int,
        targetHeight: Int
    ) {
        self.sourceImage = sourceImage
        self.filterName = filterName
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
    }
}

/// Contract for resizing an image using CoreImage.
/// Supports various scaling algorithms via CIFilter.
public struct ImageResizeContract: MediaContract {
    public static let id = ContractID(name: "media.image.resize", major: 0, minor: 1, schemaHash: "coreimage-resize")
    
    public let sourceImage: ImageSurfaceReference
    public let targetWidth: Int
    public let targetHeight: Int
    
    public var mediaKind: String { "image" }
    
    public init(sourceImage: ImageSurfaceReference, targetWidth: Int, targetHeight: Int) {
        self.sourceImage = sourceImage
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
    }
}

/// Contract for adjusting image color properties using CoreImage.
/// Supports chaining multiple color adjustments in a single operation.
public struct ImageColorAdjustmentContract: MediaContract {
    public static let id = ContractID(name: "media.image.color", major: 0, minor: 1, schemaHash: "coreimage-color")
    
    public let sourceImage: ImageSurfaceReference
    public let targetWidth: Int
    public let targetHeight: Int
    public let brightness: Float?
    public let contrast: Float?
    public let saturation: Float?
    public let exposure: Float?
    
    public var mediaKind: String { "image" }
    
    public init(
        sourceImage: ImageSurfaceReference,
        targetWidth: Int,
        targetHeight: Int,
        brightness: Float? = nil,
        contrast: Float? = nil,
        saturation: Float? = nil,
        exposure: Float? = nil
    ) {
        self.sourceImage = sourceImage
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.exposure = exposure
    }
}
