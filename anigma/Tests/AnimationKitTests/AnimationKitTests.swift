// swiftlint:disable explicit_type_interface
import XCTest
import AnimationKit

internal final class AnimationKitTests: XCTestCase {
    internal func testNativeAnimationInitialization() {
        // Should create without throwing
        let animation = NativeAnimation()
        XCTAssertNotNil(animation)
    }

    internal func testLoadInvalidDataThrows() {
        let animation = NativeAnimation()
        XCTAssertThrowsError(try animation.load(data: Data())) { error in
            XCTAssertTrue(error is NativeError)
        }
    }

    internal func testAdvanceWithoutLoadDoesNotCrash() {
        let animation = NativeAnimation()
        // Should not crash or throw
        animation.advance(delta: 1.0)
    }

    internal func testRenderWithoutLoadThrows() {
        let animation = NativeAnimation()
        XCTAssertThrowsError(try animation.render(width: 100, height: 100)) { error in
            XCTAssertTrue(error is NativeError)
        }
    }
}
