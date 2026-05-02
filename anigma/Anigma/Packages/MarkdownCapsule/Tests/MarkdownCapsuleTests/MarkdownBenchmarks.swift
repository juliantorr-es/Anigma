// MarkdownBenchmarks.swift
// Benchmarks for MarkdownCapsule

import XCTest
@testable import MarkdownCapsule

final class MarkdownBenchmarks: XCTestCase {
    
    var capsule: MarkdownCapsule!
    var largeMarkdown: String!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = MarkdownCapsule()
        
        // Generate a large markdown document (~1MB)
        var lines: [String] = []
        lines.append("# Large Benchmark Document\n")
        
        for i in 0..<10000 {
            lines.append("## Section \(i)")
            lines.append("This is paragraph \(i) with some **bold** and *italic* text.")
            lines.append("- List item 1")
            lines.append("- List item 2")
            lines.append("`code snippet \(i)`")
            lines.append("")
        }
        
        largeMarkdown = lines.joined(separator: "\n")
    }
    
    override func tearDown() async throws {
        capsule = nil
        largeMarkdown = nil
        try await super.tearDown()
    }
    
    func testParsePerformance() async {
        // Measure parsing performance
        // Note: measure() in async context requires XCTest expectation or blocking
        // For benchmarks, we often use a synchronous wrapper or multiple iterations manually
        // Since we are inside an async test, we can loop.
        
        let start = Date()
        for _ in 0..<10 {
            _ = try? await capsule.parse(largeMarkdown)
        }
        let end = Date()
        let avg = end.timeIntervalSince(start) / 10.0
        
        print("Average parse time for \(largeMarkdown.count) bytes: \(avg)s")
        
        // Assert reasonable performance (e.g. > 10MB/s)
        // 1MB file should take < 0.1s
        XCTAssertLessThan(avg, 0.5, "Parsing is too slow")
    }
    
    func testRenderPerformance() async throws {
        let document = try await capsule.parse(largeMarkdown)
        
        let start = Date()
        for _ in 0..<10 {
            _ = try? await capsule.render(document: document, to: .html)
        }
        let end = Date()
        let avg = end.timeIntervalSince(start) / 10.0
        
        print("Average render time: \(avg)s")
        XCTAssertLessThan(avg, 0.5, "Rendering is too slow")
    }
}
