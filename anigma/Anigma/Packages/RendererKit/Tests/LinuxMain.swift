// LinuxMain.swift
// Test entry point for Linux compatibility

import XCTest

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
// macOS/iOS platforms use the standard test discovery
#else
// Linux test entry point
XCTMain([
    testCase(RendererCoreTests.allTests),
    testCase(MetalRendererTests.allTests)
])
#endif
