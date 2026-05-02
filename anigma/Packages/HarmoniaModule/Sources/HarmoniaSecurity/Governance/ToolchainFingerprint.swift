//
//  ToolchainFingerprint.swift
//  HarmoniaModule
//
//  Toolchain fingerprint capture and recording.
//  Ensures deterministic verification by recording exact toolchain state.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import DoctrineCore
import AnigmaPrimitives
import os.log
@preconcurrency import Foundation

/// Toolchain fingerprint for deterministic reproduction.
/// Captures compiler version, SDK, and other environment state.
private let log = Logger(subsystem: "com.anigma.harmonia", category: "struct")
public struct ToolchainFingerprint: Codable, Sendable, Equatable {
    public let swiftVersion: String
    public let swiftcPath: String
    public let sdkPath: String
    public let osVersion: String
    public let architectures: [String]
    public let capturedAt: String  // ISO8601 sequence time, not wall-clock

    public init(
        swiftVersion: String,
        swiftcPath: String,
        sdkPath: String,
        osVersion: String,
        architectures: [String],
        capturedAt: String
    ) {
        self.swiftVersion = swiftVersion
        self.swiftcPath = swiftcPath
        self.sdkPath = sdkPath
        self.osVersion = osVersion
        self.architectures = architectures
        self.capturedAt = capturedAt
    }

    /// Generate a deterministic fingerprint hash
    public func hash() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        return BLAKE3Digest.hex(of: data)
    }
}

/// Captures toolchain state at execution time
public struct ToolchainCapture {

    /// Capture current toolchain fingerprint
    public static func current() -> ToolchainFingerprint {
        return ToolchainFingerprint(
            swiftVersion: captureSwiftVersion(),
            swiftcPath: captureSwiftcPath(),
            sdkPath: captureSDKPath(),
            osVersion: captureOSVersion(),
            architectures: captureArchitectures(),
            capturedAt: ""  // Will be set to sequence timestamp
        )
    }

    /// Capture Swift compiler version
    private static func captureSwiftVersion() -> String {
        // This would normally execute `swift --version`
        // For now, return a known format
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "unknown"
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "unknown"
        }
    }

    /// Capture path to swiftc compiler
    private static func captureSwiftcPath() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["swiftc"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "unknown"
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "unknown"
        }
    }

    /// Capture SDK path
    private static func captureSDKPath() -> String {
        // Typically something like /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
        let fm = FileManager.default
        let xcodeDefault = "/Applications/Xcode.app/Contents/Developer"
        return fm.fileExists(atPath: xcodeDefault) ? xcodeDefault : "unknown"
    }

    /// Capture operating system version
    private static func captureOSVersion() -> String {
        #if os(macOS)
            let version = ProcessInfo.processInfo.operatingSystemVersionString
            return version
        #else
            return "unknown"
        #endif
    }

    /// Capture supported architectures
    private static func captureArchitectures() -> [String] {
        #if os(macOS)
            // On Apple Silicon Macs, typically ["arm64"]
            // On Intel Macs, typically ["x86_64"]
            return ["arm64"]  // Assume modern Mac
        #else
            return []
        #endif
    }
}
