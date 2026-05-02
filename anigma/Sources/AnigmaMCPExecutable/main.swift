import Foundation
import OSLog
import AnigmaSidecar

private let mcpLogger = Logger(subsystem: "com.anigma.mcp", category: "bridge")

// Initialize connection to daemon
let socketPath = ProcessInfo.processInfo.environment["ANIGMA_SOCKET"]
guard let bridge = try? await SidecarBridge.create(socketPath: socketPath, clientName: "anigma-mcp") else {
    mcpLogger.error("Failed to connect to daemon at socket path: \(socketPath ?? "default", privacy: .public)")
    fputs("Error: Could not connect to anigma daemon. Check that the daemon is running.\n", stderr)
    exit(1)
}

// Create input stream from stdin
let (inputStream, continuation) = AsyncStream<String>.makeStream()

// Read stdin in a detached task to avoid blocking main actor if main.swift runs on it (it's top level)
// But top level async code is fine.
Task.detached {
    // Read line-by-line (MCP uses JSON-RPC lines)
    while let line = readLine(strippingNewline: false) {
        continuation.yield(line)
    }
    continuation.finish()
}

do {
    // Bridge to daemon
    let outputStream = try await bridge.bridgeMCP(inputStream: inputStream)
    
    // Write output to stdout
    for try await chunk in outputStream {
        print(chunk, terminator: "")
        fflush(stdout)
    }
} catch {
    mcpLogger.error("MCP bridge error: \(error.localizedDescription, privacy: .public)")
    fputs("Bridge error: \(error)\n", stderr)
    exit(1)
}
