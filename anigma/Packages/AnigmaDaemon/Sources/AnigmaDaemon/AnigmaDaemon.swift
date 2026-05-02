//
//  AnigmaDaemon.swift
//  AnigmaDaemon
//
//  The persistent background service for the Anigma runtime.
//

import Foundation
import AnigmaCore
import AnigmaDaemonCore
import DaemonKernel
import ModelRegistryDaemonFeature
import DaemonStatusDaemonFeature

public final class AnigmaDaemon: Sendable {
    private let kernel: DaemonKernel
    private let server: DaemonServer

    public init(configuration: DaemonConfiguration) async throws {
        let kernel = DaemonKernel()
        try await bootstrapKernel(kernel, with: [
            ModelRegistryDaemonFeature.self,
            DaemonStatusDaemonFeature.self
        ])
        self.kernel = kernel
        self.server = try await DaemonServer(configuration: configuration)
    }

    public func start() async throws {
        try await server.start()
    }

    public func stop() async {
        await server.stop()
        try? await kernel.shutdown()
    }
}
