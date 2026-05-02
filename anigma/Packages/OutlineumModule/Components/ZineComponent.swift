import AnigmaPrimitives

import AnigmaPrimitives

//
//  ZineComponent.swift
//  OutlineumModule
//
//  Ported from: Outlineum/backend/outlineum/ecs/components/zine_components.py
//
//  Top-level zine metadata and output paths.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

/// Top-level zine container with metadata and output paths.
///
/// A zine is a collection of pages, each containing images/outlines.
/// The pipeline produces:
/// - Linear PDF: Pages in reading order
/// - Booklet PDF: Pages arranged for folding/stapling
public struct ZineComponent: Component, Codable {
    /// Zine title.
    public var title: String

    /// Path to the zine specification file (optional).
    public var specPath: String?

    /// Path to linear PDF output (pages in order).
    public var linearPdfPath: String?

    /// Path to booklet PDF output (imposed for printing).
    public var bookletPdfPath: String?

    /// Entity IDs of pages in this zine.
    public var pageEntityIds: [EntityId]

    /// When the zine was created.
    public var createdAt: Date

    /// When the zine was last modified.
    public var modifiedAt: Date

    /// Current status.
    public var status: ZineStatus

    /// Version of the pipeline that created or last modified this zine.
    public var pipelineVersion: String?

    /// Hash of the canonical inputs used to build this zine.
    public var inputHash: String?

    /// Path to the provenance JSON (if produced by the pipeline).
    public var provenancePath: String?

    /// Directory where artifacts were emitted.
    public var artifactDirectory: String?

    public init(
        title: String,
        specPath: String? = nil,
        linearPdfPath: String? = nil,
        bookletPdfPath: String? = nil,
        pageEntityIds: [EntityId] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        status: ZineStatus = .draft,
        pipelineVersion: String? = nil,
        inputHash: String? = nil,
        provenancePath: String? = nil,
        artifactDirectory: String? = nil
    ) {
        self.title = title
        self.specPath = specPath
        self.linearPdfPath = linearPdfPath
        self.bookletPdfPath = bookletPdfPath
        self.pageEntityIds = pageEntityIds
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.status = status
        self.pipelineVersion = pipelineVersion
        self.inputHash = inputHash
        self.provenancePath = provenancePath
        self.artifactDirectory = artifactDirectory
    }

    /// Number of pages in the zine.
    public var pageCount: Int {
        pageEntityIds.count
    }
}

/// Zine lifecycle status.
public enum ZineStatus: String, Codable, Sendable {
    /// Initial creation, not yet processed.
    case draft

    /// Currently being generated.
    case generating

    /// Generation complete, awaiting review.
    case review

    /// Approved and published.
    case published

    /// Generation failed.
    case failed
}

/// A single page within a zine.
public struct ZinePageComponent: Component, Codable {
    /// Zero-based page index.
    public let pageIndex: Int

    /// Layout type for this page.
    public var layoutType: PageLayoutType

    /// Entity IDs of images on this page.
    public var imageEntityIds: [EntityId]

    /// Text content for this page (captions, etc.).
    public var textContent: String

    public init(
        pageIndex: Int,
        layoutType: PageLayoutType = .fullBleed,
        imageEntityIds: [EntityId] = [],
        textContent: String = ""
    ) {
        self.pageIndex = pageIndex
        self.layoutType = layoutType
        self.imageEntityIds = imageEntityIds
        self.textContent = textContent
    }
}

/// Page layout types for zine composition.
public enum PageLayoutType: String, Codable, Sendable {
    /// Image fills entire page.
    case fullBleed = "full_bleed"

    /// Image with caption below.
    case imageCaption = "image_caption"

    /// Text only (no images).
    case textOnly = "text_only"

    /// Two images side by side.
    case twoUp = "two_up"

    /// Grid of smaller images.
    case grid = "grid"
}
