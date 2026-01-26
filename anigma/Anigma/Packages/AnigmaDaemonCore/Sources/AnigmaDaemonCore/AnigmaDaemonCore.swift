import Foundation

// Minimal AnigmaDaemonCore module for dependency resolution
public struct AnigmaDaemonCore {
    public init() {}
}

// Re-export Foundation types commonly used
public typealias DaemonCoreResult = Result
public typealias DaemonCoreError = Error
