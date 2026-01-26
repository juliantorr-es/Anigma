import XCTest
import CapsuleCore
import TelemetryCore
@testable import NewCapsule

final class NewCapsuleTests: XCTestCase {
    
    var capsule: NewCapsule!
    var diagnostics: MockDiagnostics!
    
    override func setUp() async throws {
        diagnostics = MockDiagnostics()
        capsule = try NewCapsule(id: "test-capsule", diagnostics: diagnostics)
    }
    
    // MARK: - Contract Tests
    
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
    
    // MARK: - Golden Tests
    
    func testGoldenOutput() async throws {
        let input = "Hello, Anigma!"
        let expectedOutput = "!amingA ,olleH" // Reverse of "Hello, Anigma!"
        
        let result = try await capsule.process(input)
        XCTAssertEqual(result, expectedOutput)
        
        // In a real scenario, you'd read from a file in the Golden directory
        // let goldenURL = Bundle.module.url(forResource: "example", withExtension: "txt", subdirectory: "Golden")
        // let expected = try String(contentsOf: goldenURL!)
        // XCTAssertEqual(result, expected)
    }
    
    // MARK: - Edge Cases
    
    func testEmojiInput() async throws {
        let input = "🚀✨"
        let result = try await capsule.process(input)
        XCTAssertEqual(result, "✨🚀")
    }
    
    func testLongInput() async throws {
        let input = String(repeating: "x", count: 1024 * 1024)
        let result = try await capsule.process(input)
        XCTAssertEqual(result.count, 1024 * 1024)
    }
}
