import AnigmaClientKit
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
import AnigmaPrimitives

struct SourceConnectionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isWizardPresented = false
    @State private var authError: String?
    @State private var isGoogleConnecting = false
    @State private var googleAuthRequest: GoogleOAuthAuthRequest?

    var body: some View {
            VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sources Center")
                    .font(Bauhaus.Font.header)
                Spacer()
                Button(action: { isWizardPresented = true }) { // primaryButtonStyle
                    Label("Add Source", systemImage: "plus")
                }
                .primaryButtonStyle()
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel("Add New Source")

                Button(action: { startGoogleAuth() }) { 
                    Label(store.isGoogleLinked ? "Google Connected" : "Connect Google", systemImage: "globe")
                }
                .disabled(isGoogleConnecting || store.isGoogleLinked)
                .secondaryButtonStyle()
                .accessibilityLabel("Connect Google Account")

                Button(action: { dismiss() }) { // plain ButtonStyle
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, Bauhaus.Grid.x2)
                .accessibilityLabel("Close Sources Center")
                .keyboardShortcut(.escape, modifiers: [])
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
        .frame(width: 700, height: 600) // OK: Fixed sheet size
        .background(Bauhaus.Color.background)
        .sheet(isPresented: $isWizardPresented) {
            SourceConnectionWizard()
        }
        .task {
            await store.refreshGoogleOAuthTokenIfNeeded()
        }
    }

    private func startGoogleAuth() {
        let clientID = store.googleOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if clientID.isEmpty {
            store.showToast(
                title: "Configuration Required",
                subtitle: "Set the Google OAuth Client ID in Settings to continue.",
                icon: "gear"
            )
            return
        }

        let request: GoogleOAuthAuthRequest
        do {
            request = try GoogleOAuthService.makeAuthRequest(
                clientId: clientID,
                redirectURI: store.googleRedirectURI(),
                scopes: ["email", "profile"]
            )
        } catch {
            store.showToast(title: "Auth Error", subtitle: error.localizedDescription, icon: "exclamationmark.triangle")
            return
        }

        googleAuthRequest = request
        isGoogleConnecting = true
        store.logNetworkActivity(domain: "accounts.google.com", isAllowed: true, reason: "OAuth authorization")

        let callbackScheme = "com.anigma.app"
        AuthenticationService.shared.startAuthSession(authURL: request.url, callbackURLScheme: callbackScheme) { result in
            Task { @MainActor in
                isGoogleConnecting = false
                switch result {
                case .success(let callbackURL):
                    do {
                        guard let authRequest = googleAuthRequest else {
                            throw GoogleOAuthError.invalidCallback
                        }
                        let code = try GoogleOAuthService.extractCode(
                            from: callbackURL,
                            expectedState: authRequest.state
                        )
                        store.logNetworkActivity(domain: "oauth2.googleapis.com", isAllowed: true, reason: "OAuth token exchange")
                        let token = try await GoogleOAuthService.exchangeCode(
                            code,
                            clientId: clientID,
                            redirectURI: store.googleRedirectURI(),
                            codeVerifier: authRequest.codeVerifier
                        )
                        store.storeGoogleOAuthToken(token.accessToken)
                        store.showToast(title: "Google Connected", subtitle: "Account linked via system browser.", icon: "checkmark.circle.fill")
                    } catch {
                        authError = error.localizedDescription
                        store.showToast(title: "Connection Failed", subtitle: error.localizedDescription, icon: "exclamationmark.triangle")
                    }
                case .failure(let error):
                    print("Auth Failed: \(error)")
                    if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                         authError = error.localizedDescription
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
                .font(Bauhaus.Font.displayXL)
                .foregroundStyle(Bauhaus.Color.textTertiary)
            Text("No Sources Connected")
                .font(Bauhaus.Font.subHeader)
            Text("Connect local folders, cloud drives, or apps to begin ingestion.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Connect Source", action: action) // primaryButtonStyle
                .primaryButtonStyle()
                .padding(.top, Bauhaus.Grid.x2)
                .accessibilityLabel("Connect your first source")
                .accessibilityHint("Opens wizard to add a new data source")
                .keyboardShortcut("n", modifiers: .command)
        }
        .padding(Bauhaus.Grid.x6)
        .frame(maxWidth: .infinity)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.radius)
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
                    .font(Bauhaus.Font.displayS)
                    .foregroundStyle(Bauhaus.Color.accent)
                    .frame(width: Bauhaus.Grid.x4, height: Bauhaus.Grid.x4)
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

                SourceStatusBadge(status: isPaused ? .paused : .synced)
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
                    Button(action: { isPaused.toggle() }) { // tertiaryButtonStyle
                        Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(isPaused ? "Resume Sync" : "Pause Sync")

                    Menu {
                        Button(role: .destructive, action: { /* Revoke logic */ }) { // plain ButtonStyle
                            Label("Revoke Connection", systemImage: "trash")
                        }
                        .accessibilityLabel("Revoke connection to \(source.name)")
                        .accessibilityHint("Removes this source and stops syncing")
                        Button(role: .destructive, action: { /* Purge logic */ }) { // plain ButtonStyle
                            Label("Purge Derived Data", systemImage: "eraser")
                        }
                        .accessibilityLabel("Purge derived data for \(source.name)")
                        .accessibilityHint("Deletes all processed data while keeping the connection")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: Bauhaus.Grid.x3)
                    .accessibilityLabel("Connection Options")
                }
            }
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surfaceElevated.opacity(0.5))
        }
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
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
                .font(Bauhaus.Font.smallBold)
                .foregroundStyle(Bauhaus.Color.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textPrimary)
        }
    }
}

private struct SourceStatusBadge: View {
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
            case .synced: return Bauhaus.Color.trusted
            case .syncing: return Bauhaus.Color.running
            case .paused: return Bauhaus.Color.warning
            case .error: return Bauhaus.Color.error
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
        .padding(.horizontal, Bauhaus.Grid.unit)
        .padding(.vertical, Bauhaus.Grid.unit / 2)
        .background(status.color.opacity(0.1))
        .cornerRadius(12)
    }
}
