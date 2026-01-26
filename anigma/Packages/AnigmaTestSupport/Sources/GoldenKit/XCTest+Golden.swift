import XCTest
import Foundation

extension XCTestCase {
    /// Asserts that the provided data matches the golden file at the given relative path.
    /// - Parameters:
    ///   - actual: The data produced by the test.
    ///   - goldenPath: Path relative to 'Packages/', e.g., 'FooCapsule/output.golden'
    public func XCTAssertGolden(
        _ actual: Data,
        _ goldenPath: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            try GoldenTestHarness.shared.compare(actual, against: goldenPath, file: file, line: line)
        } catch {
            XCTFail("Golden assertion failed: \(error)", file: file, line: line)
        }
    }
    
    /// Asserts that the provided string matches the golden file at the given relative path.
    /// - Parameters:
    ///   - actual: The string produced by the test.
    ///   - goldenPath: Path relative to 'Packages/', e.g., 'FooCapsule/output.golden'
    ///   - normalize: Optional closure to apply normalization before comparison.
    public func XCTAssertGoldenString(
        _ actual: String,
        _ goldenPath: String,
        normalize: Bool = true,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let finalString = normalize ? CanonicalNormalization.canonicalize(actual) : actual
        let actualData = Data(finalString.utf8)
        
        do {
            try GoldenTestHarness.shared.compare(actualData, against: goldenPath, file: file, line: line)
        } catch {
            XCTFail("Golden string assertion failed: \(error)", file: file, line: line)
        }
    }

    /// Asserts that the provided JSON data matches the golden file, with deterministic normalization.
    public func XCTAssertGoldenJSON(
        _ actual: Data,
        _ goldenPath: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            let normalized = try CanonicalNormalization.normalizeJSON(actual)
            try GoldenTestHarness.shared.compare(normalized, against: goldenPath, file: file, line: line)
        } catch {
            XCTFail("Golden JSON assertion failed: \(error)", file: file, line: line)
        }
    }
}
