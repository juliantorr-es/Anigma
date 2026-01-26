import XCTest
@testable import ColorKit

final class ColorStructTests: XCTestCase {
    func testSRGBToLinear() {
        let srgb = Color(0.5, 0.5, 0.5, space: .sRGB)
        let linear = srgb.converted(to: .linearRGB)
        
        // Approx 0.21404
        XCTAssertEqual(linear.c1, 0.21404114, accuracy: 0.0001)
        XCTAssertEqual(linear.c2, 0.21404114, accuracy: 0.0001)
        XCTAssertEqual(linear.c3, 0.21404114, accuracy: 0.0001)
    }
    
    func testLinearToSRGB() {
        let linear = Color(0.21404, 0.21404, 0.21404, space: .linearRGB)
        let srgb = linear.converted(to: .sRGB)
        
        XCTAssertEqual(srgb.c1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(srgb.c2, 0.5, accuracy: 0.0001)
        XCTAssertEqual(srgb.c3, 0.5, accuracy: 0.0001)
    }

    func testRGBToHSL() {
        let red = Color.red
        let hsl = red.converted(to: .hsl)
        
        XCTAssertEqual(hsl.c1, 0.0, accuracy: 0.01) // H
        XCTAssertEqual(hsl.c2, 1.0, accuracy: 0.01) // S
        XCTAssertEqual(hsl.c3, 0.5, accuracy: 0.01) // L
        
        let cyan = Color.cyan
        let hslCyan = cyan.converted(to: .hsl)
        XCTAssertEqual(hslCyan.c1, 0.5, accuracy: 0.01) // H (180 deg / 360)
        XCTAssertEqual(hslCyan.c2, 1.0, accuracy: 0.01) // S
        XCTAssertEqual(hslCyan.c3, 0.5, accuracy: 0.01) // L
    }
    
    func testHSLToRGB() {
        let hsl = Color(0.0, 1.0, 0.5, space: .hsl)
        let rgb = hsl.converted(to: .sRGB)
        
        XCTAssertEqual(rgb.c1, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgb.c2, 0.0, accuracy: 0.01)
        XCTAssertEqual(rgb.c3, 0.0, accuracy: 0.01)
    }
    
    func testNamedColors() {
        XCTAssertEqual(Color.blue.c3, 1.0)
        XCTAssertEqual(Color.blue.space, .sRGB)
    }

    func testGolden() throws {
        let colors = [
            Color(0.0, 0.0, 0.0, space: .sRGB),
            Color(1.0, 1.0, 1.0, space: .sRGB),
            Color(0.5, 0.5, 0.5, space: .sRGB),
            Color(1.0, 0.0, 0.0, space: .sRGB),
            Color(0.0, 1.0, 0.0, space: .sRGB),
            Color(0.0, 0.0, 1.0, space: .sRGB)
        ]
        
        var output = "// color_conversion.golden\n// sRGB -> Linear -> HSL\n"
        
        for color in colors {
            let linear = color.converted(to: .linearRGB)
            let hsl = color.converted(to: .hsl)
            
            output += String(format: "sRGB(%.1f, %.1f, %.1f) -> Linear(%.6f, %.6f, %.6f) -> HSL(%.6f, %.6f, %.6f)\n",
                             color.c1, color.c2, color.c3,
                             linear.c1, linear.c2, linear.c3,
                             hsl.c1, hsl.c2, hsl.c3)
        }
        
        // Read golden file
        // Relative to source file: ../Golden/color_conversion.golden
        let goldenURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Golden/color_conversion.golden")
        
        let goldenData = try Data(contentsOf: goldenURL)
        let goldenString = String(data: goldenData, encoding: .utf8)!
        
        XCTAssertEqual(output, goldenString)
    }
}
