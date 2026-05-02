import Foundation
import FoundationContracts

/// A Tier 2 Governance actor that manages compressed media packet streams.
/// Ensures packets are registered and tracked before hit decoders.
public actor PacketStreamAuthority {
    
    // Store as Any to support CMSampleBuffer without leaking CoreMedia to Tier 1
    private var registry: [PacketStreamToken: Any] = [:]
    
    public init() {}
    
    /// Registers a raw data packet or CMSampleBuffer into the authority.
    /// Returns a portable PacketStreamReference.
    public func register(
        packet: Any,
        codec: String,
        mediaType: String,
        bitRate: Int? = nil
    ) -> PacketStreamReference {
        let token = PacketStreamToken()
        registry[token] = packet
        
        return PacketStreamReference(
            token: token,
            codec: codec,
            mediaType: mediaType,
            bitRate: bitRate
        )
    }
    
    /// Resolves a token to its underlying packet (Data or CMSampleBuffer).
    public func resolve(token: PacketStreamToken) -> Any? {
        return registry[token]
    }
    
    /// Resolves a token to raw Data if applicable.
    public func resolveData(token: PacketStreamToken) -> Data? {
        return registry[token] as? Data
    }
    
    /// Removes a packet from the registry, invalidating its token.
    public func release(token: PacketStreamToken) {
        registry.removeValue(forKey: token)
    }
    
    /// Returns the current number of active packets in the registry.
    public func activePacketCount() -> Int {
        return registry.count
    }
}
