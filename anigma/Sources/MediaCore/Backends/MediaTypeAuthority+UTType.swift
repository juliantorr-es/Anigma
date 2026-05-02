import Foundation
import UniformTypeIdentifiers
import FoundationContracts

#if canImport(UniformTypeIdentifiers)
extension MediaTypeAuthority {
    
    /// Internal implementation using macOS UTType to map to portable Anigma descriptors.
    internal func resolveFormatInternal(for url: URL) -> MediaDescriptorBundle {
        let pathExtension = url.pathExtension.lowercased()
        let container = ContainerDescriptor(pathExtension)
        
        guard let utType = UTType(filenameExtension: pathExtension) else {
            return MediaDescriptorBundle(
                type: .unknown,
                container: container,
                hardwareDecodingSupported: false
            )
        }
        
        let type: MediaTypeDescriptor
        var codec: CodecDescriptor? = nil
        var hardwareSupported = false
        
        if utType.conforms(to: .movie) || utType.conforms(to: .video) {
            type = .video
            // Heuristic for Phase 0: Common containers map to likely codecs
            if utType.conforms(to: .mpeg4Movie) || utType.conforms(to: .quickTimeMovie) {
                codec = .h264 // Default assumption, VT can probe further
                hardwareSupported = true
            } else if pathExtension == "mkv" {
                codec = .hevc // Common for modern MKV
                hardwareSupported = true
            }
        } else if utType.conforms(to: .audio) {
            type = .audio
            if utType.conforms(to: .mpeg4Audio) {
                codec = .aac
                hardwareSupported = true
            } else if utType.conforms(to: .wav) {
                codec = .pcm
                hardwareSupported = true
            }
        } else if utType.conforms(to: .image) {
            type = .image
            hardwareSupported = true // ImageIO/CoreImage are native
        } else if utType.conforms(to: .pdf) {
            type = .document
            hardwareSupported = true // PDFKit is native
        } else {
            type = .unknown
        }
        
        return MediaDescriptorBundle(
            type: type,
            container: container,
            codec: codec,
            hardwareDecodingSupported: hardwareSupported
        )
    }
}
#endif
