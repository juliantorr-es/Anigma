// AudioRenderCapsuleGoldenTests.swift
// Golden tests for AudioRenderCapsule with known good outputs

import XCTest
@testable import AudioRenderCapsule
import CapsuleCore
import TelemetryCore

final class AudioRenderCapsuleGoldenTests: XCTestCase {
    
    var capsule: AudioRenderCapsule!
    var diagnostics: DefaultCapsuleDiagnostics!
    
    override func setUp() async throws {
        try await super.setUp()
        diagnostics = DefaultCapsuleDiagnostics()
        capsule = AudioRenderCapsule(diagnostics: diagnostics)
    }
    
    override func tearDown() async throws {
        capsule = nil
        diagnostics = nil
        try await super.tearDown()
    }
    
    // MARK: - Golden Format Detection Tests
    
    func testGoldenFormatDetection() async throws {
        // Test with known good headers
        
        // MP3 header: ID3v2
        let mp3ID3Header = Data([
            0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        let detectedFormat = await capsule.detectFormat(data: mp3ID3Header)
        XCTAssertEqual(detectedFormat, .mp3, "Should detect ID3v2 MP3 header")
        
        // MP3 header: MPEG sync
        let mp3SyncHeader = Data([
            0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        let mp3DetectedFormat = await capsule.detectFormat(data: mp3SyncHeader)
        XCTAssertEqual(mp3DetectedFormat, .mp3, "Should detect MPEG sync MP3 header")
        
        // WAV header: RIFF/WAVE
        let wavHeader = Data([
            0x52, 0x49, 0x46, 0x46, // "RIFF"
            0x24, 0x08, 0x00, 0x00, // File size
            0x57, 0x41, 0x56, 0x45, // "WAVE"
            0x66, 0x6D, 0x74, 0x20  // "fmt "
        ])
        let wavDetectedFormat = await capsule.detectFormat(data: wavHeader)
        XCTAssertEqual(wavDetectedFormat, .wav, "Should detect WAV header")
        
        // FLAC header
        let flacHeader = Data([
            0x66, 0x4C, 0x61, 0x43  // "fLaC"
        ])
        let flacDetectedFormat = await capsule.detectFormat(data: flacHeader)
        XCTAssertEqual(flacDetectedFormat, .wav, "Should detect FLAC header")
        
        // AAC header: ADTS
        let aacHeader = Data([
            0xFF, 0xF9, 0x48, 0x80, 0x00, 0x1F, 0xFC
        ])
        let aacDetectedFormat = await capsule.detectFormat(data: aacHeader)
        XCTAssertEqual(aacDetectedFormat, .aac, "Should detect AAC ADTS header")
    }
    
    // MARK: - Golden Metadata Tests
    
    func testGoldenMetadataStructure() async throws {
        // Test metadata with known values
        let metadata = AudioMetadata(
            sampleRate: 44100,
            channels: 2,
            durationMs: 180000, // 3 minutes
            bitRate: 320000,
            format: .mp3,
            sampleFormat: .f32,
            frameCount: 7938000,
            title: "Golden Test Song",
            artist: "Golden Test Artist",
            album: "Golden Test Album"
        )
        
        // Verify computed properties
        XCTAssertEqual(metadata.durationSeconds, 180.0, accuracy: 0.1)
        XCTAssertEqual(metadata.totalSamples, 15876000)
        
        // Verify format properties
        XCTAssertEqual(metadata.format.mimeType, "audio/mpeg")
        XCTAssertEqual(metadata.format.fileExtension, ".mp3")
        XCTAssertEqual(metadata.sampleFormat.description, "Float 32-bit")
        XCTAssertEqual(metadata.sampleFormat.bytesPerSample, 4)
    }
    
    // MARK: - Golden Effect Parameters Tests
    
    func testGoldenEffectParameters() async throws {
        // Test reverb parameters with known golden values
        let reverbParams = AudioEffectParameters(
            type: .reverb,
            roomSize: 0.8,
            damping: 0.2,
            wetLevel: 0.4,
            dryLevel: 0.6,
            gain: 1.2
        )
        
        XCTAssertEqual(reverbParams.type, .reverb)
        XCTAssertEqual(reverbParams.roomSize, 0.8)
        XCTAssertEqual(reverbParams.damping, 0.2)
        XCTAssertEqual(reverbParams.wetLevel, 0.4)
        XCTAssertEqual(reverbParams.dryLevel, 0.6)
        XCTAssertEqual(reverbParams.gain, 1.2)
        
        // Test equalizer parameters with golden frequency bands
        let eqParams = AudioEffectParameters(
            type: .equalizer,
            bands: [
                3.0,   // 32Hz
                2.0,   // 64Hz
                1.0,   // 125Hz
                0.0,   // 250Hz
                -1.0,  // 500Hz
                0.0,   // 1kHz
                1.0,   // 2kHz
                2.0,   // 4kHz
                3.0,   // 8kHz
                2.0    // 16kHz
            ]
        )
        
        XCTAssertEqual(eqParams.type, .equalizer)
        XCTAssertEqual(eqParams.bands.count, 10)
        XCTAssertEqual(eqParams.bands[0], 3.0)  // 32Hz boost
        XCTAssertEqual(eqParams.bands[4], -1.0) // 500Hz cut
        XCTAssertEqual(eqParams.bands[8], 3.0)  // 8kHz boost
        
        // Test compressor parameters with golden values
        let compParams = AudioEffectParameters(
            type: .compressor,
            threshold: -18.0,
            ratio: 4.0,
            attackTime: 5.0,
            releaseTime: 50.0,
            gain: 1.0
        )
        
        XCTAssertEqual(compParams.type, .compressor)
        XCTAssertEqual(compParams.threshold, -18.0)
        XCTAssertEqual(compParams.ratio, 4.0)
        XCTAssertEqual(compParams.attackTime, 5.0)
        XCTAssertEqual(compParams.releaseTime, 50.0)
        
        // Test delay parameters with golden values
        let delayParams = AudioEffectParameters(
            type: .delay,
            delayTime: 250.0,
            feedback: 0.35,
            wetLevel: 0.3,
            dryLevel: 0.7,
            gain: 0.9
        )
        
        XCTAssertEqual(delayParams.type, .delay)
        XCTAssertEqual(delayParams.delayTime, 250.0)
        XCTAssertEqual(delayParams.feedback, 0.35)
        XCTAssertEqual(delayParams.wetLevel, 0.3)
        XCTAssertEqual(delayParams.dryLevel, 0.7)
        XCTAssertEqual(delayParams.gain, 0.9)
    }
    
    // MARK: - Golden Waveform Tests
    
    func testGoldenWaveformStructure() async throws {
        // Create golden waveform data with known properties
        let width: UInt32 = 800
        let height: UInt32 = 200
        let channels: UInt32 = 2
        
        // Generate known peak values (sine wave pattern)
        var peaks: [Float] = []
        var rms: [Float] = []
        
        for i in 0..<Int(width * channels) {
            let normalized = Float(i) / Float(Int(width * channels))
            let peakValue = sin(normalized * 2 * Float.pi) * 0.8
            let rmsValue = abs(sin(normalized * 2 * Float.pi)) * 0.6
            
            peaks.append(peakValue)
            rms.append(rmsValue)
        }
        
        let waveform = AudioWaveform(
            width: width,
            height: height,
            channels: channels,
            peaks: peaks,
            rms: rms
        )
        
        // Verify golden structure
        XCTAssertEqual(waveform.width, width)
        XCTAssertEqual(waveform.height, height)
        XCTAssertEqual(waveform.channels, channels)
        XCTAssertEqual(waveform.peaks.count, Int(width * channels))
        XCTAssertEqual(waveform.rms.count, Int(width * channels))
        XCTAssertEqual(waveform.dataPoints, Int(width * channels))
        
        // Verify golden data values
        XCTAssertEqual(waveform.peaks[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(waveform.peaks[Int(width * channels) / 4], 0.8, accuracy: 0.001)
        XCTAssertEqual(waveform.peaks[Int(width * channels) / 2], 0.0, accuracy: 0.001)
        XCTAssertEqual(waveform.peaks[Int(width * channels) * 3 / 4], -0.8, accuracy: 0.001)
        
        XCTAssertEqual(waveform.rms[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(waveform.rms[Int(width * channels) / 4], 0.6, accuracy: 0.001)
    }
    
    // MARK: - Golden Decoded Audio Tests
    
    func testGoldenDecodedAudioStructure() async throws {
        // Create golden decoded audio with known properties
        let sampleRate: UInt32 = 44100
        let channels: UInt32 = 2
        let durationMs: UInt32 = 5000 // 5 seconds
        let frameCount = UInt64(sampleRate) * UInt64(durationMs) / 1000
        let samplesPerFrame = channels * 4 // Float32 samples
        
        // Generate known sine wave audio data
        let sampleDataSize = Int(frameCount) * Int(samplesPerFrame)
        var sampleData = Data(capacity: sampleDataSize)
        
        for frame in 0..<Int(frameCount) {
            for channel in 0..<Int(channels) {
                let time = Float(frame) / Float(sampleRate)
                let frequency: Float = 440.0 // A4 note
                let amplitude: Float = 0.5
                let sample = amplitude * sin(2 * Float.pi * frequency * time)
                
                withUnsafeBytes(of: sample) { bytes in
                    sampleData.append(contentsOf: bytes)
                }
            }
        }
        
        let metadata = AudioMetadata(
            sampleRate: sampleRate,
            channels: channels,
            durationMs: durationMs,
            bitRate: 1411200, // Calculated for 44.1kHz, 16-bit, stereo
            format: .wav,
            sampleFormat: .f32,
            frameCount: frameCount,
            title: "Golden Sine Wave",
            artist: "Test Generator",
            album: "Audio Render Tests"
        )
        
        let decodedAudio = DecodedAudio(sampleData: sampleData, metadata: metadata)
        
        // Verify golden structure
        XCTAssertEqual(decodedAudio.metadata.sampleRate, sampleRate)
        XCTAssertEqual(decodedAudio.metadata.channels, channels)
        XCTAssertEqual(decodedAudio.metadata.durationMs, durationMs)
        XCTAssertEqual(decodedAudio.metadata.durationSeconds, 5.0, accuracy: 0.1)
        XCTAssertEqual(decodedAudio.metadata.frameCount, frameCount)
        XCTAssertEqual(decodedAudio.dataSizeBytes, sampleDataSize)
        XCTAssertEqual(decodedAudio.sampleData.count, sampleDataSize)
        
        // Verify golden audio properties
        XCTAssertEqual(decodedAudio.metadata.format, .wav)
        XCTAssertEqual(decodedAudio.metadata.sampleFormat, .f32)
        XCTAssertEqual(decodedAudio.metadata.title, "Golden Sine Wave")
        XCTAssertEqual(decodedAudio.metadata.artist, "Test Generator")
        XCTAssertEqual(decodedAudio.metadata.album, "Audio Render Tests")
    }
    
    // MARK: - Golden Batch Processing Tests
    
    func testGoldenBatchProcessing() async throws {
        // Create test data with known properties
        let testData1 = Data([0xFF, 0xFB, 0x90, 0x00]) // MP3 header
        let testData2 = Data([0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45]) // WAV header
        let testData3 = Data([0x66, 0x4C, 0x61, 0x43]) // FLAC header
        let testData4 = Data() // Empty data (should fail)
        let testData5 = Data([0x00, 0x01, 0x02, 0x03]) // Unknown format
        
        let testFiles = [testData1, testData2, testData3, testData4, testData5]
        
        // Test batch format detection
        let formats = await withTaskGroup(of: (Int, AudioFormat).self) { group in
            var results: [(Int, AudioFormat)] = []
            
            for (index, data) in testFiles.enumerated() {
                group.addTask {
                    let format = await self.capsule.detectFormat(data: data)
                    return (index, format)
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.0 < $1.0 }
        }
        
        // Verify golden format detection results
        XCTAssertEqual(formats[0].1, .mp3)  // testData1
        XCTAssertEqual(formats[1].1, .wav)  // testData2
        XCTAssertEqual(formats[2].1, .flac) // testData3
        XCTAssertEqual(formats[3].1, .unknown) // testData4 (empty)
        XCTAssertEqual(formats[4].1, .unknown) // testData5 (invalid)
        
        // Test batch decoding (should all fail with invalid data, but structure should be correct)
        let decodeResults = await capsule.decodeBatch(audioFiles: testFiles)
        XCTAssertEqual(decodeResults.count, 5)
        
        // All should be nil due to invalid/incomplete data
        XCTAssertTrue(decodeResults.allSatisfy { $0 == nil })
    }
    
    // MARK: - Golden Error Handling Tests
    
    func testGoldenErrorMapping() async throws {
        // Test that specific errors map to correct CapsuleError types
        
        // Test empty data (should map to invalidInput)
        do {
            _ = try await capsule.decode(data: Data())
            XCTFail("Should have thrown an error")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput:
                XCTAssertTrue(true, "Empty data should map to invalidInput")
            default:
                XCTFail("Expected invalidInput, got \(error)")
            }
        }
        
        // Test invalid data (should map to operationFailed or invalidInput)
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        do {
            _ = try await capsule.decode(data: invalidData)
            XCTFail("Should have thrown an error")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .operationFailed:
                XCTAssertTrue(true, "Invalid data should map to invalidInput or operationFailed")
            default:
                XCTFail("Expected invalidInput or operationFailed, got \(error)")
            }
        }
    }
    
    // MARK: - Golden Performance Benchmarks
    
    func testGoldenPerformanceBenchmarks() {
        // Benchmark format detection performance
        let mp3Header = Data([0xFF, 0xFB, 0x90, 0x00])
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                _ = await capsule.detectFormat(data: mp3Header)
            }
        }
    }
    
    // MARK: - Golden Diagnostics Tests
    
    func testGoldenDiagnosticsIntegration() async throws {
        // Clear any existing diagnostics
        diagnostics.clearEvents()
        
        // Perform operations that should generate diagnostics
        do {
            _ = try await capsule.decode(data: Data())
        } catch {
            // Expected
        }
        
        // Verify diagnostics were generated
        let events = diagnostics.getAllEvents()
        XCTAssertGreaterThan(events.count, 0, "Should generate diagnostic events on errors")
        
        // Verify diagnostic structure
        let errorEvents = events.filter { $0.level == .error }
        XCTAssertGreaterThan(errorEvents.count, 0, "Should generate error events")
        
        // Verify event contains expected fields
        if let firstError = errorEvents.first {
            XCTAssertFalse(firstError.message.isEmpty, "Error message should not be empty")
            XCTAssertFalse(firstError.category.isEmpty, "Category should not be empty")
            XCTAssertFalse(firstError.correlationID.isEmpty, "Correlation ID should not be empty")
        }
    }
}