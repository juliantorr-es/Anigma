import Foundation
import AnigmaPrimitives

/// High-level interface for media container analysis and manipulation.
public final class MediaContainerCapsule {
    private let wrapper: MediaContainerCapsuleWrapper
    
    public init(config: MediaContainerConfig = .default) throws {
        self.wrapper = try MediaContainerCapsuleWrapper(config: config)
    }
    
    /// Analyze a media file.
    public func analyze(url: URL) throws -> MediaContainerReport {
        return try wrapper.analyzeFile(at: url)
    }
    
    /// Analyze media data from memory.
    public func analyze(data: Data) throws -> MediaContainerReport {
        return try wrapper.analyzeBuffer(data)
    }
    
    /// Get detailed video stream info.
    public func videoStreamInfo(at index: Int) throws -> VideoStreamInfo? {
        return try wrapper.getVideoStreamInfo(at: UInt32(index))
    }
    
    /// Get detailed audio stream info.
    public func audioStreamInfo(at index: Int) throws -> AudioStreamInfo? {
        return try wrapper.getAudioStreamInfo(at: UInt32(index))
    }
    
    /// Extract a thumbnail from a video stream.
    public func extractThumbnail(
        streamIndex: Int,
        maxWidth: Int = 320,
        maxHeight: Int = 240
    ) throws -> Data {
        return try wrapper.extractThumbnail(
            from: UInt32(streamIndex),
            maxWidth: UInt32(maxWidth),
            maxHeight: UInt32(maxHeight)
        )
    }
    
    /// Validate if a file is a supported media container.
    public func validate(url: URL) throws -> Bool {
        return try wrapper.validateContainer(at: url)
    }
}
