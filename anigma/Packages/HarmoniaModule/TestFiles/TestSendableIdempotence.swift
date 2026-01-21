//
//  TestSendableIdempotence.swift
//  HarmoniaModule
//
//  Test file for verifying SendableConformanceRule idempotence.
//  This file should be in Sources/ directory to pass invariants check.
//

import Foundation

// Test case 1: Struct without inheritance - should add : Sendable
struct UserWithoutSendable {
    let name: String
    let age: Int
}

// Test case 2: Struct with existing inheritance - should add Sendable to list
struct ProductWithCodable: Codable {
    let id: Int
    let title: String
}

// Test case 3: Already has Sendable - should not change
struct AlreadySendable: Sendable {
    let data: String
}

// Test case 4: Class without inheritance - should add : Sendable
class ContainerWithoutSendable {
    let value: String = ""
}

// Test case 5: Class with existing inheritance - should add Sendable to list
class RepositoryWithCodable: Codable {
    let items: [String]
}

// Note: This file is intentionally placed in Sources/HarmoniaModule/TestFiles/
// to test the invariants check that only allows changes in Sources/ directory.
