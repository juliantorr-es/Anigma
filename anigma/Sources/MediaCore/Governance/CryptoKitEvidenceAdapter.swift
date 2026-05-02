import Foundation
import CryptoKit
import CoreVideo
import FoundationContracts

/// A Tier 2 Governance actor that provides cryptographic fingerprints for media buffers.
/// Uses native Apple CryptoKit to ensure hardware-accelerated, tamper-evident validation.
public actor CryptoKitEvidenceAdapter {
    
    public enum EvidenceError: Error {
        case bufferLockFailed(OSStatus)
    }
    
    public init() {}
    
    /// Generates a SHA256 fingerprint for the contents of a CVPixelBuffer.
    /// This operation is zero-copy: it hashes directly from the buffer's memory pointers.
    public func generateFingerprint(for pixelBuffer: CVPixelBuffer) throws -> MediaFingerprint {
        // 1. Lock the buffer for read-only access
        let status = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard status == kCVReturnSuccess else {
            throw EvidenceError.bufferLockFailed(status)
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        var hasher = SHA256()
        
        // 2. Determine if the buffer is planar
        if CVPixelBufferIsPlanar(pixelBuffer) {
            let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
            for planeIndex in 0..<planeCount {
                guard let planeAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, planeIndex) else { continue }
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, planeIndex)
                let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
                let totalBytes = bytesPerRow * height
                
                let bufferPointer = UnsafeRawBufferPointer(start: planeAddress, count: totalBytes)
                hasher.update(bufferPointer: bufferPointer)
            }
        } else {
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                throw EvidenceError.bufferLockFailed(-1)
            }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let totalBytes = bytesPerRow * height
            
            let bufferPointer = UnsafeRawBufferPointer(start: baseAddress, count: totalBytes)
            hasher.update(bufferPointer: bufferPointer)
        }
        
        // 3. Finalize hash and format as hex
        let digest = hasher.finalize()
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        
        return MediaFingerprint(
            hash: hashString,
            algorithm: "sha256",
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
    }
}
