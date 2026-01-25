//
//  FileToolRuntime.swift
//  HarmoniaModule
//
//  Simple file tool runtime for harness testing.
//  Uses SimpleToolRegistry types.
//

@preconcurrency import Foundation

// MARK: - Simple File Tool Runtime

/// Simple file tool runtime for testing.
public struct FileToolRuntime {
    /// Resolves a relative path to an absolute path.
    public static func resolvePath(_ path: String, relativeTo baseDirectory: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        return (baseDirectory as NSString).appendingPathComponent(path)
    }
}
