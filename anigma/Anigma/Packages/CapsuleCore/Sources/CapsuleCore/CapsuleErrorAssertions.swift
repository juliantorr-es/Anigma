// CapsuleErrorAssertions.swift
// CapsuleCore - Consistent error assertion utilities for the testing harness
// Part of the Anigma remediation plan

#if canImport(XCTest)
import XCTest
import Foundation

/// Assertion utilities for CapsuleError to verify structured error details.
/// 
/// These functions allow developers to assert on specific error cases and their 
/// associated metadata without relying solely on string matching.

/**
 Asserts that an expression throws or returns a `CapsuleError` matching specific criteria.
 
 - Parameters:
   - expression: The expression to evaluate (can be a throwing call or a value).
   - expectedCode: The `CapsuleErrorCode` expected.
   - messagePattern: Optional regex or substring to match against the error description.
   - underlyingCode: Optional internal code to match (applies to `.operationFailed` and `.nativeError`).
   - file: The file where the assertion is called (default is #file).
   - line: The line where the assertion is called (default is #line).
 */
public func XCTAssertCapsuleError(
    _ expression: @autoclosure () throws -> Any?,
    matches expectedCode: CapsuleErrorCode,
    message messagePattern: String? = nil,
    underlyingCode: Int? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let actualError: CapsuleError
    
    do {
        let result = try expression()
        if let error = result as? CapsuleError {
            actualError = error
        } else if let error = result as? Error {
            XCTFail("Expected CapsuleError but found different Error type: \(type(of: error)) (\(error))", file: file, line: line)
            return
        } else {
            XCTFail("Expected CapsuleError but found \(result == nil ? "nil" : String(describing: result!))", file: file, line: line)
            return
        }
    } catch let error as CapsuleError {
        actualError = error
    } catch {
        XCTFail("Expected CapsuleError but caught \(type(of: error)): \(error)", file: file, line: line)
        return
    }
    
    // 1. Verify Error Case (via errorCode)
    XCTAssertEqual(
        actualError.errorCode,
        expectedCode,
        "Error case mismatch. Expected \(expectedCode), but got \(actualError.errorCode)",
        file: file,
        line: line
    )
    
    // 2. Verify Message Pattern
    if let pattern = messagePattern {
        let description = actualError.localizedDescription
        XCTAssertTrue(
            description.localizedCaseInsensitiveContains(pattern),
            "Error message '\(description)' does not contain expected pattern '\(pattern)'",
            file: file,
            line: line
        )
    }
    
    // 3. Verify Underlying Code (if applicable)
    if let expectedUnderlying = underlyingCode {
        switch actualError {
        case .operationFailed(let code, _, _):
            XCTAssertEqual(
                Int(code), 
                expectedUnderlying, 
                "Underlying operation code mismatch. Expected \(expectedUnderlying), but got \(code)",
                file: file, 
                line: line
            )
        case .nativeError(let code, _):
            XCTAssertEqual(
                Int(code), 
                expectedUnderlying, 
                "Underlying native code mismatch. Expected \(expectedUnderlying), but got \(code)",
                file: file, 
                line: line
            )
        default:
            XCTFail(
                "Error case \(actualError.errorCode) does not have an underlying code to match. Metadata check failed.",
                file: file,
                line: line
            )
        }
    }
}

#endif
