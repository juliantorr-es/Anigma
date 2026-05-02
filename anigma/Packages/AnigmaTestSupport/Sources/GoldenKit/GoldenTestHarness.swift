import Foundation
import XCTest

public final class GoldenTestHarness: @unchecked Sendable {
    public static let shared = GoldenTestHarness()
    
    private init() {}

    public func compare(
        _ actual: Data,
        against goldenPath: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let goldenData: Data
        do {
            goldenData = try FixtureManager.shared.load(goldenPath)
        } catch {
            XCTFail("Could not load golden file at \(goldenPath): \(error)", file: file, line: line)
            return
        }

        if actual != goldenData {
            let diffDir = try exportDiff(actual: actual, expected: goldenData, name: goldenPath)
            XCTFail("Golden comparison failed for \(goldenPath). Artifacts exported to \(diffDir)", file: file, line: line)
        }
    }
    
    public func compareString(
        _ actual: String,
        against goldenPath: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let actualData = Data(actual.utf8)
        try compare(actualData, against: goldenPath, file: file, line: line)
    }

    private func exportDiff(actual: Data, expected: Data, name: String) throws -> String {
        let projectRoot = FixtureManager.shared.findProjectRoot()
        let diffDir = "\(projectRoot)/test-results/diffs"
        try FileManager.default.createDirectory(atPath: diffDir, withIntermediateDirectories: true)
        
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        let actualPath = "\(diffDir)/\(safeName).actual"
        let expectedPath = "\(diffDir)/\(safeName).expected"
        
        try actual.write(to: URL(fileURLWithPath: actualPath))
        try expected.write(to: URL(fileURLWithPath: expectedPath))
        
        // Optional: generate a text diff if they are strings
        if let _ = String(data: actual, encoding: .utf8),
           let _ = String(data: expected, encoding: .utf8) {
            let diffPath = "\(diffDir)/\(safeName).diff"
            // Simple line-by-line diff placeholder or just both files
            let diffContent = "Actual vs Expected diff for \(name):\n(Use a diff tool to compare \(actualPath) and \(expectedPath))"
            try diffContent.write(to: URL(fileURLWithPath: diffPath), atomically: true, encoding: .utf8)
        }
        
        return diffDir
    }
}
