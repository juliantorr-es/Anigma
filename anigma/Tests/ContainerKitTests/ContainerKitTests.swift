// swiftlint:disable explicit_type_interface
import XCTest
import ContainerKit

internal final class ContainerKitTests: XCTestCase {
    internal func testNativeContainerInitialization() {
        let container = NativeContainer()
        XCTAssertNotNil(container)
    }

    internal func testOpenInvalidPathThrows() {
        let container = NativeContainer()
        XCTAssertThrowsError(try container.open(path: "/nonexistent/file.zip")) { error in
            XCTAssertTrue(error is NativeError)
        }
    }

    internal func testReadWithoutOpenThrows() {
        let container = NativeContainer()
        XCTAssertThrowsError(try container.readEntry(name: "entry")) { error in
            XCTAssertTrue(error is NativeError)
        }
    }

    internal func testWriteWithoutOpenThrows() {
        let container = NativeContainer()
        XCTAssertThrowsError(try container.writeEntry(name: "entry", data: Data())) { error in
            XCTAssertTrue(error is NativeError)
        }
    }

    internal func testCloseWithoutOpenDoesNotCrash() {
        let container = NativeContainer()
        container.close()
    }
}