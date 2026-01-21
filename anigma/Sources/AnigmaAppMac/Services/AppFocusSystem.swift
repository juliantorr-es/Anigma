//
//  AppFocusSystem.swift
//  AnigmaAppMac
//
//  Monitors active application changes to dynamically adjust RAG context (Experts).
//

import SwiftUI
import AnigmaCore
import AppKit

public actor AppFocusSystem: System, Sendable {
    public let id: String = "system.ui.app-focus"
    public nonisolated var name: String { id }

    private var activeAppIdentifier: String?
    private var notificationTask: Task<Void, Never>?

    public init() {}

    public func update(world: World) async {}

    /// Start monitoring workspace application activation
    public func startMonitoring(runtime: RuntimeServices) {
        notificationTask = Task {
            let center = NSWorkspace.shared.notificationCenter
            let sequence = center.notifications(named: NSWorkspace.didActivateApplicationNotification)

            for await notification in sequence {
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bundleId = app.bundleIdentifier else { continue }

                await handleAppSwitch(bundleId: bundleId, runtime: runtime)
            }
        }
    }

    public func stopMonitoring() {
        notificationTask?.cancel()
        notificationTask = nil
    }

    public func handleAppSwitch(bundleId: String, runtime: RuntimeServices) async {
        guard bundleId != activeAppIdentifier else { return }
        self.activeAppIdentifier = bundleId

        let expertId = determineExpert(for: bundleId)

        // Record focus change evidence
        _ = try? await runtime.evidence.record(
            operation: .custom,
            principal: Principal(id: "system", displayName: "System"),
            payload: .custom(type: "app_focus_change", data: ["bundle_id": bundleId, "suggested_expert": expertId]),
            governanceDecision: nil,
            context: ExecutionContext(principal: Principal(id: "system", displayName: "System"))
        )

        print("AppFocusSystem: Context shifted to \(bundleId). Tuning for \(expertId).")
    }

    private func determineExpert(for bundleId: String) -> String {
        switch bundleId {
        case "com.apple.dt.Xcode": return "expert.swift-programming"
        case "com.microsoft.Excel": return "expert.data-analysis"
        case "com.apple.Safari": return "expert.web-research"
        case "com.apple.Terminal", "com.googlecode.iterm2": return "expert.system-ops"
        default: return "expert.general-purpose"
        }
    }
}
