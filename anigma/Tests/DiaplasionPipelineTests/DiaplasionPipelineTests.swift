// swiftlint:disable explicit_type_interface
import XCTest
import DiaplasionPipeline

internal final class DiaplasionPipelineTests: XCTestCase {
    internal func testHelpFlag() async throws {
        // Ensure the command can parse --help without crashing
        do {
            try await DiaplasionPipeline.main(["--help"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}