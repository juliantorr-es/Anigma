//
//  LauncherRuntimeModel.swift
//  AnigmaAppMac
//
//  Canonical executable model for the launcher-first app shell.
//

import Foundation
import AnigmaHostMac
import HarmoniaV2Surface

enum ExecutableRole: String, Sendable {
    case primaryBackend = "Primary Backend"
    case controlPlane = "Control Plane"
    case internalWorker = "Internal Worker"
}

enum AssistantRuntimeMode: String, Sendable {
    case daemonPrimary = "Daemon Primary"
    case daemonUnavailable = "Daemon Unavailable"

    var displayName: String { rawValue }
}

struct ExecutableTopology: Sendable {
    let anigmad: ExecutableRole
    let harmonia: ExecutableRole
    let mlWorker: ExecutableRole

    static let canonical = ExecutableTopology(
        anigmad: .primaryBackend,
        harmonia: .controlPlane,
        mlWorker: .internalWorker
    )
}

struct LauncherBootstrapState: Sendable {
    let topology: ExecutableTopology
    let runtimeMode: AssistantRuntimeMode
    let daemonStatus: DaemonStatus?
    let lastError: String?
}

enum AppClientFactory {
    @MainActor
    static func makeAssistantClient(daemonCapability: DaemonHostCapability) -> any HarmoniaAppClient {
        BootstrappedAppClient(
            daemonCapability: daemonCapability
        )
    }
}

@MainActor
enum LauncherRuntimeBootstrapper {
    static func bootstrap(
        daemonCapability: DaemonHostCapability
    ) async -> LauncherBootstrapState {
        do {
            let daemonStatus = try await daemonCapability.ensureDaemonRunning()
            return LauncherBootstrapState(
                topology: .canonical,
                runtimeMode: .daemonPrimary,
                daemonStatus: daemonStatus,
                lastError: nil
            )
        } catch {
            return LauncherBootstrapState(
                topology: .canonical,
                runtimeMode: .daemonUnavailable,
                daemonStatus: nil,
                lastError: error.localizedDescription
            )
        }
    }
}
