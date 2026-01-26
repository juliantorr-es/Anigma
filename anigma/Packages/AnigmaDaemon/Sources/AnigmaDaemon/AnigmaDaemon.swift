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
    private let server: DaemonServer

    public init(configuration: DaemonConfiguration) async throws {
        self.server = try await DaemonServer(configuration: configuration)
    }

    public func start() async throws {
        try await server.start()
    }

    public func stop() async {
        await server.stop()
    }
}
