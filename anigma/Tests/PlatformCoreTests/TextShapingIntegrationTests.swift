//
//  TextShapingIntegrationTests.swift
//  PlatformCoreTests
//
//  Integration tests for text shaping providers.
//

import XCTest

@testable import CapabilityCore
@testable import PlatformCore

#if canImport(CoreText)
    final class TextShapingIntegrationTests: XCTestCase {

        override func setUp() async throws {
            // Bootstrap capabilities
            await PlatformCapabilityBootstrap.registerPlatformCapabilities()
        }

        func testNativeTextShaping() async throws {
            let registry = CapabilityRegistry.shared

            guard
                let provider = await registry.resolve(
                    capabilityId: CapabilityIds.textShaping,
                    as: TextShapingCapability.self
                )
            else {
                XCTFail("No text shaping provider available")
                return
            }

            // Use a system font that should be available
            #if os(macOS)
                let fontPath = URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc")
            #elseif os(iOS)
                let fontPath = URL(fileURLWithPath: "/System/Library/Fonts/Core/Helvetica.ttc")
            #else
                throw XCTSkip("Test only runs on macOS/iOS")
            #endif

            // Test basic text shaping
            let glyphs = try await provider.shapeText(
                "Hello, World!",
                fontPath: fontPath,
                fontSize: 12.0
            )

            XCTAssertGreaterThan(glyphs.count, 0, "Should have shaped glyphs")
            XCTAssertEqual(glyphs.count, 13, "Should have 13 glyphs for 13 characters")

            // Verify glyph properties
            for glyph in glyphs {
                XCTAssertGreaterThan(glyph.glyphId, 0, "Glyph ID should be valid")
                XCTAssertGreaterThan(glyph.xAdvance, 0, "X advance should be positive")
            }
        }

        func testEmptyString() async throws {
            let registry = CapabilityRegistry.shared

            guard
                let provider = await registry.resolve(
                    capabilityId: CapabilityIds.textShaping,
                    as: TextShapingCapability.self
                )
            else {
                XCTFail("No text shaping provider available")
                return
            }

            #if os(macOS)
                let fontPath = URL(fileURLWithPath: "/System/Library/Fonts/Helvetica.ttc")
            #elseif os(iOS)
                let fontPath = URL(fileURLWithPath: "/System/Library/Fonts/Core/Helvetica.ttc")
            #else
                throw XCTSkip("Test only runs on macOS/iOS")
            #endif

            let glyphs = try await provider.shapeText(
                "",
                fontPath: fontPath,
                fontSize: 12.0
            )

            XCTAssertEqual(glyphs.count, 0, "Empty string should produce no glyphs")
        }

        func testInvalidFontPath() async throws {
            let registry = CapabilityRegistry.shared

            guard
                let provider = await registry.resolve(
                    capabilityId: CapabilityIds.textShaping,
                    as: TextShapingCapability.self
                )
            else {
                XCTFail("No text shaping provider available")
                return
            }

            let invalidPath = URL(fileURLWithPath: "/nonexistent/font.ttf")

            do {
                _ = try await provider.shapeText(
                    "Test",
                    fontPath: invalidPath,
                    fontSize: 12.0
                )
                XCTFail("Should have thrown an error for invalid font path")
            } catch {
                // Expected error
                XCTAssertTrue(error is CapabilityError, "Should throw CapabilityError")
            }
        }
    }
#endif
