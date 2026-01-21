import XCTest

final class DesignConsistencyTests: XCTestCase {
    func testSurfacesAvoidRawSystemFontsAndColors() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DesignConsistencyTests.swift
            .deletingLastPathComponent() // AnigmaAppMacTests
            .deletingLastPathComponent() // Tests
        let surfacesURL = repoRoot.appendingPathComponent("Sources/AnigmaAppMac/Surfaces")

        let bannedFragments = [
            ".font(.system",
            "foregroundStyle(.red",
            "foregroundStyle(.green",
            "foregroundStyle(.blue",
            "foregroundStyle(.orange",
            "foregroundStyle(.purple",
            "foregroundColor("
        ]

        guard let enumerator = FileManager.default.enumerator(at: surfacesURL, includingPropertiesForKeys: nil) else {
            fatalError("Failed to unwrap enumerator")
        }
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            let contents = try String(contentsOf: fileURL)
            for fragment in bannedFragments {
                XCTAssertFalse(
                    contents.contains(fragment),
                    "\(fileURL.lastPathComponent) contains banned fragment: \(fragment)"
                )
            }
        }
    }
}
