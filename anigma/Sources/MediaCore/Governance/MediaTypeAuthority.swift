import Foundation
import FoundationContracts

/// A Tier 2 Authority that standardizes media type routing.
/// Prevents platform-specific type leakage (like UTType) into the core architecture.
public actor MediaTypeAuthority {
    
    public init() {}
    
    /// Resolves the media format for a given URL using platform-native identifiers internally.
    /// Returns a portable MediaDescriptorBundle.
    public func resolveFormat(for url: URL) async -> MediaDescriptorBundle {
        return resolveFormatInternal(for: url)
    }
    
    /// Determines if hardware-saturated decoding is available for the given descriptor.
    public func isHardwareDecodingSupported(for bundle: MediaDescriptorBundle) -> Bool {
        // Broad policy for Phase 0: Native frameworks support H.264, HEVC, and ProRes.
        guard let codec = bundle.codec else {
            return bundle.hardwareDecodingSupported
        }
        
        switch codec {
        case .h264, .hevc, .prores:
            return true
        default:
            return false
        }
    }
}
