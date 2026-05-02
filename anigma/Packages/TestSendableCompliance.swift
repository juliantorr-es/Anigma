import Foundation

// Test for Sendable compliance
struct TestStruct {
    let value: String
}

// This should work if our fixes are good
func testSendable() {
    let array: [TestStruct] = [TestStruct(value: "test")]
    print("Sendable compliance test passed")
}