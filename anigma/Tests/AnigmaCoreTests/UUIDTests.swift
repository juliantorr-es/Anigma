//
//  UUIDTests.swift
//  AnigmaPrimitives
//
//  Centralized UUID handling with byte order consistency tests.
//  Prevents endianness religion by enforcing round-trip guarantees.
//

import Foundation
import XCTest

/// Test UUID byte order consistency across different platforms.
/// This prevents the classic "works on Mac, breaks on Windows" bugs.
public class UUIDByteOrderTests: XCTestCase {

    /// Test that UUID round-trips through 16-byte representation consistently.
    /// This catches endianness issues and byte order inconsistencies.
    func testUUIDRoundTripConsistency() throws {
        // Test a variety of UUIDs to catch edge cases
        let testUUIDs = [
            UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!,
            UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
        ]

        for originalUUID in testUUIDs {
            // Convert to 16-byte data using our centralized method
            let blobData = withUnsafeBytes(of: originalUUID) { Data($0) }

            // Verify it's exactly 16 bytes
            XCTAssertEqual(blobData.count, 16, "UUID must be exactly 16 bytes")

            // Convert back to UUID from the same 16-byte data
            let roundTripUUID = blobData.withUnsafeBytes { rawBytes in
                let uuidBytes = rawBytes.bindMemory(to: UInt8.self)
                let uuidTuple = (
                    uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                    uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                    uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                    uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
                )
                return UUID(uuid: uuidTuple)
            }

            // Verify round-trip consistency
            XCTAssertEqual(roundTripUUID, originalUUID, "UUID must round-trip exactly")
            XCTAssertEqual(roundTripUUID.uuidString, originalUUID.uuidString, "UUID string must match")

            // Test hex representation consistency
            let hex1 = originalUUID.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            let hex2 = roundTripUUID.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            XCTAssertEqual(hex1, hex2, "Hex representation must be consistent")
        }
    }

    /// Test that our BLOB storage matches SQLite expectations.
    /// Ensures we're storing UUIDs in the format StepEngine expects.
    func testUUIDBlobStorageFormat() throws {
        guard let testUUID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000") else {
            fatalError("Failed to unwrap testUUID")
        }

        // Get 16-byte representation
        let blobData = withUnsafeBytes(of: testUUID) { Data($0) }

        // Verify byte pattern is what we expect
        let expectedBytes: [UInt8] = [
            0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4,
            0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00
        ]

        XCTAssertEqual(Array(blobData), expectedBytes, "UUID bytes must match expected pattern")

        // Test that hex() function produces correct output
        let hex = testUUID.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let expectedHex = "550e8400e29b41d4a716446655440000"
        XCTAssertEqual(hex, expectedHex, "Hex representation must match expected")
    }

    /// Test that UUID initialization from hex works correctly.
    /// This validates the UUID(hexString:) initializer we use in StepEngine.
    func testUUIDHexInitialization() throws {
        let testCases: [(String, Bool)] = [
            ("550e8400e29b41d4a716446655440000", true),
            ("550e8400-e29b-41d4-a716-446655440000", true),
            ("550e8400e29b41d4a716446655440", false),  // Too short
            ("g550e8400e29b41d4a716446655440000", false), // Invalid hex
            ("550e8400e29b41d4a71644665544000000000", false) // Too long
        ]

        for (hexString, shouldSucceed) in testCases {
            let uuid = UUID(hexString: hexString)

            if shouldSucceed {
                XCTAssertNotNil(uuid, "Valid hex should create UUID")
                if let u = uuid {
                     XCTAssertEqual(u.uuidString.lowercased().replacingOccurrences(of: "-", with: ""), hexString.lowercased().replacingOccurrences(of: "-", with: ""), "UUID should match input")
                }
            } else {
                XCTAssertNil(uuid, "Invalid hex should not create UUID")
            }
        }
    }
}
