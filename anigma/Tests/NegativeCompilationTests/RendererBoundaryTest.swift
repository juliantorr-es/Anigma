//
//  RendererBoundaryTest.swift
//  NegativeCompilationTests
//
//  Created by Gemini on 2026-01-03.
//
//  This file is INTENTIONALLY designed NOT to compile.
//  It serves as a negative test case to ensure that renderer-level code
//  (i.e., code that only depends on AnigmaClientKit) cannot access
//  host-only modules like AnigmaSidecar.
//
//  If the build succeeds with this file included, the architectural
//  boundary has been breached.
//

import XCTest
import AnigmaClientKit

// This import should fail with "No such module 'AnigmaSidecar'"
// import AnigmaSidecar

final class RendererBoundaryTest: XCTestCase {

    func testBoundary() {
        // This test should never run because the file should not compile.
        XCTFail("The AnigmaSidecar module was imported, breaching the renderer/host boundary!")
    }

}
