//
//  ModuleInitialization.swift
//  AnigmaAppMac
//
//  Utility for initializing capability modules with PlatformRuntime.
//

import AnigmaCore
import DevelopumModule

@MainActor
final class ModuleInitialization {
    static let shared = ModuleInitialization()

    private var runtime: PlatformRuntime?
    private var isInitialized: Bool = false

    private init() {}

    func initializeModules() async throws {
        guard !isInitialized else { return }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ModuleInitializationError.appSupportNotFound
        }

        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

        let dbPath = anigmaDir.appendingPathComponent("platform_runtime.sqlite").path

        let runtime = try await PlatformRuntime(config: RuntimeConfiguration(databasePath: dbPath))
        try await runtime.initialize()

        try await runtime.registerModule(DevelopumModule.self)

        self.runtime = runtime
        self.isInitialized = true
    }

    func getRuntime() -> PlatformRuntime? {
        return runtime
    }
}

enum ModuleInitializationError: Error, LocalizedError {
    case appSupportNotFound
    case runtimeNotInitialized

    var errorDescription: String? {
        switch self {
        case .appSupportNotFound:
            return "Application Support directory not found"
        case .runtimeNotInitialized:
            return "PlatformRuntime not initialized"
        }
    }
}
