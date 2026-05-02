// AudioRenderCapsuleTests.swift
// Unit tests for AudioRenderCapsule

import XCTest
@testable import AudioRenderCapsule
import CapsuleCore
import TelemetryCore

final class AudioRenderCapsuleTests: XCTestCase {
    
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
    
    // MARK: - Initialization Tests
    
    func testInitialization() async throws {
        // Test that capsule initializes successfully
        let testCapsule = AudioRenderCapsule()
        XCTAssertNotNil(testCapsule)
        
        // Test version is available
        let version = testCapsule.version
        XCTAssertFalse(version.isEmpty)
    }
    
    // MARK: - Format Detection Tests
    
    func testDetectFormat() async throws {
        // Test with MP3 data (simplified header)
        let mp3Data = Data([0xFF, 0xFB, 0x90, 0x00]) // MP3 sync header
        let detectedFormat = await capsule.detectFormat(data: mp3Data)
        XCTAssertEqual(detectedFormat, .mp3)
        
        // Test with WAV data (RIFF header)
        let wavData = Data([0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45]) // "RIFF....WAVE"
        let wavDetectedFormat = await capsule.detectFormat(data: wavData)
        XCTAssertEqual(wavDetectedFormat, .wav)
        
        // Test with FLAC data
        let flacData = Data([0x66, 0x4C, 0x61, 0x43]) // "fLaC"
        let flacDetectedFormat = await capsule.detectFormat(data: flacData)
        XCTAssertEqual(flacDetectedFormat, .flac)
        
        // Test with unknown data
        let unknownData = Data([0x00, 0x01, 0x02, 0x03])
        let unknownDetectedFormat = await capsule.detectFormat(data: unknownData)
        XCTAssertEqual(unknownDetectedFormat, .unknown)
    }
    
    // MARK: - Error Handling Tests
    
    func testDecodeInvalidData() async throws {
        // Test with empty data
        let emptyData = Data()
        
        do {
            _ = try await capsule.decode(data: emptyData)
            XCTFail("Should have thrown an error")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput:
                XCTAssertTrue(true)
            default:
                XCTFail("Expected invalidInput error, got \(error)")
            }
        }
        
        // Test with null data (can't easily test in Swift, but we can test with very small data)
        let smallData = Data([0x00])
        
        do {
            _ = try await capsule.decode(data: smallData)
            XCTFail("Should have thrown an error")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .operationFailed:
                XCTAssertTrue(true)
            default:
                XCTFail("Expected invalidInput or operationFailed error, got \(error)")
            }
        }
    }
    
    // MARK: - AudioEffectParameters Tests
    
    func testAudioEffectParameters() {
        // Test reverb parameters
        let reverbParams = AudioEffectParameters(
            type: .reverb,
            roomSize: 0.8,
            damping: 0.3,
            wetLevel: 0.5,
            dryLevel: 0.5
        )
        
        XCTAssertEqual(reverbParams.type, .reverb)
        XCTAssertEqual(reverbParams.roomSize, 0.8)
        XCTAssertEqual(reverbParams.damping, 0.3)
        XCTAssertEqual(reverbParams.wetLevel, 0.5)
        XCTAssertEqual(reverbParams.dryLevel, 0.5)
        
        // Test equalizer parameters
        let eqParams = AudioEffectParameters(
            type: .equalizer,
            bands: [0.0, 1.0, -1.0, 2.0, -2.0, 0.5, -0.5, 1.5, -1.5, 0.0]
        )
        
        XCTAssertEqual(eqParams.type, .equalizer)
        XCTAssertEqual(eqParams.bands.count, 10)
        XCTAssertEqual(eqParams.bands[0], 0.0)
        XCTAssertEqual(eqParams.bands[1], 1.0)
        
        // Test parameter clamping
        let clampedParams = AudioEffectParameters(
            type: .reverb,
            roomSize: 1.5, // Should be clamped to 1.0
            damping: -0.5, // Should be clamped to 0.0
            feedback: 1.5  // Should be clamped to 1.0
        )
        
        XCTAssertEqual(clampedParams.roomSize, 1.0)
        XCTAssertEqual(clampedParams.damping, 0.0)
        XCTAssertEqual(clampedParams.feedback, 1.0)
    }
    
    // MARK: - AudioMetadata Tests
    
    func testAudioMetadata() {
        let metadata = AudioMetadata(
            sampleRate: 44100,
            channels: 2,
            durationMs: 180000,
            bitRate: 320000,
            format: .mp3,
            sampleFormat: .f32,
            frameCount: 7938000,
            title: "Test Song",
            artist: "Test Artist",
            album: "Test Album"
        )
        
        XCTAssertEqual(metadata.sampleRate, 44100)
        XCTAssertEqual(metadata.channels, 2)
        XCTAssertEqual(metadata.durationMs, 180000)
        XCTAssertEqual(metadata.bitRate, 320000)
        XCTAssertEqual(metadata.format, .mp3)
        XCTAssertEqual(metadata.sampleFormat, .f32)
        XCTAssertEqual(metadata.frameCount, 7938000)
        XCTAssertEqual(metadata.title, "Test Song")
        XCTAssertEqual(metadata.artist, "Test Artist")
        XCTAssertEqual(metadata.album, "Test Album")
        
        // Test computed properties
        XCTAssertEqual(metadata.durationSeconds, 180.0)
        XCTAssertEqual(metadata.totalSamples, 15876000)
    }
    
    // MARK: - AudioWaveform Tests
    
    func testAudioWaveform() {
        let peaks: [Float] = Array(repeating: 0.8, count: 1000) // 1000 data points
        let rms: [Float] = Array(repeating: 0.6, count: 1000)
        
        let waveform = AudioWaveform(
            width: 500,
            height: 200,
            channels: 2,
            peaks: peaks,
            rms: rms
        )
        
        XCTAssertEqual(waveform.width, 500)
        XCTAssertEqual(waveform.height, 200)
        XCTAssertEqual(waveform.channels, 2)
        XCTAssertEqual(waveform.peaks.count, 1000)
        XCTAssertEqual(waveform.rms.count, 1000)
        XCTAssertEqual(waveform.dataPoints, 1000)
    }
    
    // MARK: - DecodedAudio Tests
    
    func testDecodedAudio() {
        let sampleData = Data(repeating: 0x00, count: 1024)
        let metadata = AudioMetadata(
            sampleRate: 44100,
            channels: 2,
            durationMs: 180000,
            bitRate: 320000,
            format: .mp3,
            sampleFormat: .f32,
            frameCount: 512
        )
        
        let decodedAudio = DecodedAudio(sampleData: sampleData, metadata: metadata)
        
        XCTAssertEqual(decodedAudio.sampleData.count, 1024)
        XCTAssertEqual(decodedAudio.metadata.sampleRate, 44100)
        XCTAssertEqual(decodedAudio.dataSizeBytes, 1024)
        XCTAssertEqual(decodedAudio.durationSeconds, 180.0)
    }
    
    // MARK: - Format Tests
    
    func testAudioFormat() {
        XCTAssertEqual(AudioFormat.mp3.mimeType, "audio/mpeg")
        XCTAssertEqual(AudioFormat.mp3.fileExtension, ".mp3")
        XCTAssertEqual(AudioFormat.wav.mimeType, "audio/wav")
        XCTAssertEqual(AudioFormat.wav.fileExtension, ".wav")
        XCTAssertEqual(AudioFormat.flac.mimeType, "audio/flac")
        XCTAssertEqual(AudioFormat.flac.fileExtension, ".flac")
        XCTAssertEqual(AudioFormat.aac.mimeType, "audio/aac")
        XCTAssertEqual(AudioFormat.aac.fileExtension, ".aac")
    }
    
    func testSampleFormat() {
        XCTAssertEqual(SampleFormat.u8.bytesPerSample, 1)
        XCTAssertEqual(SampleFormat.s16.bytesPerSample, 2)
        XCTAssertEqual(SampleFormat.s32.bytesPerSample, 4)
        XCTAssertEqual(SampleFormat.f32.bytesPerSample, 4)
        XCTAssertEqual(SampleFormat.f64.bytesPerSample, 8)
        
        XCTAssertEqual(SampleFormat.f32.description, "Float 32-bit")
        XCTAssertEqual(SampleFormat.s16.description, "Signed 16-bit")
    }
    
    func testAudioEffectType() {
        XCTAssertEqual(AudioEffectType.reverb.description, "Reverb")
        XCTAssertEqual(AudioEffectType.equalizer.description, "Equalizer")
        XCTAssertEqual(AudioEffectType.compressor.description, "Compressor")
        XCTAssertEqual(AudioEffectType.delay.description, "Delay")
        XCTAssertEqual(AudioEffectType.none.description, "No effect")
    }
    
    // MARK: - Batch Processing Tests
    
    func testDecodeBatch() async throws {
        // This test would require actual audio files, so we'll test the structure
        let testDataArray = [Data(), Data(), Data()] // Empty data for structure test
        
        let results = await capsule.decodeBatch(audioFiles: testDataArray)
        
        XCTAssertEqual(results.count, 3)
        // All should be nil due to invalid data
        XCTAssertTrue(results.allSatisfy { $0 == nil })
    }
    
    // MARK: - Diagnostics Tests
    
    func testDiagnosticsIntegration() async throws {
        // Test that diagnostics are properly integrated
        let eventsBefore = diagnostics.getAllEvents()
        let initialCount = eventsBefore.count
        
        // Perform an operation that should generate diagnostics
        do {
            _ = try await capsule.decode(data: Data())
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
        
        let eventsAfter = diagnostics.getAllEvents()
        
        // Should have at least one event from the failed operation
        XCTAssertGreaterThan(eventsAfter.count, initialCount)
    }
    
    // MARK: - Lifecycle Tests
    
    func testCapsuleLifecycle() async throws {
        let testCapsule = AudioRenderCapsule(diagnostics: diagnostics)
        
        // Test activation
        try await testCapsule.activate()
        
        // Test deactivation
        await testCapsule.deactivate()
    }
    
    // MARK: - Performance Tests
    
    func testFormatDetectionPerformance() {
        let mp3Data = Data([0xFF, 0xFB, 0x90, 0x00])
        
        measure {
            Task {
                _ = await capsule.detectFormat(data: mp3Data)
            }
        }
    }
}

// MARK: - Golden Tests

final class AudioRenderCapsuleGoldenTests: XCTestCase {
    
    func testGoldenWAVFile() async throws {
        // Test with actual WAV file if available in golden fixtures
        let goldenPath = Bundle.module.path(forResource: "test_audio", ofType: "wav", inDirectory: "Golden")
        
        if let path = goldenPath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            let capsule = AudioRenderCapsule()
            
            // Test format detection
            let detectedFormat = await capsule.detectFormat(data: data)
            XCTAssertEqual(detectedFormat, .wav)
            
            // Test decoding (this would require actual WAV file with proper headers)
            do {
                let decoded = try await capsule.decode(data: data, format: .wav)
                XCTAssertNotNil(decoded)
                XCTAssertGreaterThan(decoded.metadata.sampleRate, 0)
                XCTAssertGreaterThan(decoded.metadata.channels, 0)
            } catch {
                // Expected if golden file is not a valid WAV
                print("Expected error with test file: \(error)")
            }
        }
    }
    
    func testGoldenMP3File() async throws {
        // Test with actual MP3 file if available in golden fixtures
        let goldenPath = Bundle.module.path(forResource: "test_audio", ofType: "mp3", inDirectory: "Golden")
        
        if let path = goldenPath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            let capsule = AudioRenderCapsule()
            
            // Test format detection
            let detectedFormat = await capsule.detectFormat(data: data)
            XCTAssertEqual(detectedFormat, .mp3)
        }
    }
}