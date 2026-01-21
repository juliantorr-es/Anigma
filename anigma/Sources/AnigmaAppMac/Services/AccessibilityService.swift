//
//  AccessibilityService.swift
//  AnigmaAppMac
//
//  Tier 0 service for managing system-wide accessibility features.
//  Bridges the UI to the underlying AccessibilityAuthority.
//

import SwiftUI
import AnigmaCore
import ApplicationServices

@MainActor
public class AccessibilityService: ObservableObject {
    @Published public var isTrusted: Bool = false
    @Published public var capturedText: String = ""

    private let runtime: RuntimeServices
    private var timer: Timer?

    public init(runtime: RuntimeServices) {
        self.runtime = runtime
        startMonitoring()
    }

    private func startMonitoring() {
        checkStatus()
        // Poll status every 2 seconds to detect permission changes in System Settings
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }

    public func checkStatus() {
        let options = [kAXTrustedCheckOptionPrompt: false] as CFDictionary
        let status = AXIsProcessTrustedWithOptions(options)
        if status != self.isTrusted {
            self.isTrusted = status
        }
    }

    public func openPermissions() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            fatalError("Failed to unwrap url")
        }
        NSWorkspace.shared.open(url)
    }

    /// Capture text from the active application and trigger the Governance HUD
    public func captureActiveText(hudViewModel: GovernanceHUDViewModel? = nil) async {
        guard isTrusted else { return }

        do {
            if let text = try await runtime.accessibility.getSelectedText(context: .system) {
                self.capturedText = text

                // If HUD is provided, classify the captured text and update UI
                if let hud = hudViewModel {
                    // This would ideally go through a proper system call
                    let router = PromptRouter()
                    let classification = await router.classify(text)
                    hud.update(with: classification)
                }
            }
        } catch {
            print("AccessibilityService: Capture failed - \(error)")
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - View Modifiers

struct AccessibilityRequiredOverlay: ViewModifier {
    @ObservedObject var service: AccessibilityService

    func body(content: Content) -> some View {
        ZStack {
            content

            if !service.isTrusted {
                VStack {
                    Text("Accessibility Access Required")
                        .font(.headline)
                    Text("Anigma needs accessibility permissions to provide inline assistance.")
                        .font(.caption)
                    Button("Open System Settings") {
                        service.openPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 8)
            }
        }
    }
}
