import Foundation
import AnigmaSidecar

// Initialize connection to daemon
let socketPath = ProcessInfo.processInfo.environment["ANIGMA_SOCKET"]
guard let bridge = try? await SidecarBridge.create(socketPath: socketPath, clientName: "anigma-mcp") else {
    fputs("Error: Could not connect to anigma daemon.\n", stderr)
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
    fputs("Bridge error: \(error)\n", stderr)
    exit(1)
}
