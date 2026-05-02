import Foundation

/// Sidecar configuration mirroring DaemonConfig for client-side usage.
public struct SidecarConfig {
    /// Platform-aware default Unix socket path
    public static func defaultUnixSocketPath() -> String {
        #if os(macOS)
            return NSString(string: "~/Library/Caches/anigma/anigmad.sock").expandingTildeInPath
        #elseif os(Linux)
            if let xdgRuntime = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] {
                return "\(xdgRuntime)/anigmad.sock"
            }
            return NSString(string: "~/.cache/anigma/anigmad.sock").expandingTildeInPath
        #else
            return NSString(string: "~/.anigma/anigmad.sock").expandingTildeInPath
        #endif
    }
}
