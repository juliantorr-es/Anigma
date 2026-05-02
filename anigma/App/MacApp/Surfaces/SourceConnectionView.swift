//
//  SourceConnectionView.swift
//  AnigmaAppMac
//
//  The "Sources Center" dashboard.
//  Displays connected sources, their status, and governance controls.
//  Allows adding new sources via SourceConnectionWizard.
//

import SwiftUI
import AuthenticationServices
import OSLog

private let sourceConnectionLogger = Logger(subsystem: "com.anigma.app", category: "sources")

struct SourceConnectionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isWizardPresented = false
    @State private var authError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sources Center")
                    .font(Bauhaus.Font.header)
                Spacer()
                Button(action: { isWizardPresented = true }) {
                    Label("Add Source", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Bauhaus.Color.accent)
                .accessibilityLabel("Add New Source")

                Button(action: { startGoogleAuth() }) {
                    Label("Connect Google", systemImage: "globe")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Connect Google Account")

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, Bauhaus.Grid.x2)
                .accessibilityLabel("Close Sources Center")
            }
            .padding(Bauhaus.Grid.x3)
            .background(Bauhaus.Color.surface)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: Bauhaus.Grid.x3) {
                    if store.sources.isEmpty {
                        EmptyStateView { isWizardPresented = true }
                    } else {
                        ForEach(store.sources) { source in
                            SourceRow(source: source)
                        }
                    }
                }
                .padding(Bauhaus.Grid.x4)
            }
        }
        .frame(width: 700, height: 600)
        .background(Bauhaus.Color.background)
        .sheet(isPresented: $isWizardPresented) {
            SourceConnectionWizard()
        }
    }

    private func startGoogleAuth() {
        // In a real app, this would be configured in Settings.
        // For the prototype, we simulate the flow if ID is missing or use a demo ID.
        let clientID = "DEMO_CLIENT_ID"

        // Check for Demo/Configuration state
        if clientID == "DEMO_CLIENT_ID" {
             store.showToast(
                title: "Configuration Required",
                subtitle: "Google OAuth Client ID not configured.",
                icon: "gear"
             )
             return
        }

        guard let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=com.anigma.app:/callback&response_type=code&scope=email%20profile") else {
            fatalError("Failed to unwrap authURL")
        }
        let callbackScheme = "com.anigma.app"

        AuthenticationService.shared.startAuthSession(authURL: authURL, callbackURLScheme: callbackScheme) { result in
            Task { @MainActor in
                switch result {
                case .success(let callbackURL):
                    sourceConnectionLogger.info("Auth Success: \(callbackURL.absoluteString, privacy: .public)")
                    // Here we would exchange code for token and store in Keychain
                    store.showToast(title: "Google Connected", subtitle: "Account linked via system browser.", icon: "checkmark.circle.fill")
                    // Simulate adding source
                    let source = AnigmaSource(name: "Google Drive", type: .googleDrive, status: .connected)
                    store.sources.append(source)
                case .failure(let error):
                    sourceConnectionLogger.error("Auth Failed: \(error.localizedDescription, privacy: .public)")
                    // For demo purposes, if it's a cancellation or error, we might still want to show a toast or handle it.
                    // If it's just "user cancelled", we assume they know.
                    if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                         self.authError = error.localizedDescription
                         store.showToast(title: "Connection Failed", subtitle: error.localizedDescription, icon: "exclamationmark.triangle")
                    }
                }
            }
        }
    }
}

private struct EmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(Bauhaus.Color.textTertiary)
            Text("No Sources Connected")
                .font(Bauhaus.Font.subHeader)
            Text("Connect local folders, cloud drives, or apps to begin ingestion.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Connect Source", action: action)
                .buttonStyle(.bordered)
                .padding(.top, Bauhaus.Grid.x2)
        }
        .padding(Bauhaus.Grid.x6)
        .frame(maxWidth: .infinity)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
    }
}

private struct SourceRow: View {
    let source: AnigmaSource
    @State private var isPaused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Row: Identity & Status
            HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
                Image(systemName: source.type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Bauhaus.Color.accent)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name)
                        .font(Bauhaus.Font.bodyBold)
                    Text(source.path)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                StatusBadge(status: isPaused ? .paused : .synced)
            }
            .padding(Bauhaus.Grid.x3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(source.name), \(String(describing: source.type)). Status: \(isPaused ? "Paused" : "Synced")")
            .accessibilityHint(source.path)

            Divider()

            // Bottom Row: Controls & Stats
            HStack {
                HStack(spacing: Bauhaus.Grid.x3) {
                    StatLabel(label: "Last Sync", value: "2m ago")
                    StatLabel(label: "Items", value: "1,420")
                    StatLabel(label: "Size", value: "450 MB")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Stats: Last sync 2 minutes ago, 1,420 items, 450 megabytes")

                Spacer()

                HStack(spacing: Bauhaus.Grid.unit) {
                    Button(action: { isPaused.toggle() }) {
                        Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(isPaused ? "Resume Sync" : "Pause Sync")

                    Menu {
                        Button(role: .destructive, action: { /* Revoke logic */ }) {
                            Label("Revoke Connection", systemImage: "trash")
                        }
                        Button(role: .destructive, action: { /* Purge logic */ }) {
                            Label("Purge Derived Data", systemImage: "eraser")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .accessibilityLabel("Connection Options")
                }
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.background.opacity(0.5))
        }
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

private struct StatLabel: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Bauhaus.Color.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textPrimary)
        }
    }
}

private struct StatusBadge: View {
    let status: SourceStatus

    enum SourceStatus {
        case synced, syncing, paused, error

        var label: String {
            switch self {
            case .synced: return "Synced"
            case .syncing: return "Syncing..."
            case .paused: return "Paused"
            case .error: return "Error"
            }
        }

        var color: Color {
            switch self {
            case .synced: return .green
            case .syncing: return .blue
            case .paused: return .orange
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .synced: return "checkmark.circle.fill"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .paused: return "pause.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .symbolEffect(.variableColor.iterative, isActive: status == .syncing)
            Text(status.label)
        }
        .font(Bauhaus.Font.caption)
        .fontWeight(.bold)
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(12)
    }
}
