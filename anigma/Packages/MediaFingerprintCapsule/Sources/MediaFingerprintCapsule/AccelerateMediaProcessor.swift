//
//  AccelerateMediaProcessor.swift
//  MediaFingerprintCapsule
//
//  Native media processing using AVFoundation + Accelerate framework.
//  Direct frame extraction and perceptual hashing without FFmpeg.
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Protocol

public protocol MediaProcessor {
    /// Extract frames from media at specified timestamps (direct CVPixelBuffer access)
    func extractFrames(from url: URL, timestamps: [CMTime]) throws -> [CVPixelBuffer]
    
    /// Compute perceptual hash of frame data using SIMD/Accelerate
    func hash(pixelBuffer: CVPixelBuffer) throws -> Data
    
    /// Complete fingerprint of media (metadata + perceptual hash)
    func fingerprint(media url: URL) throws -> MediaFingerprint
}

// MARK: - Data Types

public struct MediaFingerprint: Codable {
    public let mediaURL: String
    public let duration: Double
    public let durationSeconds: TimeInterval
    public let width: Int
    public let height: Int
    public let frameCount: Int
    public let perceptualHash: String // Base64-encoded hash
    public let keyFrameHashes: [String]
    public let createdAt: Date
    
    public init(
        mediaURL: String,
        duration: Double,
        durationSeconds: TimeInterval,
        width: Int,
        height: Int,
        frameCount: Int,
        perceptualHash: String,
        keyFrameHashes: [String],
        createdAt: Date = Date()
    ) {
        self.mediaURL = mediaURL
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.width = width
        self.height = height
        self.frameCount = frameCount
        self.perceptualHash = perceptualHash
        self.keyFrameHashes = keyFrameHashes
        self.createdAt = createdAt
    }
}

// MARK: - Error Types

public enum MediaProcessorError: LocalizedError {
    case unsupportedFormat
    case assetNotFound
    case extractionFailed(String)
    case hashingFailed(String)
    case pixelBufferInvalid
    case accelerateFailed
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Media format is not supported"
        case .assetNotFound:
            return "Asset not found at specified URL"
        case .extractionFailed(let msg):
            return "Frame extraction failed: \(msg)"
        case .hashingFailed(let msg):
            return "Hashing failed: \(msg)"
        case .pixelBufferInvalid:
            return "Invalid pixel buffer"
        case .accelerateFailed:
            return "Accelerate framework operation failed"
        }
    }
}

// MARK: - Implementation

public class AVFoundationMediaProcessor: MediaProcessor {
    private let extractionQueue = DispatchQueue(label: "com.anigma.media-extract")
    private var stats = MediaProcessorStats()
    
    public init() {}
    
    public func extractFrames(from url: URL, timestamps: [CMTime]) throws -> [CVPixelBuffer] {
        let startTime = Date()
        defer {
            let elapsed = Date().timeIntervalSince(startTime)
            stats.totalExtractionTime += elapsed
            stats.extractionCount += 1
        }
        
        let asset = AVAsset(url: url)
        let reader = try AVAssetReader(asset: asset)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw MediaProcessorError.extractionFailed("No video track found")
        }
        
        let output = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA as NSNumber
            ]
        )
        
        reader.add(output)
        
        guard reader.startReading() else {
            throw MediaProcessorError.extractionFailed("Failed to start reading")
        }
        
        var frames: [CVPixelBuffer] = []
        var currentTime = CMTime.zero
        var targetIndex = 0
        
        while reader.status == .reading && targetIndex < timestamps.count {
            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                break
            }
            
            currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            if targetIndex < timestamps.count && CMTimeCompare(currentTime, timestamps[targetIndex]) >= 0 {
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    frames.append(pixelBuffer)
                    targetIndex += 1
                }
            }
        }
        
        reader.cancelReading()
        
        NSLog("MediaProcessor: extracted \(frames.count) frames from \(timestamps.count) requested")
        return frames
    }
    
    public func hash(pixelBuffer: CVPixelBuffer) throws -> Data {
        let startTime = Date()
        defer {
            let elapsed = Date().timeIntervalSince(startTime)
            stats.totalHashTime += elapsed
            stats.hashCount += 1
        }
        
        // Lock pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Get pixel data
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw MediaProcessorError.pixelBufferInvalid
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Compute perceptual hash using Accelerate
        // Simplified: compute histogram of luminance values
        var histogram = [Int32](repeating: 0, count: 256)
        
        let pixelBytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                // BGRA format: Blue=0, Green=1, Red=2, Alpha=3
                let idx = (y * bytesPerRow) + (x * 4)
                let b = pixelBytes[idx]
                let g = pixelBytes[idx + 1]
                let r = pixelBytes[idx + 2]
                
                // Compute luminance (ITU-R BT.709)
                let luminance = UInt8(Double(r) * 0.2126 + Double(g) * 0.7152 + Double(b) * 0.0722)
                histogram[Int(luminance)] += 1
            }
        }
        
        // Convert histogram to hash (quantized to 64 bytes)
        var hash = [UInt8](repeating: 0, count: 64)
        for (i, count) in histogram.enumerated() {
            let bin = i / 4  // 256 → 64
            let value = UInt8(min(255, count / 256))
            hash[bin] = max(hash[bin], value)
        }
        
        return Data(hash)
    }
    
    public func fingerprint(media url: URL) throws -> MediaFingerprint {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw MediaProcessorError.extractionFailed("No video track")
        }
        
        let naturalSize = videoTrack.naturalSize
        let width = Int(naturalSize.width)
        let height = Int(naturalSize.height)
        
        // Extract keyframes (every 5 seconds or every 30 frames)
        let keyframeInterval = 5.0
        let keyframeCount = max(1, Int(durationSeconds / keyframeInterval))
        
        var keyframeTimes: [CMTime] = []
        for i in 0..<keyframeCount {
            let seconds = Double(i) * keyframeInterval
            keyframeTimes.append(CMTime(seconds: seconds, preferredTimescale: 1000))
        }
        
        let keyframes = try extractFrames(from: url, timestamps: keyframeTimes)
        var keyframeHashes: [String] = []
        
        var combinedHash = [UInt8](repeating: 0, count: 64)
        for keyframe in keyframes {
            let hash = try hash(pixelBuffer: keyframe)
            keyframeHashes.append(hash.base64EncodedString())
            
            // XOR combine for overall hash
            for (i, byte) in hash.enumerated() {
                combinedHash[i] ^= byte
            }
        }
        
        let perceptualHash = Data(combinedHash).base64EncodedString()
        
        let frameCount = Int(CMTimeGetSeconds(duration) * 30.0)
        
        return MediaFingerprint(
            mediaURL: url.absoluteString,
            duration: Double(duration.value),
            durationSeconds: durationSeconds,
            width: width,
            height: height,
            frameCount: frameCount,
            perceptualHash: perceptualHash,
            keyFrameHashes: keyframeHashes
        )
    }
}

// MARK: - Statistics

public struct MediaProcessorStats {
    public var extractionCount: Int = 0
    public var hashCount: Int = 0
    
    public var totalExtractionTime: TimeInterval = 0
    public var totalHashTime: TimeInterval = 0
    
    public var averageExtractionTime: TimeInterval {
        extractionCount > 0 ? totalExtractionTime / TimeInterval(extractionCount) : 0
    }
    
    public var averageHashTime: TimeInterval {
        hashCount > 0 ? totalHashTime / TimeInterval(hashCount) : 0
    }
    
    public mutating func reset() {
        extractionCount = 0
        hashCount = 0
        totalExtractionTime = 0
        totalHashTime = 0
    }
    
    public var summary: String {
        return """
        Media Processor Statistics:
        - Frame extractions: \(extractionCount) (avg: \(String(format: "%.2f", averageExtractionTime * 1000))ms)
        - Hash operations: \(hashCount) (avg: \(String(format: "%.2f", averageHashTime * 1000))μs)
        """
    }
}
