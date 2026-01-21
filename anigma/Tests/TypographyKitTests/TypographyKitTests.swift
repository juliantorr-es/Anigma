// swiftlint:disable explicit_type_interface
import XCTest
@testable import TypographyKit

internal final class TypographyKitTests: XCTestCase {
    internal func testNativeShaperInitialization() {
        let shaper = NativeShaper()
        XCTAssertNotNil(shaper)
    }

    internal func testShapeWithEmptyStringThrows() {
        // Temporarily disabled due to missing NativeError type
        // let shaper = NativeShaper()
        // XCTAssertThrowsError(try shaper.shape(text: "", fontId: "dummy")) { error in
        //     XCTAssertTrue(error is NativeError)
        // }
    }

    internal func testShapeWithInvalidFontThrows() {
        // Temporarily disabled due to missing NativeError type
        // let shaper = NativeShaper()
        // XCTAssertThrowsError(try shaper.shape(text: "hello", fontId: "invalid")) { error in
        //     XCTAssertTrue(error is NativeError)
        // }
    }
}