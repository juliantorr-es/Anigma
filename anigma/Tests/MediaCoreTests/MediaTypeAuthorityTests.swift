import Testing
import Foundation
import ContractsCore
@testable import MediaCore

@Suite("MediaTypeAuthority Tests")
struct MediaTypeAuthorityTests {
    let authority: MediaTypeAuthority
    
    init() {
        self.authority = MediaTypeAuthority()
    }
    
    @Test("Resolving native video formats (.mp4, .mov)")
    func resolveNativeVideo() async throws {
        let mp4URL = URL(fileURLWithPath: "test.mp4")
        let movURL = URL(fileURLWithPath: "test.MOV")
        
        let mp4Bundle = await authority.resolveFormat(for: mp4URL)
        #expect(mp4Bundle.type == .video)
        #expect(mp4Bundle.container == .mp4)
        #expect(mp4Bundle.hardwareDecodingSupported == true)
        
        let movBundle = await authority.resolveFormat(for: movURL)
        #expect(movBundle.type == .video)
        #expect(movBundle.container == .mov)
        #expect(movBundle.hardwareDecodingSupported == true)
    }
    
    @Test("Resolving fallback video formats (.webm)")
    func resolveFallbackVideo() async throws {
        let webmURL = URL(fileURLWithPath: "test.webm")
        
        let bundle = await authority.resolveFormat(for: webmURL)
        // Note: UTType on older macOS might not recognize webm, but on newer it does.
        // We check that even if recognized as video, hardwareDecodingSupported stays false if not H264/HEVC.
        if bundle.type == .video {
            #expect(bundle.codec != .h264)
            #expect(bundle.codec != .hevc)
        }
        
        // Final check: Is it supported by our policy?
        #expect(await authority.isHardwareDecodingSupported(for: bundle) == false)
    }
    
    @Test("Resolving native image formats (.jpg, .png)")
    func resolveNativeImages() async throws {
        let jpgURL = URL(fileURLWithPath: "photo.jpg")
        let pngURL = URL(fileURLWithPath: "icon.png")
        
        let jpgBundle = await authority.resolveFormat(for: jpgURL)
        #expect(jpgBundle.type == .image)
        #expect(jpgBundle.hardwareDecodingSupported == true)
        
        let pngBundle = await authority.resolveFormat(for: pngURL)
        #expect(pngBundle.type == .image)
        #expect(pngBundle.hardwareDecodingSupported == true)
    }
    
    @Test("Resolving document formats (.pdf)")
    func resolveDocuments() async throws {
        let pdfURL = URL(fileURLWithPath: "report.pdf")
        
        let bundle = await authority.resolveFormat(for: pdfURL)
        #expect(bundle.type == .document)
        #expect(bundle.container == .pdf)
        #expect(bundle.hardwareDecodingSupported == true)
    }
}
