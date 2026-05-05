import Foundation
import FoundationContracts

/// A Tier 2 Backend Registry that selects the optimal hardware-saturated executor for a given MediaContract.
/// Enforces lane scheduling policies and hardware availability checks.
///
/// **Phase 2**: Uses HardwareCapabilityProbe for AV1 capability checking.
public actor MediaBackendRegistry {
    
    public enum RegistryError: Error {
        case noExecutorAvailable(String)
        case hardwareRequirementNotMet(String)
    }
    
    public enum ExecutorKind: String, Codable, Sendable {
        case videoToolbox = "apple.videotoolbox"
        case audioToolbox = "apple.audiotoolbox"
        case imageIO = "apple.imageio"
        case coreImage = "apple.coreimage"
        case metal = "apple.metal"
        case accelerate = "apple.accelerate"
        case ffmpegFallback = "fallback.ffmpeg"
    }
    
    private let _capabilityProbe: HardwareCapabilityProbe
    
    /// Creates a new MediaBackendRegistry with a hardware capability probe.
    /// 
    /// - Parameter capabilityProbe: The probe for checking hardware capabilities.
    ///   Defaults to a new HardwareCapabilityProbe instance.
    public init(capabilityProbe: HardwareCapabilityProbe = HardwareCapabilityProbe()) {
        self._capabilityProbe = capabilityProbe
    }
    
    /// Selects the best executor for a given contract.
    /// 
    /// **Phase 1**: Uses deterministic mapping based on codec and media type.
    /// **Phase 2**: Uses HardwareCapabilityProbe for AV1 and other codec-specific checks.
    /// 
    /// - Parameter contract: The media contract to select an executor for
    /// - Returns: The optimal ExecutorKind for the contract
    /// - Throws: RegistryError if no executor is available or hardware requirements are not met
    public func selectExecutor<C: MediaContract>(for contract: C) async throws -> ExecutorKind {
        if let decodeContract = contract as? VideoDecodeContract {
            return try await selectVideoDecoder(codec: decodeContract.codec)
        }
        
        if contract is VideoEncodeContract {
            return .videoToolbox
        }
        
        if contract is VideoScaleContract {
            // Check if Metal is available for GPU processing
            if await _capabilityProbe.supportsMetalPerformanceShaders() {
                return .metal
            }
            // Fall back to CPU-based scaling
            return .accelerate
        }
        
        if contract is AudioMixContract {
            // Check if Accelerate DSP is available
            if await _capabilityProbe.supportsAudioDSP() {
                return .accelerate
            }
            throw RegistryError.hardwareRequirementNotMet("Accelerate framework not available")
        }
        
        if contract is AudioDecodeContract {
            return .audioToolbox
        }
        
        if contract is ImageDecodeContract {
            return .imageIO
        }
        
        throw RegistryError.noExecutorAvailable("No saturated executor for contract \(type(of: contract))")
    }
    
    /// Selects the appropriate video decoder executor based on codec support.
    /// 
    /// **Phase 2**: Uses HardwareCapabilityProbe to check AV1 support.
    /// 
    /// - Parameter codec: The video codec identifier
    /// - Returns: The optimal ExecutorKind for the codec
    private func selectVideoDecoder(codec: String) async throws -> ExecutorKind {
        let codecLower = codec.lowercased()
        
        // Check hardware support for specific codecs
        switch codecLower {
        case "h264", "hevc", "hev1":
            // These are widely supported on all Apple hardware
            return .videoToolbox
            
        case "av1":
            // AV1 requires explicit capability check (Phase 2)
            if await _capabilityProbe.supportsHardwareDecode(for: codecLower) {
                return .videoToolbox
            } else {
                // Fall through to FFmpeg
                return .ffmpegFallback
            }
            
        case "prores":
            // ProRes requires checking if available
            if await _capabilityProbe.supportsHardwareDecode(for: codecLower) {
                return .videoToolbox
            } else {
                return .ffmpegFallback
            }
            
        case "vp9":
            // VP9 hardware decode on Apple Silicon M2+
            if await _capabilityProbe.supportsHardwareDecode(for: codecLower) {
                return .videoToolbox
            } else {
                return .ffmpegFallback
            }
            
        default:
            // If not in known codecs, route to FFmpeg fallback boundary
            // Note: This will trigger a MaterializationGate warning/event
            return .ffmpegFallback
        }
    }
    
    /// Returns the HardwareCapabilityProbe used by this registry.
    public func getCapabilityProbe() -> HardwareCapabilityProbe {
        return _capabilityProbe
    }
}
