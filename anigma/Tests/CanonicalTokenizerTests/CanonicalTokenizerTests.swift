import XCTest
@testable import CanonicalTokenizer

final class CanonicalTokenizerTests: XCTestCase {
    func testTokenizationPolicyHashable() {
        let policy = TokenizationPolicy(
            tokenizerHash: "test",
            maxLength: 128,
            padding: .none,
            truncation: .none
        )
        XCTAssertEqual(policy.tokenizerHash, "test")
        XCTAssertEqual(policy.maxLength, 128)
    }
}