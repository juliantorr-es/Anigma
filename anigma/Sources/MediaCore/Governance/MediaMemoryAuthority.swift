//
//  MediaMemoryAuthority.swift
//  MediaCore
//
//  Tier 2 Authority - The keystone MediaMemoryAuthority for the Unified Media Substrate.
//  Owns all live media memory across the substrate and delegates to specialized authorities.
//
//  See POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md Part 3
//

import Foundation
import AVFoundation
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import SaturationKit
import AnigmaPrimitives

/// The keystone Tier 2 Authority that owns all live media memory across the substrate.
/// 
/// **Responsibilities**:
/// - Unified ownership of all live media surfaces (video frames, audio buffers, packet streams)
/// - Delegates to specialized authorities (SurfaceAuthority, AudioBufferAuthority, PacketStreamAuthority)
/// - Provides MediaMemoryLease for time-bound access to media surfaces
/// - Tracks all live memory for bounded memory budget enforcement
/// - Coordinates with MaterializationGate for copy governance
///
/// **Thread Safety**: This is an actor, all mutations must go through it.
public actor MediaMemoryAuthority {
    
    private let surfaceAuthority: SurfaceAuthority
    private let audioBufferAuthority: AudioBufferAuthority
    private let packetStreamAuthority: PacketStreamAuthority
    private let materializationGate: MaterializationGate
    private let loggingRing: SaturatedLoggingRing
    
    private var activeLeaseCount: Int = 0
    private var totalBytes: Int64 = 0
    private var memoryBudget: Int64 = 0
    
    /// Creates a new MediaMemoryAuthority with the required dependencies.
    ///
    /// - Parameters:
    ///   - surfaceAuthority: Authority managing video/image surfaces
    ///   - audioBufferAuthority: Authority managing audio buffers
    ///   - packetStreamAuthority: Authority managing packet streams
    ///   - materializationGate: Gate governing forced copies
    ///   - loggingRing: Ring for saturated telemetry logging
    ///   - memoryBudget: Maximum bytes of live memory allowed
    public init(
        surfaceAuthority: SurfaceAuthority,
        audioBufferAuthority: AudioBufferAuthority,
        packetStreamAuthority: PacketStreamAuthority,
        materializationGate: MaterializationGate,
        loggingRing: SaturatedLoggingRing,
        memoryBudget: Int64 = 2_000_000_000 // 2GB default budget
    ) {
        self.surfaceAuthority = surfaceAuthority
        self.audioBufferAuthority = audioBufferAuthority
        self.packetStreamAuthority = packetStreamAuthority
        self.materializationGate = materializationGate
        self.loggingRing = loggingRing
        self.memoryBudget = memoryBudget
    }
    
    // MARK: - Surface Authority Access
    
    /// Returns the SurfaceAuthority for video/image surface management.
    public func getSurfaceAuthority() -> SurfaceAuthority {
        return surfaceAuthority
    }
    
    /// Returns the AudioBufferAuthority for audio buffer management.
    public func getAudioBufferAuthority() -> AudioBufferAuthority {
        return audioBufferAuthority
    }
    
    /// Returns the PacketStreamAuthority for packet stream management.
    public func getPacketStreamAuthority() -> PacketStreamAuthority {
        return packetStreamAuthority
    }
    
    /// Returns the MaterializationGate for copy governance.
    public func getMaterializationGate() -> MaterializationGate {
        return materializationGate
    }
    
    // MARK: - Unified Registration
    
    /// Registers a native video surface and returns a FrameReference.
    /// Internal method used by backends.
    public func registerVideoSurface(
        nativeSurface: Any,
        width: Int,
        height: Int,
        format: String,
        metadata: [String: String] = [:]
    ) async -> FrameReference {
        return await surfaceAuthority.registerInternal(
            nativeSurface: nativeSurface,
            width: width,
            height: height,
            format: format,
            metadata: metadata
        )
    }
    
    /// Registers a native image surface and returns an ImageSurfaceReference.
    public func registerImageSurface(
        nativeSurface: Any,
        width: Int,
        height: Int,
        format: String
    ) async -> ImageSurfaceReference {
        return await surfaceAuthority.registerImageInternal(
            nativeSurface: nativeSurface,
            width: width,
            height: height,
            format: format
        )
    }
    
    /// Registers an audio buffer and returns an AudioBufferReference.
    public func registerAudioBuffer(pcmBuffer: AVAudioPCMBuffer) async -> AudioBufferReference {
        return await audioBufferAuthority.register(pcmBuffer: pcmBuffer)
    }
    
    /// Registers a compressed audio buffer and returns an AudioBufferReference.
    public func registerCompressedAudioBuffer(compressedBuffer: AVAudioCompressedBuffer) async -> AudioBufferReference {
        return await audioBufferAuthority.register(compressedBuffer: compressedBuffer)
    }
    
    /// Registers a packet stream and returns a PacketStreamReference.
    public func registerPacketStream(
        packet: Any,
        codec: String,
        mediaType: String,
        bitRate: Int? = nil
    ) async -> PacketStreamReference {
        return await packetStreamAuthority.register(
            packet: packet,
            codec: codec,
            mediaType: mediaType,
            bitRate: bitRate
        )
    }
    
    // MARK: - Memory Budget Tracking
    
    /// Returns the current memory usage in bytes.
    public func currentMemoryUsage() -> Int64 {
        return totalBytes
    }
    
    /// Returns the memory budget in bytes.
    public func getMemoryBudget() -> Int64 {
        return memoryBudget
    }
    
    /// Returns the percentage of memory budget used.
    public func memoryUsagePercentage() -> Double {
        guard memoryBudget > 0 else { return 0.0 }
        return Double(totalBytes) / Double(memoryBudget) * 100.0
    }
    
    /// Returns whether we are within memory budget.
    public func isWithinBudget() -> Bool {
        return totalBytes <= memoryBudget
    }
    
    /// Updates the byte count for a surface. Called by authorities on registration.
    internal func addBytes(_ bytes: Int64) {
        totalBytes += bytes
    }
    
    /// Updates the byte count when a surface is released. Called by authorities on release.
    internal func removeBytes(_ bytes: Int64) {
        totalBytes = max(0, totalBytes - bytes)
    }
    
    // MARK: - Lease Management
    
    /// Creates a time-bound lease for a FrameReference.
    public func createLease(for reference: FrameReference) -> FrameLease {
        activeLeaseCount += 1
        return FrameLease(token: reference.token, reference: reference)
    }
    
    /// Creates a time-bound lease for an ImageSurfaceReference.
    public func createLease(for reference: ImageSurfaceReference) -> ImageSurfaceLease {
        activeLeaseCount += 1
        return ImageSurfaceLease(token: reference.token, reference: reference)
    }
    
    /// Releases a lease and potentially frees the underlying surface.
    public func releaseLease(_ lease: any MediaLease) {
        activeLeaseCount = max(0, activeLeaseCount - 1)
    }
    
    /// Returns the current number of active leases.
    public func getActiveLeaseCount() -> Int {
        return activeLeaseCount
    }
    
    // MARK: - MediaCopyProof Generation
    
    /// Generates a MediaCopyProof for a zero-copy operation.
    public func generateZeroCopyProof(
        token: String,
        operation: String,
        events: [String] = []
    ) -> MediaCopyProof {
        return MediaCopyProof(
            token: token,
            copiedBytes: 0,
            operation: operation,
            events: events
        )
    }
    
    /// Generates a MediaCopyProof for a materialization (copy) operation.
    public func generateCopyProof(
        token: String,
        copiedBytes: Int64,
        operation: String,
        events: [String] = []
    ) -> MediaCopyProof {
        return MediaCopyProof(
            token: token,
            copiedBytes: copiedBytes,
            operation: operation,
            events: events
        )
    }
}

// MARK: - MediaLease Protocol

/// Protocol for all media leases that provide time-bound access to media surfaces.
public protocol MediaLease: Sendable {
    var token: any Hashable & Sendable { get }
    var reference: any MediaReferenceConvertible { get }
}

/// Marker protocol for types that can be converted to MediaReference.
public protocol MediaReferenceConvertible: Sendable {
    var mediaReference: MediaReference { get }
}

// MARK: - Extensions for MediaReferenceConvertible

extension FrameReference: MediaReferenceConvertible {
    public var mediaReference: MediaReference {
        return .videoFrame(self)
    }
}

extension AudioBufferReference: MediaReferenceConvertible {
    public var mediaReference: MediaReference {
        return .audioBuffer(self)
    }
}

extension ImageSurfaceReference: MediaReferenceConvertible {
    public var mediaReference: MediaReference {
        return .imageSurface(self)
    }
}

extension PacketStreamReference: MediaReferenceConvertible {
    public var mediaReference: MediaReference {
        return .packetStream(self)
    }
}

extension ArtifactReference: MediaReferenceConvertible {
    public var mediaReference: MediaReference {
        return .artifact(self)
    }
}
