//
//  AnigmaDaemon.swift
//  AnigmaDaemon
//
//  The persistent background service for the Anigma runtime.
//

import Foundation
import AnigmaCore
import AnigmaDaemonCore

public final class AnigmaDaemon: Sendable {
    private let runtime: PlatformRuntime
    private let server: any DaemonServerProtocol

    public init(runtime: PlatformRuntime, port: Int = 8317) {
        self.runtime = runtime
        // In a real implementation, this would use Hummingbird or similar
        self.server = StdioDaemonServer()
    }

    public func start() async throws {
        print("AnigmaDaemon: Starting system services...")

        // 1. Initialize Runtime Authorities
        // 2. Load Governance Policies
        // 3. Start HTTP/RPC Interface

        try await server.start()
    }

    public func stop() async {
        await server.stop()
        print("AnigmaDaemon: Services stopped.")
    }
}

protocol DaemonServerProtocol: Sendable {
    func start() async throws
    func stop() async
}

final class StdioDaemonServer: DaemonServerProtocol {
    func start() async throws {
        print("AnigmaDaemon: Listening on stdio/ipc...")
    }
    func stop() async {}
}
