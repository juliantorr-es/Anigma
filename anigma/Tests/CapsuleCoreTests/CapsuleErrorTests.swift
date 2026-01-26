// CapsuleErrorTests.swift
// CapsuleCore - Tests for canonical error model
// Part of the Anigma remediation plan

import XCTest
@testable import CapsuleCore

class CapsuleErrorTests: XCTestCase {
    
    // MARK: - Sendable Verification
    
    /// Verify CapsuleError conforms to Sendable
    func testSendableConformance() async {
        let error: CapsuleError = .invalidConfiguration(reason: "test")
        let task = Task { return error }
        let result = await task.value
        XCTAssertEqual(result, error)
    }
    
    // MARK: - Codable: Individual Cases
    
    func testCodeableInvalidConfiguration() throws {
        let original: CapsuleError = .invalidConfiguration(reason: "missing key")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapsuleError.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
    
    func testCodeableOperationFailed() throws {
        let original: CapsuleError = .operationFailed(code: 404, message: "not found", context: ["id": "123"])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapsuleError.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
    
    func testCodeableResourceExhausted() throws {
        let original: CapsuleError = .resourceExhausted(resource: "memory", limit: "1GB")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapsuleError.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
    
    func testCodeableInvalidInput() throws {
        let original: CapsuleError = .invalidInput(field: "email", constraint: "must contain @")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapsuleError.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
    
    func testCodeableNativeError() throws {
        let original: CapsuleError = .nativeError(code: -1, libraryName: "libffmpeg")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapsuleError.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
    
    func testCodeableTimeout() throws {
        let original: CapsuleError = .timeout(operation: "upload", deadline: 30.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapsuleError.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
    
    func testCodeableInternalError() throws {
        let original: CapsuleError = .internalError(details: "null pointer")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CapsuleError.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
    
    // MARK: - C Mapping: Lossless Roundtrip
    
    func testMappingRoundtripLossless() {
        let testCases: [CapsuleError] = [
            .invalidConfiguration(reason: "bad config"),
            .operationFailed(code: 1, message: "failed", context: ["key": "val"]),
            .resourceExhausted(resource: "cpu", limit: "100%"),
            .invalidInput(field: "username", constraint: "too short"),
            .nativeError(code: 42, libraryName: "libamfp"),
            .timeout(operation: "sync", deadline: 5.0),
            .internalError(details: "assertion failed")
        ]
        
        for original in testCases {
            let cRepr = capsuleErrorToC(original)
            let code = cRepr["code"] as? Int32 ?? 0
            let message = cRepr["message"] as? String ?? ""
            let context = cRepr["context"] as? String
            
            let reconstructed = capsuleErrorFromC(code: code, message: message, contextJson: context)
            
            XCTAssertEqual(original, reconstructed, "Roundtrip failed for \(original)")
        }
    }
    
    // MARK: - LocalizedError
    
    func testLocalizedErrorMessages() {
        let error: CapsuleError = .invalidInput(field: "test", constraint: "required")
        XCTAssertTrue(error.localizedDescription.contains("Invalid input for 'test'"))
    }
    
    // MARK: - JSON Serialization
    
    func testJsonString() {
        let error: CapsuleError = .timeout(operation: "test", deadline: 1.0)
        let json = error.jsonString
        XCTAssertNotNil(json)
        XCTAssertTrue(json!.contains("\"code\" : 6"))
    }
}
