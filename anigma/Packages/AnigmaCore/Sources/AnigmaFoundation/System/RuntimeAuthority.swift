import Foundation

/// Error representing unrecoverable runtime failure that should terminate the process.
/// Used instead of `fatalError` in library code to allow proper handling at process boundaries.
public enum RuntimeLifecycleError: Error, Sendable {
    /// Fatal error with a message describing the failure.
    case fatal(message: String)
    /// Unrecoverable internal inconsistency.
    case inconsistency(message: String)
    /// Unimplemented operation that was called.
    case unimplemented(message: String)
}

/// Authority governing the runtime state and process lifecycle.
/// This aligns with the "Runtime Alignment Doctrine" by centralizing ambient assumptions.
/// Placed in AnigmaFoundation to ensure availability across all service tiers.
public final class RuntimeAuthority: Sendable {
    
    /// The shared instance of the runtime authority.
    public static let shared = RuntimeAuthority()
    
    /// The working directory captured at process startup.
    public let initialWorkingDirectory: String
    
    private init() {
        // Capture CWD at initialization to provide a stable reference
        self.initialWorkingDirectory = FileManager.default.currentDirectoryPath
    }
    
    /// The canonical working directory of the process.
    /// Alignment: Use this instead of FileManager.default.currentDirectoryPath.
    public var workingDirectory: String {
        return initialWorkingDirectory
    }
    
    /// Gracefully shutdown the runtime and process.
    /// This provides a single point of process termination that can be instrumented or mocked.
    /// 
    /// - Note: In reusable library code, prefer throwing errors or returning lifecycle signals.
    /// Calling this directly from a library can unexpectedly terminate the host process.
    public func shutdown(exitCode: Int32 = 0) -> Never {
        // In a future phase, this will trigger registered cleanup hooks
        exit(exitCode)
    }
}
