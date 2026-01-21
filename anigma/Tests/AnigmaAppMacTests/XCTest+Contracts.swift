import XCTest
import ContractsCore

extension XCTestCase {
    /// Asserts that an OperationResult is valid according to the system contract.
    /// - Parameters:
    ///   - result: The operation result to validate.
    ///   - expectedKind: The expected kind string (e.g. "pdfImport").
    ///   - file: The file where the assertion is called.
    ///   - line: The line where the assertion is called.
    func assertOperationValid<T>(
        _ result: OperationResult<T>,
        expectedKind: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // 1. Kind must match
        XCTAssertEqual(result.kind, expectedKind, "Operation kind mismatch", file: file, line: line)

        // 2. ID must be present
        XCTAssertNotNil(result.id, "Operation ID is missing", file: file, line: line)

        // 3. State must be valid
        switch result.state {
        case .running:
            XCTAssertNil(result.endTime, "Running operation should not have endTime", file: file, line: line)
            XCTAssertNil(result.failure, "Running operation should not have failure", file: file, line: line)
            XCTAssertNotNil(result.progress, "Running operation MUST have progress if > 0.2s (contract rule)", file: file, line: line)
        case .success:
            XCTAssertNotNil(result.endTime, "Success operation must have endTime", file: file, line: line)
            XCTAssertNotNil(result.payload, "Success operation must have payload", file: file, line: line)
            XCTAssertEqual(result.progress?.percent, 100, "Success progress must be 100", file: file, line: line)
            XCTAssertNil(result.failure, "Success operation should not have failure", file: file, line: line)
        case .failure:
            XCTAssertNotNil(result.endTime, "Failure operation must have endTime", file: file, line: line)
            XCTAssertNotNil(result.failure, "Failure operation must have failure object", file: file, line: line)
            XCTAssertNil(result.payload, "Failure operation should not have payload", file: file, line: line)

            // 4. Failure must have a code (Error Code Taxonomy)
            let code = result.failure?.code ?? ""
            XCTAssertFalse(code.isEmpty, "Failure code must not be empty", file: file, line: line)
            XCTAssertTrue(code.uppercased() == code, "Failure code should be UPPER_SNAKE_CASE", file: file, line: line)
        case .cancelled:
            XCTAssertNotNil(result.endTime, "Cancelled operation must have endTime", file: file, line: line)
        }
    }
}
