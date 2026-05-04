//
//  BackendProtocol.swift
//  PolytroposModule
//
//  Abstract backend protocol for renderer/export engines.
//  Allows switching between native Polytropos renderer and legacy MLT/FFmpeg backends.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
import RendererBackendContracts

// MARK: - Renderer Backend Protocol

/// Abstract protocol for video/audio rendering backends.
/// Implementations can use native Metal/AVFoundation or external tools like MLT/FFmpeg.
/// 
/// This protocol conforms to `RendererBackendContract` to allow AnigmaFoundation
/// to reference renderer backends through a Tier 1-safe contract.
public protocol RendererBackend: RendererBackendContract {
    /// Backend identifier.
    var backendId: RendererBackendId { get }

    /// Human-readable name.
    var displayName: String { get }

    /// Capabilities this backend supports.
    var capabilities: RendererCapabilities { get }

    /// Check if backend is available on this system.
    func isAvailable() async -> Bool

    /// Render a timeline to output file.
    func render(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        configuration: ProExportConfiguration,
        progress: @Sendable @escaping (RenderProgress) -> Void
    ) async throws -> RenderResult

    /// Cancel an in-progress render.
    func cancelRender(jobId: UUID) async

    /// Generate preview frame at specific time.
    func generatePreview(
        timeline: MultiTrackTimelineComponent,
        assets: [EntityId: MediaAssetInfo],
        atTime: TimeInterval,
        resolution: PreviewBackendResolution
    ) async throws -> PreviewFrame
}

/// Backend identifier.
public struct RendererBackendId: Hashable, Codable, Sendable {
    public let rawValue: String

    public static let native = RendererBackendId(rawValue: "native")
    public static let mlt = RendererBackendId(rawValue: "mlt")
    public static let ffmpeg = RendererBackendId(rawValue: "ffmpeg")

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Capabilities a backend can advertise.
public struct RendererCapabilities: Codable, Sendable {
    /// Supported video codecs for export.
    public var supportedBackendVideoCodecs: [BackendVideoCodec]

    /// Supported audio codecs for export.
    public var supportedBackendAudioCodecs: [BackendAudioCodec]

    /// Supported container formats.
    public var supportedContainers: [ContainerFormat]

    /// Whether GPU acceleration is available.
    public var gpuAcceleration: Bool

    /// Whether hardware encoding is available.
    public var hardwareEncoding: Bool

    /// Maximum resolution supported.
    public var maxBackendResolution: BackendResolution?

    /// Whether color grading is supported.
    public var supportsColorGrading: Bool

    /// Whether audio effects are supported.
    public var supportsAudioEffects: Bool

    /// Whether transitions are supported.
    public var supportsTransitions: Bool

    /// Whether keyframe animation is supported.
    public var supportsKeyframes: Bool

    public init(
        supportedBackendVideoCodecs: [BackendVideoCodec] = [],
        supportedBackendAudioCodecs: [BackendAudioCodec] = [],
        supportedContainers: [ContainerFormat] = [],
        gpuAcceleration: Bool = false,
        hardwareEncoding: Bool = false,
        maxBackendResolution: BackendResolution? = nil,
        supportsColorGrading: Bool = false,
        supportsAudioEffects: Bool = false,
        supportsTransitions: Bool = false,
        supportsKeyframes: Bool = false
    ) {
        self.supportedBackendVideoCodecs = supportedBackendVideoCodecs
        self.supportedBackendAudioCodecs = supportedBackendAudioCodecs
        self.supportedContainers = supportedContainers
        self.gpuAcceleration = gpuAcceleration
        self.hardwareEncoding = hardwareEncoding
        self.maxBackendResolution = maxBackendResolution
        self.supportsColorGrading = supportsColorGrading
        self.supportsAudioEffects = supportsAudioEffects
        self.supportsTransitions = supportsTransitions
        self.supportsKeyframes = supportsKeyframes
    }
}

// MARK: - Codec & Format Types

/// Video codecs.
public enum BackendVideoCodec: String, Codable, Sendable, CaseIterable {
    case h264
    case h265
    case prores422
    case prores422hq
    case prores4444
    case proresProxy
    case dnxhd
    case dnxhr
    case vp9
    case av1
    case rawVideo
}

/// Audio codecs.
public enum BackendAudioCodec: String, Codable, Sendable, CaseIterable {
    case aac
    case mp3
    case pcm
    case flac
    case opus
    case vorbis
    case ac3
    case eac3
}

/// Container formats.
public enum ContainerFormat: String, Codable, Sendable, CaseIterable {
    case mp4
    case mov
    case mkv
    case webm
    case avi
    case mxf
    case wav
    case m4a
}

/// BackendResolution specification.
public struct BackendResolution: Codable, Sendable, Hashable {
    public var width: Int
    public var height: Int

    public static let hd720 = BackendResolution(width: 1280, height: 720)
    public static let hd1080 = BackendResolution(width: 1920, height: 1080)
    public static let uhd4k = BackendResolution(width: 3840, height: 2160)
    public static let uhd8k = BackendResolution(width: 7680, height: 4320)

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// MARK: - Media Asset Info

/// Lightweight media asset info for backend rendering.
public struct MediaAssetInfo: Codable, Sendable {
    public var entityId: EntityId
    public var filePath: String
    public var duration: TimeInterval
    public var resolution: BackendResolution?
    public var frameRate: Double?
    public var audioChannels: Int?
    public var sampleRate: Int?
    public var hasProxy: Bool
    public var proxyPath: String?

    public init(
        entityId: EntityId,
        filePath: String,
        duration: TimeInterval,
        resolution: BackendResolution? = nil,
        frameRate: Double? = nil,
        audioChannels: Int? = nil,
        sampleRate: Int? = nil,
        hasProxy: Bool = false,
        proxyPath: String? = nil
    ) {
        self.entityId = entityId
        self.filePath = filePath
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.audioChannels = audioChannels
        self.sampleRate = sampleRate
        self.hasProxy = hasProxy
        self.proxyPath = proxyPath
    }
}

// MARK: - Render Progress & Result

/// Render progress update.
public struct RenderProgress: Sendable {
    public var jobId: UUID
    public var phase: RenderPhase
    public var progress: Double // 0.0 - 1.0
    public var currentFrame: Int?
    public var totalFrames: Int?
    public var estimatedTimeRemaining: TimeInterval?
    public var currentPassName: String?

    public init(
        jobId: UUID,
        phase: RenderPhase,
        progress: Double,
        currentFrame: Int? = nil,
        totalFrames: Int? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentPassName: String? = nil
    ) {
        self.jobId = jobId
        self.phase = phase
        self.progress = progress
        self.currentFrame = currentFrame
        self.totalFrames = totalFrames
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentPassName = currentPassName
    }
}

/// Render phases.
public enum RenderPhase: String, Sendable {
    case preparing
    case analyzing
    case rendering
    case encoding
    case audioMixing
    case compositing
    case finalizing
    case completed
    case failed
    case cancelled
}

/// Render result.
public struct RenderResult: Sendable {
    public var jobId: UUID
    public var success: Bool
    public var outputPath: String?
    public var outputSize: Int64?
    public var duration: TimeInterval?
    public var renderTime: TimeInterval
    public var warnings: [RenderWarning]
    public var error: RenderError?

    public init(
        jobId: UUID,
        success: Bool,
        outputPath: String? = nil,
        outputSize: Int64? = nil,
        duration: TimeInterval? = nil,
        renderTime: TimeInterval,
        warnings: [RenderWarning] = [],
        error: RenderError? = nil
    ) {
        self.jobId = jobId
        self.success = success
        self.outputPath = outputPath
        self.outputSize = outputSize
        self.duration = duration
        self.renderTime = renderTime
        self.warnings = warnings
        self.error = error
    }
}

/// Render warning.
public struct RenderWarning: Sendable {
    public var code: String
    public var message: String
    public var affectedAsset: EntityId?

    public init(code: String, message: String, affectedAsset: EntityId? = nil) {
        self.code = code
        self.message = message
        self.affectedAsset = affectedAsset
    }
}

/// Render error.
public struct RenderError: Error, Sendable {
    public var code: String
    public var message: String
    public var underlyingError: String?

    public init(code: String, message: String, underlyingError: String? = nil) {
        self.code = code
        self.message = message
        self.underlyingError = underlyingError
    }
}

// MARK: - Preview Frame

/// Preview resolution.
public enum PreviewBackendResolution: Sendable {
    case thumbnail(maxDimension: Int)
    case preview(width: Int, height: Int)
    case full
}

/// Preview frame result.
public struct PreviewFrame: Sendable {
    public var time: TimeInterval
    public var width: Int
    public var height: Int
    public var pixelData: Data
    public var pixelFormat: PixelFormat

    public init(
        time: TimeInterval,
        width: Int,
        height: Int,
        pixelData: Data,
        pixelFormat: PixelFormat
    ) {
        self.time = time
        self.width = width
        self.height = height
        self.pixelData = pixelData
        self.pixelFormat = pixelFormat
    }
}

/// Pixel formats.
public enum PixelFormat: String, Sendable {
    case rgba8
    case bgra8
    case rgb8
    case yuv420p
}

// MARK: - Backend Registry

/// Registry of available renderer backends.
public actor RendererBackendRegistry {
    /// Shared instance.
    public static let shared = RendererBackendRegistry()

    /// Registered backends.
    private var backends: [RendererBackendId: any RendererBackend] = [:]

    /// Default backend to use.
    private var defaultBackendId: RendererBackendId = .native

    private init() {}

    /// Register a backend.
    public func register(_ backend: any RendererBackend) {
        backends[backend.backendId] = backend
    }

    /// Get a specific backend.
    public func backend(for id: RendererBackendId) -> (any RendererBackend)? {
        backends[id]
    }

    /// Get the default backend.
    public func defaultBackend() -> (any RendererBackend)? {
        backends[defaultBackendId]
    }

    /// Set the default backend.
    public func setDefaultBackend(_ id: RendererBackendId) {
        if backends.keys.contains(id) {
            defaultBackendId = id
        }
    }

    /// List all registered backends.
    public func allBackends() -> [any RendererBackend] {
        Array(backends.values)
    }

    /// Find best backend for given requirements.
    public func bestBackend(
        requiring capabilities: Set<BackendRequirement>
    ) async -> (any RendererBackend)? {
        for backend in backends.values {
            guard await backend.isAvailable() else { continue }

            var meetsRequirements = true
            for requirement in capabilities {
                switch requirement {
                case .gpuAcceleration:
                    if !backend.capabilities.gpuAcceleration {
                        meetsRequirements = false
                    }
                case .colorGrading:
                    if !backend.capabilities.supportsColorGrading {
                        meetsRequirements = false
                    }
                case .codec(let codec):
                    if !backend.capabilities.supportedBackendVideoCodecs.contains(codec) {
                        meetsRequirements = false
                    }
                case .container(let format):
                    if !backend.capabilities.supportedContainers.contains(format) {
                        meetsRequirements = false
                    }
                }
            }

            if meetsRequirements {
                return backend
            }
        }

        // Fall back to default
        return backends[defaultBackendId]
    }
}

/// Backend requirements for selection.
public enum BackendRequirement: Hashable, Sendable {
    case gpuAcceleration
    case colorGrading
    case codec(BackendVideoCodec)
    case container(ContainerFormat)
}
