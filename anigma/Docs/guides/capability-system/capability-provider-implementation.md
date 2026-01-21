# Capability Provider Implementation Guide

This document provides guidance for implementing the C library integrations for capability providers.

## Overview

Several capability providers require C library bindings:
- **PDFiumProvider**: Requires PDFium library for Linux PDF support
- **HarfBuzzTextShapingProvider**: Requires HarfBuzz + FreeType for Linux text shaping
- **NativeTextShapingProvider**: Requires CoreText (available on macOS/iOS)

## PDFium Integration (Linux)

### Prerequisites
```bash
# Install PDFium development libraries
sudo apt-get install libpdfium-dev  # Debian/Ubuntu
# OR build from source: https://pdfium.googlesource.com/pdfium/
```

### Implementation Steps

1. **Create C Module Map** (`Sources/CPDFium/module.modulemap`):
```
module CPDFium {
    header "pdfium_wrapper.h"
    link "pdfium"
    export *
}
```

2. **Create Wrapper Header** (`Sources/CPDFium/pdfium_wrapper.h`):
```c
#include <fpdfview.h>
#include <fpdf_text.h>
#include <fpdf_edit.h>
```

3. **Update Package.swift**:
```swift
.systemLibrary(
    name: "CPDFium",
    pkgConfig: "pdfium",
    providers: [
        .apt(["libpdfium-dev"])
    ]
),
.target(
    name: "PlatformCore",
    dependencies: ["CPDFium"],
    linkerSettings: [
        .linkedLibrary("pdfium", .when(platforms: [.linux]))
    ]
)
```

4. **Implement Provider Methods**:
```swift
import CPDFium

public func renderPage(pdfData: Data, pageNumber: Int, resolution: CGFloat) async throws -> Data? {
    return try pdfData.withUnsafeBytes { buffer in
        // Initialize PDFium
        FPDF_InitLibrary()
        defer { FPDF_DestroyLibrary() }
        
        // Load document
        guard let doc = FPDF_LoadMemDocument(buffer.baseAddress, Int32(buffer.count), nil) else {
            throw CapabilityError.providerFailed(providerId, NSError(...))
        }
        defer { FPDF_CloseDocument(doc) }
        
        // Load page (0-indexed in PDFium)
        guard let page = FPDF_LoadPage(doc, Int32(pageNumber - 1)) else {
            throw CapabilityError.invalidInput("Invalid page number")
        }
        defer { FPDF_ClosePage(page) }
        
        // Get dimensions and create bitmap
        let width = Int(FPDF_GetPageWidth(page) * resolution / 72.0)
        let height = Int(FPDF_GetPageHeight(page) * resolution / 72.0)
        
        guard let bitmap = FPDFBitmap_Create(Int32(width), Int32(height), 0) else {
            throw CapabilityError.providerFailed(providerId, NSError(...))
        }
        defer { FPDFBitmap_Destroy(bitmap) }
        
        // Render page
        FPDFBitmap_FillRect(bitmap, 0, 0, Int32(width), Int32(height), 0xFFFFFFFF)
        FPDF_RenderPageBitmap(bitmap, page, 0, 0, Int32(width), Int32(height), 0, 0)
        
        // Convert to PNG data
        // ... (use libpng or similar)
    }
}
```

## HarfBuzz Integration (Linux)

### Prerequisites
```bash
# Install HarfBuzz and FreeType
sudo apt-get install libharfbuzz-dev libfreetype6-dev
```

### Implementation Steps

1. **Create C Module Maps**:

`Sources/CHarfBuzz/module.modulemap`:
```
module CHarfBuzz {
    header "harfbuzz_wrapper.h"
    link "harfbuzz"
    export *
}
```

`Sources/CFreeType/module.modulemap`:
```
module CFreeType {
    header "freetype_wrapper.h"
    link "freetype"
    export *
}
```

2. **Update Package.swift**:
```swift
.systemLibrary(
    name: "CHarfBuzz",
    pkgConfig: "harfbuzz",
    providers: [.apt(["libharfbuzz-dev"])]
),
.systemLibrary(
    name: "CFreeType",
    pkgConfig: "freetype2",
    providers: [.apt(["libfreetype6-dev"])]
),
```

3. **Implement Text Shaping**:
```swift
import CHarfBuzz
import CFreeType

public func shapeText(_ text: String, fontPath: URL, fontSize: Double) async throws -> [GlyphInfo] {
    // Initialize FreeType
    var library: FT_Library?
    guard FT_Init_FreeType(&library) == 0 else {
        throw CapabilityError.providerFailed(providerId, NSError(...))
    }
    defer { FT_Done_FreeType(library) }
    
    // Load font
    var face: FT_Face?
    guard FT_New_Face(library, fontPath.path, 0, &face) == 0 else {
        throw CapabilityError.invalidInput("Failed to load font")
    }
    defer { FT_Done_Face(face) }
    
    // Set font size
    FT_Set_Char_Size(face, 0, FT_F26Dot6(fontSize * 64), 72, 72)
    
    // Create HarfBuzz font
    let hbFont = hb_ft_font_create(face, nil)
    defer { hb_font_destroy(hbFont) }
    
    // Create buffer and add text
    let buffer = hb_buffer_create()
    defer { hb_buffer_destroy(buffer) }
    
    hb_buffer_add_utf8(buffer, text, -1, 0, -1)
    hb_buffer_set_direction(buffer, HB_DIRECTION_LTR)
    hb_buffer_set_script(buffer, HB_SCRIPT_LATIN)
    hb_buffer_set_language(buffer, hb_language_from_string("en", -1))
    
    // Shape text
    hb_shape(hbFont, buffer, nil, 0)
    
    // Get glyph info
    var glyphCount: UInt32 = 0
    let glyphInfos = hb_buffer_get_glyph_infos(buffer, &glyphCount)
    let glyphPositions = hb_buffer_get_glyph_positions(buffer, &glyphCount)
    
    // Convert to GlyphInfo array
    return (0..<Int(glyphCount)).map { i in
        let info = glyphInfos![i]
        let pos = glyphPositions![i]
        return GlyphInfo(
            glyphId: info.codepoint,
            xOffset: Double(pos.x_offset) / 64.0,
            yOffset: Double(pos.y_offset) / 64.0,
            xAdvance: Double(pos.x_advance) / 64.0,
            yAdvance: Double(pos.y_advance) / 64.0
        )
    }
}
```

## CoreText Integration (macOS/iOS)

CoreText is already available on Apple platforms. Implementation:

```swift
import CoreText

public func shapeText(_ text: String, fontPath: URL, fontSize: Double) async throws -> [GlyphInfo] {
    // Load font from URL
    guard let fontDataProvider = CGDataProvider(url: fontPath as CFURL),
          let cgFont = CGFont(fontDataProvider),
          let ctFont = CTFontCreateWithGraphicsFont(cgFont, fontSize, nil, nil) else {
        throw CapabilityError.invalidInput("Failed to load font")
    }
    
    // Create attributed string
    let attributes: [NSAttributedString.Key: Any] = [.font: ctFont]
    let attributedString = NSAttributedString(string: text, attributes: attributes)
    
    // Create line
    let line = CTLineCreateWithAttributedString(attributedString)
    
    // Get glyph runs
    guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else {
        return []
    }
    
    var glyphs: [GlyphInfo] = []
    
    for run in runs {
        let glyphCount = CTRunGetGlyphCount(run)
        var runGlyphs = [CGGlyph](repeating: 0, count: glyphCount)
        var positions = [CGPoint](repeating: .zero, count: glyphCount)
        
        CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &runGlyphs)
        CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
        
        for i in 0..<glyphCount {
            let nextPos = i + 1 < glyphCount ? positions[i + 1] : CGPoint(x: positions[i].x + 10, y: 0)
            glyphs.append(GlyphInfo(
                glyphId: UInt32(runGlyphs[i]),
                xOffset: positions[i].x,
                yOffset: positions[i].y,
                xAdvance: nextPos.x - positions[i].x,
                yAdvance: 0
            ))
        }
    }
    
    return glyphs
}
```

## Integration Tests

### PDF Integration Test
```swift
import XCTest
@testable import PlatformCore
@testable import CapabilityCore

final class PDFProviderIntegrationTests: XCTestCase {
    func testRenderPDFPage() async throws {
        // Load test PDF
        let testPDFURL = Bundle.module.url(forResource: "test", withExtension: "pdf")!
        let pdfData = try Data(contentsOf: testPDFURL)
        
        // Get provider
        let registry = CapabilityRegistry.shared
        guard let provider = await registry.resolve(
            capabilityId: CapabilityIds.pdfRender,
            as: PDFRenderingCapability.self
        ) else {
            XCTFail("No PDF provider available")
            return
        }
        
        // Render first page
        let imageData = try await provider.renderPage(
            pdfData: pdfData,
            pageNumber: 1,
            resolution: 144.0
        )
        
        XCTAssertNotNil(imageData)
        XCTAssertGreaterThan(imageData!.count, 0)
    }
}
```

### Text Shaping Integration Test
```swift
final class TextShapingIntegrationTests: XCTestCase {
    func testShapeText() async throws {
        let registry = CapabilityRegistry.shared
        guard let provider = await registry.resolve(
            capabilityId: CapabilityIds.textShaping,
            as: TextShapingCapability.self
        ) else {
            XCTFail("No text shaping provider available")
            return
        }
        
        // Use system font
        let fontURL = URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc")
        
        let glyphs = try await provider.shapeText(
            "Hello, World!",
            fontPath: fontURL,
            fontSize: 12.0
        )
        
        XCTAssertGreaterThan(glyphs.count, 0)
        XCTAssertEqual(glyphs.count, 13) // 13 characters
    }
}
```

## Build Configuration

### Linux-specific Build
```bash
# Install dependencies
sudo apt-get install libpdfium-dev libharfbuzz-dev libfreetype6-dev

# Build
swift build -c release

# Run tests
swift test
```

### macOS Build
```bash
# No additional dependencies needed
swift build -c release
swift test
```

## Troubleshooting

### PDFium Not Found
- Ensure PKG_CONFIG_PATH includes PDFium
- May need to build PDFium from source on some systems

### HarfBuzz/FreeType Version Issues
- Requires HarfBuzz >= 2.0
- Requires FreeType >= 2.8

### Symbol Conflicts
- Use module namespacing to avoid conflicts
- Ensure proper linker settings in Package.swift

## References

- [PDFium Documentation](https://pdfium.googlesource.com/pdfium/)
- [HarfBuzz Manual](https://harfbuzz.github.io/)
- [FreeType Documentation](https://www.freetype.org/freetype2/docs/)
- [CoreText Programming Guide](https://developer.apple.com/library/archive/documentation/StringsTextFonts/Conceptual/CoreText_Programming/Introduction/Introduction.html)
