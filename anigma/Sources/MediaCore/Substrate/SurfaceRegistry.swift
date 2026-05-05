import Foundation
import CoreVideo
import Metal
import FoundationContracts
import MediaPipelineContracts

/// Internal registry mapping SurfaceToken to actual native surface handles.
/// This registry is NOT exposed through contract modules - it lives only in MediaCore.
/// Native APIs (CoreVideo, Metal, etc.) remain in this implementation module.
public final class SurfaceRegistry: Sendable {
    private var pixelBufferStore: [SurfaceToken: CVPixelBuffer] = [:]
    private var textureStore: [SurfaceToken: MTLTexture] = [:]
    private let lock = NSRecursiveLock()
    
    public static let shared = SurfaceRegistry()
    
    private init() {}
    
    /// Register a CVPixelBuffer and return a SurfaceToken.
    /// The SurfaceToken can be used to create a portable MediaSurface.
    public func register(pixelBuffer: CVPixelBuffer) -> SurfaceToken {
        lock.lock()
        defer { lock.unlock() }
        
        let token = SurfaceToken()
        pixelBufferStore[token] = pixelBuffer
        return token
    }
    
    /// Register a MTLTexture and return a SurfaceToken.
    public func register(texture: MTLTexture) -> SurfaceToken {
        lock.lock()
        defer { lock.unlock() }
        
        let token = SurfaceToken()
        textureStore[token] = texture
        return token
    }
    
    /// Resolve a SurfaceToken to its CVPixelBuffer representation.
    /// Returns nil if the token doesn't exist or isn't a pixel buffer.
    public func resolvePixelBuffer(_ token: SurfaceToken) -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return pixelBufferStore[token]
    }
    
    /// Resolve a SurfaceToken to its MTLTexture representation.
    /// Returns nil if the token doesn't exist or isn't a texture.
    public func resolveTexture(_ token: SurfaceToken) -> MTLTexture? {
        lock.lock()
        defer { lock.unlock() }
        return textureStore[token]
    }
    
    /// Create a portable MediaSurface from a CVPixelBuffer.
    public func createMediaSurface(from pixelBuffer: CVPixelBuffer) -> MediaSurface {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let byteCount = CVPixelBufferGetDataSize(pixelBuffer)
        return MediaSurface(
            token: register(pixelBuffer: pixelBuffer),
            kind: .pixelBuffer,
            width: width,
            height: height,
            byteCount: byteCount
        )
    }
    
    /// Create a portable MediaSurface from a MTLTexture.
    public func createMediaSurface(from texture: MTLTexture) -> MediaSurface {
        return MediaSurface(
            token: register(texture: texture),
            kind: .texture,
            width: texture.width,
            height: texture.height,
            byteCount: texture.height * texture.width * 4 // Assume 4 bytes per pixel
        )
    }
    
    /// Release all registered surfaces.
    public func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        pixelBufferStore.removeAll()
        textureStore.removeAll()
    }
}

/// Extension to resolve MediaSurface to native types for internal MediaCore use.
public extension MediaSurface {
    /// Resolve this media surface to a CVPixelBuffer if it represents a pixel buffer.
    /// Returns nil if not a pixel buffer or if the surface is not registered.
    func resolveToPixelBuffer() -> CVPixelBuffer? {
        SurfaceRegistry.shared.resolvePixelBuffer(token)
    }
    
    /// Resolve this media surface to a MTLTexture if it represents a texture.
    /// Returns nil if not a texture or if the surface is not registered.
    func resolveToTexture() -> MTLTexture? {
        SurfaceRegistry.shared.resolveTexture(token)
    }
}
