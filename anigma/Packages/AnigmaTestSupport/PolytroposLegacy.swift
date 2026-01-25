//
//  PolytroposLegacy.swift
//  AnigmaTestSupport
//
//  [Brief description of file purpose]
//

import Foundation
import PolytroposModule
import AnigmaCore
import AnigmaPrimitives

/// Legacy conveniences for PolytroposModule tests.
public typealias Resolution = ExportResolution
public typealias PreviewResolution = PreviewBackendResolution

public extension RendererCapabilities {
    /// Legacy video codec list used by existing tests.
    var supportedVideoCodecs: [VideoCodec] {
        supportedBackendVideoCodecs.compactMap { VideoCodec(rawValue: $0.rawValue) }
    }

    /// Legacy audio codec list used by existing tests.
    var supportedAudioCodecs: [AudioCodec] {
        supportedBackendAudioCodecs.compactMap { AudioCodec(rawValue: $0.rawValue) }
    }
}

public enum LegacyVideoCodec: String, Sendable, CaseIterable {
    case h264
    case h265
    case vp9

    public var runtime: VideoCodec? {
        switch self {
        case .h264:
            return .h264
        case .h265:
            return .hevc
        case .vp9:
            return nil
        }
    }

    public var backend: BackendVideoCodec? {
        switch self {
        case .h264:
            return .h264
        case .h265:
            return .h265
        case .vp9:
            return .vp9
        }
    }
}

public extension VideoCodec {
    var backendCodec: BackendVideoCodec? {
        BackendVideoCodec(rawValue: rawValue)
            ?? (self == .hevc ? .h265 : nil)
    }
}

public extension AudioCodec {
    var backendCodec: BackendAudioCodec? {
        BackendAudioCodec(rawValue: rawValue)
    }
}

public extension RendererCapabilities {
    init(
        supportedVideoCodecs: [VideoCodec] = [],
        supportedAudioCodecs: [AudioCodec] = [],
        supportedContainers: [ContainerFormat] = [],
        gpuAcceleration: Bool = false,
        hardwareEncoding: Bool = false,
        maxResolution: ExportResolution? = nil,
        supportsColorGrading: Bool = false,
        supportsAudioEffects: Bool = false,
        supportsTransitions: Bool = false,
        supportsKeyframes: Bool = false
    ) {
        self.init(
            supportedBackendVideoCodecs: supportedVideoCodecs.compactMap { $0.backendCodec },
            supportedBackendAudioCodecs: supportedAudioCodecs.compactMap { $0.backendCodec },
            supportedContainers: supportedContainers,
            gpuAcceleration: gpuAcceleration,
            hardwareEncoding: hardwareEncoding,
            maxBackendResolution: maxResolution.map {
                BackendResolution(width: $0.width, height: $0.height)
            },
            supportsColorGrading: supportsColorGrading,
            supportsAudioEffects: supportsAudioEffects,
            supportsTransitions: supportsTransitions,
            supportsKeyframes: supportsKeyframes
        )
    }

    var maxResolution: ExportResolution? {
        guard let backend = maxBackendResolution else { return nil }
        return ExportResolution(width: backend.width, height: backend.height)
    }
}

public extension WaveformComponent {
    var legacyDuration: TimeInterval {
        duration
    }
}

public extension BatchExportConfiguration {
    static func legacy(
        sceneIds: [EntityId],
        presets: [ProExportPreset],
        outputDirectory: URL,
        namingPattern: NamingPattern = .sceneNameWithPreset,
        createSubdirectories: Bool = true
    ) -> BatchExportConfiguration {
        .init(
            sceneIds: sceneIds,
            presets: presets,
            outputDirectory: outputDirectory,
            namingPattern: namingPattern,
            createSubdirectories: createSubdirectories
        )
    }
}
