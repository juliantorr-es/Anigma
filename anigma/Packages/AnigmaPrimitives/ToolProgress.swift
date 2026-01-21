//
//  ToolProgress.swift
//  AnigmaPrimitives
//
//  Shared helper for reporting tool-level progress from TTC components.
//

import Foundation

/// Callback invoked when a tool wants to report progress.
public typealias ToolProgressCallback = @Sendable (Int, Int, String) async -> Void
