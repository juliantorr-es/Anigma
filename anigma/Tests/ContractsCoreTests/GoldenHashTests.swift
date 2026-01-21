//
//  GoldenHashTests.swift
//  ContractsCoreTests
//
//  Contract definition for GoldenHashTests in ContractsCoreTests.
//

import CryptoKit
import XCTest

@testable import ContractsCore

final class GoldenHashTests: XCTestCase {

    // MARK: - PresentationIR Golden Tests

    func testPresentationIRCanonicalHash() throws {
        // 1. Construct a complex IR with potential sorting/ordering traps
        // - Mixed dictionary keys (bindings)
        // - Nested children
        // - SnapshotID that SHOULD be ignored by contentOnlyEncode
        let ir = PresentationIR(
            version: "1.0.0",
            snapshotId: "ignore-me-i-am-ephemeral",
            root: ViewNode(
                id: "root",
                type: "VStack",
                properties: [
                    "z-index": .number(10),  // z before a
                    "alignment": .string("center"),
                    "isVisible": .bool(true)
                ],
                children: [
                    ViewNode(id: "child1", type: "Text"),
                    ViewNode(id: "child2", type: "Button")
                ],
                actions: [
                    ActionRef(rawValue: "submit", family: "core"),
                    ActionRef(rawValue: "cancel", family: "ui")
                ]
            ),
            bindings: [
                BindingId(rawValue: "user.name"): .string("Alice"),
                BindingId(rawValue: "user.age"): .number(30),
                BindingId(rawValue: "config.flags"): .object([
                    "featureB": .bool(false),
                    "featureA": .bool(true)  // Should come first in canonical JSON
                ])
            ]
        )

        let encoded = try ir.contentOnlyEncode()
        let hash = SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()

        // This is the "Golden Hash" derived from the above structure.
        // If this test fails, it means the canonicalization stability is broken.
        // Or we changed the schema intentionally (V2).
        //
        // Derived value: 4016c7f5f0b8e8abb07574b2e69acb94f1ca9ad3eaa21ec8e3f67e2d943aa96a
        // We will run this once to get the value, then fill it. for now assert non-empty.
        print("Golden Hash for PresentationIR: \(hash)")

        XCTAssertEqual(
            hash, "4016c7f5f0b8e8abb07574b2e69acb94f1ca9ad3eaa21ec8e3f67e2d943aa96a",
            "Canonical hash changed! Check serialization order logic.")
    }

    // MARK: - ActionIntent Golden Tests

    func testActionIntentCanonicalHash() throws {
        // Construct an intent with specific nonce/timestamp to ensure deterministic output
        // Timestamp: 1735689600000 (2025-01-01 00:00:00 UTC)
        let header = ActionIntent.Header(
            surfaceId: SurfaceId(rawValue: "surface-123"),
            actorId: ActorId(rawValue: "actor-456"),
            capabilityToken: "token-789",
            irSnapshotId: "snap-abc",
            timestamp: 1_735_689_600_000,
            nonce: "nonce-fixed-value"
        )
        let intent = ActionIntent(
            header: header,
            action: ActionRef(rawValue: "doSomething", family: "core"),
            parameters: [
                "param2": .number(42),
                "param1": .string("value")  // sort order check
            ]
        )

        let encoded = try intent.encode()
        let hash = SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()

        print("Golden Hash for ActionIntent: \(hash)")

        // Uncomment once we have the value from the first run
        XCTAssertEqual(
            hash, "5535e3f168849e8e50190aa6a1d40f285cc6253ab3aa6bf9ce60cbd89cc5bec2",
            "ActionIntent hash changed!")
    }
}
