// swiftlint:disable explicit_type_interface
import XCTest
import ColorKit

internal final class ColorKitTests: XCTestCase {
    internal func testNativeColorTransformInitialization() {
        let transform = NativeColorTransform()
        XCTAssertNotNil(transform)
    }

    internal func testTransformWithInvalidProfilesThrows() {
        let transform = NativeColorTransform()
        let pixelData = Data([0, 0, 0, 0])
        let invalidProfile = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertThrowsError(try transform.transform(pixelData: pixelData, from: invalidProfile, to: invalidProfile)) { error in
            XCTAssertTrue(error is NativeError)
        }
    }

    internal func testTransformWithEmptyPixelData() {
        let transform = NativeColorTransform()
        let emptyData = Data()
        let invalidProfile = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertThrowsError(try transform.transform(pixelData: emptyData, from: invalidProfile, to: invalidProfile)) { error in
            XCTAssertTrue(error is NativeError)
        }
    }
}