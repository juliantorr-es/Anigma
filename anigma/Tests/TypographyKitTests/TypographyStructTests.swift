import XCTest
@testable import TypographyKit

final class TypographyStructTests: XCTestCase {
    func testShapeStub() {
        let text = "Hello"
        let glyphs = shape(text: text, fontName: "Arial", fontSize: 12.0)
        
        XCTAssertEqual(glyphs.count, 5)
        XCTAssertEqual(glyphs[0].advance, 12.0 * 0.6)
        XCTAssertEqual(glyphs[0].glyphID, 1)
    }
    
    func testStructs() {
        let metrics = FontMetrics(ascent: 10, descent: 2, leading: 1, xHeight: 5, capHeight: 8)
        XCTAssertEqual(metrics.ascent, 10)
        
        let glyph = GlyphInfo(glyphID: 100, advance: 10)
        XCTAssertEqual(glyph.offsetX, 0)
    }

    func testGoldenShape() throws {
        let text = "Hello"
        let glyphs = shape(text: text, fontName: "Arial", fontSize: 12.0)
        
        var output = ""
        for g in glyphs {
            output += String(format: "Glyph(ID: %d, Advance: %.1f, Offset: (%.1f, %.1f))\n",
                             g.glyphID, g.advance, g.offsetX, g.offsetY)
        }
        
        // Read golden file
        let goldenURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Golden/shape_output.golden")
        
        let goldenData = try Data(contentsOf: goldenURL)
        var goldenString = String(data: goldenData, encoding: .utf8)!
        
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        goldenString = goldenString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        XCTAssertEqual(output, goldenString)
    }
}
