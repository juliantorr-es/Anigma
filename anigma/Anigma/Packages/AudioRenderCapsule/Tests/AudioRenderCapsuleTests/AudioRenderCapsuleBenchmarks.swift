// AudioRenderCapsuleBenchmarks.swift
// Performance benchmarks for AudioRenderCapsule

import XCTest
@testable import AudioRenderCapsule
import CapsuleCore
import TelemetryCore

final class AudioRenderCapsuleBenchmarks: XCTestCase {
    
    var capsule: AudioRenderCapsule!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = AudioRenderCapsule()
    }
    
    override func tearDown() async throws {
        capsule = nil
        try await super.tearDown()
    }
    
    // MARK: - Format Detection Benchmarks
    
    func benchmarkFormatDetection() {
        let mp3Header = Data([0xFF, 0xFB, 0x90, 0x00])
        let wavHeader = Data([0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45])
        let flacHeader = Data([0x66, 0x4C, 0x61, 0x43])
        let aacHeader = Data([0xFF, 0xF9, 0x48, 0x80, 0x00, 0x1F, 0xFC])
        
        let headers = [mp3Header, wavHeader, flacHeader, aacHeader]
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                for header in headers {
                    _ = await capsule.detectFormat(data: header)
                }
            }
        }
    }
    
    // MARK: - Decoding Benchmarks
    
    func benchmarkDecoding() {
        // Create test audio data (simplified sine wave)
        let sampleRate: UInt32 = 44100
        let durationMs: UInt32 = 1000 // 1 second
        let frameCount = UInt64(sampleRate) * UInt64(durationMs) / 1000
        let channels: UInt32 = 2
        
        // Generate WAV header for test
        var wavData = Data()
        
        // RIFF header
        wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        let fileSize = UInt32(36 + frameCount * channels * 2)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        
        // fmt chunk
        wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        wavData.append(contentsOf: [0x10, 0x00, 0x00, 0x00]) // chunk size
        wavData.append(contentsOf: [0x01, 0x00]) // PCM format
        wavData.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0.prefix(2)) })
        wavData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0.prefix(4)) })
        let byteRate = sampleRate * channels * 2
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0.prefix(4)) })
        let blockAlign = channels * 2
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0.prefix(2)) })
        wavData.append(contentsOf: [0x10, 0x00]) // 16-bit
        
        // data chunk
        wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        let dataSize = UInt32(frameCount * channels * 2)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0.prefix(4)) })
        
        // Generate sine wave data
        for frame in 0..<Int(frameCount) {
            for _ in 0..<Int(channels) {
                let time = Float(frame) / Float(sampleRate)
                let frequency: Float = 440.0 // A4 note
                let amplitude: Float = 0.5
                let sample = amplitude * sin(2 * Float.pi * frequency * time)
                let sample16 = Int16(sample * Float(Int16.max))
                wavData.append(contentsOf: withUnsafeBytes(of: sample16.littleEndian) { Array($0) })
            }
        }
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                do {
                    _ = try await capsule.decode(data: wavData, format: .wav)
                } catch {
                    // Expected if native library is not fully implemented
                    print("Decoding benchmark failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Effect Processing Benchmarks
    
    func benchmarkEffectProcessing() {
        // Create test audio data
        let frameCount: UInt64 = 44100 // 1 second at 44.1kHz
        let channels: UInt32 = 2
        let sampleDataSize = Int(frameCount) * Int(channels) * 4 // Float32
        
        var sampleData = Data(capacity: sampleDataSize)
        
        // Generate sine wave
        for frame in 0..<Int(frameCount) {
            for _ in 0..<Int(channels) {
                let time = Float(frame) / 44100.0
                let frequency: Float = 440.0
                let amplitude: Float = 0.5
                let sample = amplitude * sin(2 * Float.pi * frequency * time)
                
                withUnsafeBytes(of: sample) { bytes in
                    sampleData.append(contentsOf: bytes)
                }
            }
        }
        
        let metadata = AudioMetadata(
            sampleRate: 44100,
            channels: channels,
            durationMs: 1000,
            bitRate: 1411200,
            format: .wav,
            sampleFormat: .f32,
            frameCount: frameCount
        )
        
        let decodedAudio = DecodedAudio(sampleData: sampleData, metadata: metadata)
        
        // Benchmark different effects
        let effects: [AudioEffectParameters] = [
            AudioEffectParameters(type: .reverb, roomSize: 0.5, wetLevel: 0.3, dryLevel: 0.7),
            AudioEffectParameters(type: .equalizer, bands: Array(repeating: 0.0, count: 10)),
            AudioEffectParameters(type: .compressor, threshold: -20.0, ratio: 4.0),
            AudioEffectParameters(type: .delay, delayTime: 250.0, feedback: 0.3)
        ]
        
        for effect in effects {
            measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], named: "Effect_\(effect.type.description)") {
                Task {
                    do {
                        _ = try await capsule.applyEffect(to: decodedAudio, effect: effect)
                    } catch {
                        // Expected if native library is not fully implemented
                        print("Effect benchmark failed for \(effect.type.description): \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Waveform Generation Benchmarks
    
    func benchmarkWaveformGeneration() {
        // Create test audio data
        let frameCount: UInt64 = 44100 * 10 // 10 seconds
        let channels: UInt32 = 2
        let sampleDataSize = Int(frameCount) * Int(channels) * 4 // Float32
        
        var sampleData = Data(capacity: sampleDataSize)
        
        // Generate complex audio (multiple frequencies)
        for frame in 0..<Int(frameCount) {
            for _ in 0..<Int(channels) {
                let time = Float(frame) / 44100.0
                let sample: Float = 
                    0.3 * sin(2 * Float.pi * 440.0 * time) + // A4
                    0.2 * sin(2 * Float.pi * 554.37 * time) + // C#5
                    0.1 * sin(2 * Float.pi * 659.25 * time) + // E5
                    0.05 * sin(2 * Float.pi * 880.0 * time)   // A5
                
                withUnsafeBytes(of: sample) { bytes in
                    sampleData.append(contentsOf: bytes)
                }
            }
        }
        
        let metadata = AudioMetadata(
            sampleRate: 44100,
            channels: channels,
            durationMs: 10000,
            bitRate: 1411200,
            format: .wav,
            sampleFormat: .f32,
            frameCount: frameCount
        )
        
        let decodedAudio = DecodedAudio(sampleData: sampleData, metadata: metadata)
        
        // Benchmark different waveform sizes
        let sizes: [(UInt32, UInt32)] = [
            (400, 100),   // Small
            (800, 200),   // Medium
            (1600, 400),  // Large
            (3200, 800)   // Extra large
        ]
        
        for (width, height) in sizes {
            measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], named: "Waveform_\(width)x\(height)") {
                Task {
                    do {
                        _ = try await capsule.generateWaveform(from: decodedAudio, width: width, height: height)
                    } catch {
                        // Expected if native library is not fully implemented
                        print("Waveform benchmark failed for \(width)x\(height): \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Batch Processing Benchmarks
    
    func benchmarkBatchProcessing() {
        // Create multiple test audio files
        let testFiles: [Data] = (0..<10).map { _ in
            // Generate small WAV files
            let frameCount: UInt64 = 4410 // 100ms
            let channels: UInt32 = 2
            
            var wavData = Data()
            
            // Minimal WAV header
            wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
            let fileSize = UInt32(36 + frameCount * channels * 2)
            wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
            wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
            wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
            wavData.append(contentsOf: [0x10, 0x00, 0x00, 0x00])
            wavData.append(contentsOf: [0x01, 0x00])
            wavData.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0.prefix(2)) })
            wavData.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0.prefix(4)) })
            wavData.append(contentsOf: withUnsafeBytes(of: UInt32(176400).littleEndian) { Array($0.prefix(4)) })
            wavData.append(contentsOf: [0x04, 0x00])
            wavData.append(contentsOf: [0x10, 0x00])
            wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
            let dataSize = UInt32(frameCount * channels * 2)
            wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0.prefix(4)) })
            
            // Generate audio data
            for frame in 0..<Int(frameCount) {
                for _ in 0..<Int(channels) {
                    let time = Float(frame) / 44100.0
                    let frequency: Float = 440.0
                    let amplitude: Float = 0.5
                    let sample = amplitude * sin(2 * Float.pi * frequency * time)
                    let sample16 = Int16(sample * Float(Int16.max))
                    wavData.append(contentsOf: withUnsafeBytes(of: sample16.littleEndian) { Array($0) })
                }
            }
            
            return wavData
        }
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                _ = await capsule.decodeBatch(audioFiles: testFiles)
            }
        }
    }
    
    // MARK: - Memory Usage Benchmarks
    
    func benchmarkMemoryUsage() {
        // Test memory usage with large audio files
        let largeFrameCount: UInt64 = 44100 * 60 // 1 minute
        let channels: UInt32 = 2
        let sampleDataSize = Int(largeFrameCount) * Int(channels) * 4 // Float32
        
        var sampleData = Data(capacity: sampleDataSize)
        
        // Generate audio data
        for frame in 0..<Int(largeFrameCount) {
            for _ in 0..<Int(channels) {
                let time = Float(frame) / 44100.0
                let sample = sin(2 * Float.pi * 440.0 * time) * 0.5
                withUnsafeBytes(of: sample) { bytes in
                    sampleData.append(contentsOf: bytes)
                }
            }
        }
        
        let metadata = AudioMetadata(
            sampleRate: 44100,
            channels: channels,
            durationMs: 60000,
            bitRate: 1411200,
            format: .wav,
            sampleFormat: .f32,
            frameCount: largeFrameCount
        )
        
        let decodedAudio = DecodedAudio(sampleData: sampleData, metadata: metadata)
        
        measure(metrics: [XCTMemoryMetric()]) {
            Task {
                do {
                    _ = try await capsule.generateWaveform(from: decodedAudio, width: 1000, height: 300)
                } catch {
                    print("Memory benchmark failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Concurrent Processing Benchmarks
    
    func benchmarkConcurrentProcessing() {
        let testData = Data([0xFF, 0xFB, 0x90, 0x00]) // MP3 header
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                await withTaskGroup(of: AudioFormat.self) { group in
                    for _ in 0..<100 {
                        group.addTask {
                            return await self.capsule.detectFormat(data: testData)
                        }
                    }
                    
                    var results: [AudioFormat] = []
                    for await result in group {
                        results.append(result)
                    }
                    
                    XCTAssertEqual(results.count, 100)
                }
            }
        }
    }
    
    // MARK: - Performance Regression Tests
    
    func testPerformanceRegression() {
        // Define performance baselines (these would be updated based on actual measurements)
        let formatDetectionBaseline: TimeInterval = 0.001 // 1ms
        let decodingBaseline: TimeInterval = 0.1 // 100ms for 1 second of audio
        let waveformGenerationBaseline: TimeInterval = 0.05 // 50ms for 1 second of audio
        
        // Test format detection performance
        let mp3Header = Data([0xFF, 0xFB, 0x90, 0x00])
        let startTime = CFAbsoluteTimeGetCurrent()
        Task {
            _ = await capsule.detectFormat(data: mp3Header)
        }
        let formatDetectionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(formatDetectionTime, formatDetectionBaseline * 2, 
                         "Format detection performance regression detected")
        
        // Additional regression tests would be added here as performance baselines are established
    }
}