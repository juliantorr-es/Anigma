//
//  LegacyTypes.swift
//  PolytroposModule
//
//  [Brief description of file purpose]
//

import Foundation

/// Legacy typealiases preserved for tests and external callers.
@available(*, deprecated, renamed: "ExportResolution")
public typealias Resolution = ExportResolution

@available(*, deprecated, renamed: "PreviewBackendResolution")
public typealias PreviewResolution = PreviewBackendResolution

/// Bridge between backend codec arrays and the legacy `VideoCodec`/`AudioCodec` enums used by fixtures.
public extension RendererCapabilities {
    /// Legacy video codec list for compatibility.
    var supportedVideoCodecs: [VideoCodec] {
        supportedBackendVideoCodecs.compactMap { VideoCodec(rawValue: $0.rawValue) }
    }

    /// Legacy audio codec list for compatibility.
    var supportedAudioCodecs: [AudioCodec] {
        supportedBackendAudioCodecs.compactMap { AudioCodec(rawValue: $0.rawValue) }
    }
}
