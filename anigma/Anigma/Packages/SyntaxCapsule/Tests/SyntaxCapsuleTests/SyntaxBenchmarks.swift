// SyntaxBenchmarks.swift
// Benchmarks for SyntaxCapsule

import XCTest
@testable import SyntaxCapsule

final class SyntaxBenchmarks: XCTestCase {
    
    var capsule: SyntaxCapsule!
    var largeSwiftCode: String!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = SyntaxCapsule()
        
        // Generate a large Swift file
        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("import UIKit")
        
        for i in 0..<5000 {
            lines.append("""
            class Class\(i) {
                let id = \(i)
                func method\(i)() -> String {
                    return "value \\(id)"
                }
            }
            """)
        }
        
        largeSwiftCode = lines.joined(separator: "\n")
    }
    
    override func tearDown() async throws {
        capsule = nil
        largeSwiftCode = nil
        try await super.tearDown()
    }
    
    func testParsePerformance() async {
        let start = Date()
        for _ in 0..<5 {
            _ = try? await capsule.parse(largeSwiftCode, language: .swift)
        }
        let end = Date()
        let avg = end.timeIntervalSince(start) / 5.0
        
        print("Average parse time for \(largeSwiftCode.count) bytes: \(avg)s")
        XCTAssertLessThan(avg, 1.0, "Parsing is too slow")
    }
    
    func testHighlightPerformance() async {
        let start = Date()
        for _ in 0..<5 {
            _ = try? await capsule.highlightToHTML(largeSwiftCode, language: .swift)
        }
        let end = Date()
        let avg = end.timeIntervalSince(start) / 5.0
        
        print("Average highlight time: \(avg)s")
        XCTAssertLessThan(avg, 1.5, "Highlighting is too slow")
    }
}
