// swiftlint:disable explicit_type_interface
import XCTest
import DoctrineCLI

internal final class DoctrineCLITests: XCTestCase {
    internal func testDoctrineCommandsInitialization() {
        let commands = DoctrineCommands(dbPath: ":memory:")
        XCTAssertNotNil(commands)
    }

    internal func testStatusDoesNotThrow() throws {
        let commands = DoctrineCommands(dbPath: ":memory:")
        XCTAssertNoThrow(try commands.status())
    }
}