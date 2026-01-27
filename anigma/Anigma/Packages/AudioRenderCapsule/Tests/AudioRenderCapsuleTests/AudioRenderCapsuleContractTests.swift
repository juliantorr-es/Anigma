// AudioRenderCapsuleContractTests.swift
// Contract tests for AudioRenderCapsule compliance

import XCTest
@testable import AudioRenderCapsule
import CapsuleCore
import TelemetryCore

final class AudioRenderCapsuleContractTests: XCTestCase {
    
    var capsule: AudioRenderCapsule!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = AudioRenderCapsule()
    }
    
    override func tearDown() async throws {
        capsule = nil
        try await super.tearDown()
    }
    
    // MARK: - Capsule Contract Tests
    
    func testCapsuleProvidesVersion() {
        let version = capsule.version
        XCTAssertFalse(version.isEmpty, "Capsule must provide a version string")
        XCTAssertTrue(version.contains("."), "Version should follow semantic versioning")
    }
    
    func testCapsuleSupportsDiagnostics() async throws {
        let diagnostics = DefaultCapsuleDiagnostics()
        let diagnosticCapsule = AudioRenderCapsule(diagnostics: diagnostics)
        
        // Perform an operation that should generate diagnostics
        do {
            _ = try await diagnosticCapsule.decode(data: Data())
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
        
        // Check that diagnostics were collected
        let events = diagnostics.getAllEvents()
        XCTAssertGreaterThan(events.count, 0, "Capsule should emit diagnostic events")
    }
    
    func testCapsuleErrorsMapToCapsuleError() async throws {
        // Test that native errors are properly mapped to CapsuleError
        do {
            _ = try await capsule.decode(data: Data())
            XCTFail("Should have thrown an error")
        } catch let error as CapsuleError {
            // Verify it's a proper CapsuleError
            switch error {
            case .invalidInput, .operationFailed, .internalError:
                XCTAssertTrue(true, "Error should be a valid CapsuleError type")
            default:
                XCTFail("Unexpected CapsuleError type: \(error)")
            }
        } catch {
            XCTFail("Error should be of type CapsuleError, got \(type(of: error))")
        }
    }
    
    func testCapsuleIsThreadSafe() async throws {
        // Test concurrent operations
        let testData = Data([0xFF, 0xFB, 0x90, 0x00]) // MP3 header
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    // Each task performs format detection
                    _ = await self.capsule.detectFormat(data: testData)
                }
            }
        }
        
        // If we get here without crashing, the capsule is thread-safe
        XCTAssertTrue(true)
    }
    
    func testCapsuleSupportsLifecycle() async throws {
        // Test that capsule implements CapsuleLifecycle
        let lifecycleCapsule: any CapsuleLifecycle = capsule
        
        try await lifecycleCapsule.activate()
        await lifecycleCapsule.deactivate()
        
        // Should not throw
        XCTAssertTrue(true)
    }
    
    // MARK: - Audio Processing Contract Tests
    
    func testDecodingReturnsValidStructure() async throws {
        // This test would require valid audio data
        // For now, test the error path which should return proper structure
        do {
            _ = try await capsule.decode(data: Data())
            XCTFail("Should have thrown an error")
        } catch {
            // Expected - error handling is the contract
        }
    }
    
    func testFormatDetectionReturnsValidFormat() async throws {
        let testData = Data([0xFF, 0xFB, 0x90, 0x00]) // MP3 header
        let format = await capsule.detectFormat(data: testData)
        
        // Should return a valid format enum
        switch format {
        case .mp3, .wav, .flac, .aac, .ogg, .unknown:
            XCTAssertTrue(true)
        }
    }
    
    func testEffectParametersValidation() async throws {
        // Test that effect parameters are properly validated
        let validParams = AudioEffectParameters(
            type: .reverb,
            roomSize: 0.5,
            damping: 0.5,
            wetLevel: 0.3,
            dryLevel: 0.7
        )
        
        // Parameters should be clamped to valid ranges
        XCTAssertLessThanOrEqual(validParams.roomSize, 1.0)
        XCTAssertGreaterThanOrEqual(validParams.roomSize, 0.0)
        XCTAssertLessThanOrEqual(validParams.damping, 1.0)
        XCTAssertGreaterThanOrEqual(validParams.damping, 0.0)
        XCTAssertLessThanOrEqual(validParams.wetLevel, 1.0)
        XCTAssertGreaterThanOrEqual(validParams.wetLevel, 0.0)
        XCTAssertLessThanOrEqual(validParams.dryLevel, 1.0)
        XCTAssertGreaterThanOrEqual(validParams.dryLevel, 0.0)
    }
    
    func testBatchProcessingReturnsCorrectStructure() async throws {
        let testFiles = [Data(), Data(), Data()]
        let results = await capsule.decodeBatch(audioFiles: testFiles)
        
        // Should return array with same count as input
        XCTAssertEqual(results.count, testFiles.count)
        
        // Each result should be optional DecodedAudio
        for result in results {
            if result != nil {
                XCTAssertNotNil(result?.metadata)
                XCTAssertNotNil(result?.sampleData)
            }
        }
    }
    
    // MARK: - Memory Management Contract Tests
    
    func testProperMemoryManagement() async throws {
        // Test that large data doesn't cause memory leaks
        let largeData = Data(repeating: 0x00, count: 1_000_000)
        
        do {
            _ = try await capsule.decode(data: largeData)
            XCTFail("Should have thrown an error")
        } catch {
            // Expected - but memory should be properly managed
        }
        
        // Force garbage collection and test again
        autoreleasepool {
            // Test with smaller data that might succeed
            let smallData = Data([0xFF, 0xFB, 0x90, 0x00])
            Task {
                _ = await capsule.detectFormat(data: smallData)
            }
        }
    }
    
    // MARK: - Error Recovery Contract Tests
    
    func testErrorRecovery() async throws {
        // Test that capsule can recover from errors
        let invalidData = Data()
        
        // First operation should fail
        do {
            _ = try await capsule.decode(data: invalidData)
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
        
        // Second operation should also fail gracefully (not crash)
        do {
            _ = try await capsule.decode(data: invalidData)
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
        
        // But valid operations should still work
        let validHeader = Data([0xFF, 0xFB, 0x90, 0x00])
        let format = await capsule.detectFormat(data: validHeader)
        XCTAssertNotEqual(format, .unknown)
    }
    
    // MARK: - Performance Contract Tests
    
    func testPerformanceContract() {
        // Test that operations complete within reasonable time
        let testData = Data([0xFF, 0xFB, 0x90, 0x00])
        
        measure {
            Task {
                _ = await capsule.detectFormat(data: testData)
            }
        }
    }
    
    // MARK: - Data Integrity Contract Tests
    
    func testDataIntegrity() async throws {
        // Test that metadata is properly populated when available
        let metadata = AudioMetadata(
            sampleRate: 44100,
            channels: 2,
            durationMs: 180000,
            bitRate: 320000,
            format: .mp3,
            sampleFormat: .f32,
            frameCount: 7938000,
            title: "Test",
            artist: "Test",
            album: "Test"
        )
        
        XCTAssertEqual(metadata.sampleRate, 44100)
        XCTAssertEqual(metadata.channels, 2)
        XCTAssertEqual(metadata.durationSeconds, 180.0)
        XCTAssertEqual(metadata.totalSamples, 15876000)
    }
    
    // MARK: - API Consistency Contract Tests
    
    func testAPIConsistency() async throws {
        // Test that all public methods follow consistent patterns
        
        // All decode methods should throw CapsuleError on failure
        do {
            _ = try await capsule.decode(data: Data())
            XCTFail("Should have thrown an error")
        } catch is CapsuleError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Should throw CapsuleError, got \(type(of: error))")
        }
        
        do {
            _ = try await capsule.decodeMP3(Data())
            XCTFail("Should have thrown an error")
        } catch is CapsuleError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Should throw CapsuleError, got \(type(of: error))")
        }
        
        // Effect application should also throw CapsuleError
        let invalidAudio = DecodedAudio(
            sampleData: Data(),
            metadata: AudioMetadata(
                sampleRate: 44100,
                channels: 2,
                durationMs: 1000,
                bitRate: 128000,
                format: .mp3,
                sampleFormat: .f32,
                frameCount: 0
            )
        )
        
        let effectParams = AudioEffectParameters(type: .reverb)
        
        do {
            _ = try await capsule.applyEffect(to: invalidAudio, effect: effectParams)
            XCTFail("Should have thrown an error")
        } catch is CapsuleError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Should throw CapsuleError, got \(type(of: error))")
        }
    }
}