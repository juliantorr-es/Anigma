import XCTest
import CapsuleCore
import TelemetryCore
@testable import VizAggregationCapsule

final class VizAggregationCapsuleContractTests: XCTestCase {
    
    var capsule: VizAggregationCapsule!
    
    override func setUp() async throws {
        capsule = try VizAggregationCapsule(id: "test-contract", diagnostics: MockDiagnostics())
    }
    
    /// Contract: Empty input must throw .invalidInput
    func testInvalidInputEmptyString() async {
        do {
            _ = try await capsule.process("")
            XCTFail("Should have thrown .invalidInput")
        } catch let error as CapsuleError {
            if case .invalidInput(let field, _) = error {
                XCTAssertEqual(field, "input")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    /// Contract: Input exceeding 1MB must throw .resourceExhausted
    func testResourceExhaustion() async {
        let largeInput = String(repeating: "a", count: 1024 * 1024 + 1)
        do {
            _ = try await capsule.process(largeInput)
            XCTFail("Should have thrown .resourceExhausted")
        } catch let error as CapsuleError {
            if case .resourceExhausted(let resource, _) = error {
                XCTAssertEqual(resource, "memory")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    /// Contract: Verify specific error properties
    func testErrorMetadata() async {
        do {
            _ = try await capsule.process("")
        } catch let error as CapsuleError {
            XCTAssertNotNil(error.errorDescription)
            // Contract check for localized description or other metadata
        } catch {
            XCTFail("Should have been a CapsuleError")
        }
    }
}
