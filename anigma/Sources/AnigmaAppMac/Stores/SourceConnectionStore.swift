//
//  SourceConnectionStore.swift
//  AnigmaAppMac
//
//  Manages OAuth connections and external service integrations.
//  Migrated to use the governed SourceAuthority via AnigmaSidecar.
//

import Foundation
import Observation
import CryptoKit
import Security
import AnigmaSidecar
import AnigmaPrimitives

@MainActor
@Observable
final class SourceConnectionStore {
    
    // MARK: - Properties
    
    /// Governed list of content sources from the daemon
    private(set) var sources: [AnigmaSource] = []
    
    /// Loading state
    private(set) var isLoading: Bool = false
    
    /// Google OAuth client ID (user configurable)
    var googleOAuthClientId: String = "" {
        didSet {
            if googleOAuthClientId != oldValue {
                saveOAuthConfig()
            }
        }
    }
    
    /// Current Google OAuth token (private set)
    private(set) var googleOAuthToken: GoogleOAuthToken?
    
    /// Whether Google account is linked
    var isGoogleLinked: Bool { googleOAuthToken != nil }
    
    /// Last refresh timestamp for Google token
    var googleOAuthLastRefreshAt: Date? {
        didSet {
            if googleOAuthLastRefreshAt != oldValue {
                saveGoogleRefreshTimestamp()
            }
        }
    }
    
    /// Background task for token refresh loop
    private var googleRefreshTask: Task<Void, Never>?
    
    // MARK: - Dependencies (Injected)
    
    /// Reference to the daemon store for bridge access
    private let daemonStore: DaemonStore
    
    /// Bridge to the Anigma daemon
    private var bridge: SidecarBridge? { daemonStore.daemonBridge }
    
    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }
    
    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }
    
    /// Callback for logging network activity (injected from AppStore)
    var logNetworkActivity: (String, String, String, String) -> Void = { _, _, _, _ in }
    
    /// Callback for updating source connection status (injected from AppStore)
    var onSourceConnectionChanged: (SourceType, Bool) -> Void = { _, _ in }
    
    // MARK: - Initialization
    
    init(daemonStore: DaemonStore) {
        self.daemonStore = daemonStore
        loadOAuthConfig()
        loadGoogleRefreshTimestamp()
    }
    
    func setup() {
        Task {
            await loadSources()
            await loadOAuthToken()
            startGoogleTokenRefreshLoop()
        }
    }
    
    deinit {
        // Task cancellation should be handled explicitly or via Task.isCancelled checks in the loop
    }
    
    // MARK: - Source Management (Daemon-backed)
    
    /// Load all sources from the daemon
    func loadSources() async {
        guard let bridge = bridge else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await bridge.listSources()
            if let error = response.error {
                showError("Failed to list sources: \(error.message)")
                return
            }
            self.sources = response.sources
        } catch {
            showError("Failed to communicate with daemon: \(error.localizedDescription)")
        }
    }
    
    /// Add a new source to the daemon
    func addSource(_ source: AnigmaSource) async {
        guard let bridge = bridge else {
            showError("Cannot add source: Not connected to daemon.")
            return
        }
        do {
            let response = try await bridge.addSource(source)
            if let error = response.error {
                showError("Failed to add source: \(error.message)")
                return
            }
            if let newSource = response.source {
                self.sources.append(newSource)
                showToast("Source Added", "\(newSource.name) is now tracked.", "plus.circle")
            }
            await loadSources() // Refresh list
        } catch {
            showError("Failed to add source: \(error.localizedDescription)")
        }
    }
    
    /// Remove a source from the daemon
    func removeSource(id: String) async {
        guard let bridge = bridge else {
            showError("Cannot remove source: Not connected to daemon.")
            return
        }
        do {
            let response = try await bridge.removeSource(sourceId: id)
            if let error = response.error {
                showError("Failed to remove source: \(error.message)")
                return
            }
            self.sources.removeAll { $0.id == id }
            showToast("Source Removed", "Connection has been disconnected.", "trash")
            await loadSources() // Refresh list
        } catch {
            showError("Failed to remove source: \(error.localizedDescription)")
        }
    }
    
    /// Update a source in the daemon
    func updateSource(_ source: AnigmaSource) async {
        guard let bridge = bridge else {
            showError("Cannot update source: Not connected to daemon.")
            return
        }
        do {
            let response = try await bridge.updateSource(source)
            if let error = response.error {
                showError("Failed to update source: \(error.message)")
                return
            }
            if let index = self.sources.firstIndex(where: { $0.id == source.id }) {
                self.sources[index] = source
            }
            showToast("Source Updated", "Settings saved successfully.", "checkmark.circle")
        } catch {
            showError("Failed to update source: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Legacy OAuth Token Logic (Bridged to Daemon)
    
    private func loadOAuthToken() async {
        do {
            guard let stored = try await KeychainManager.shared.retrievePassword(for: Self.googleOAuthTokenAccount),
                  let data = stored.data(using: .utf8)
            else { return }
            let token = try JSONDecoder().decode(GoogleOAuthToken.self, from: data)
            googleOAuthToken = token
            onSourceConnectionChanged(.googleDrive, true)
            await refreshGoogleOAuthTokenIfNeeded()
        } catch {
            print("Failed to load Google OAuth token: \(error)")
        }
    }
    
    // MARK: - Persistence (Local config only)
    
    private static let googleOAuthClientIdKey = "google_oauth_client_id"
    private static let googleOAuthTokenAccount = "google_oauth_token"
    private static let googleOAuthLastRefreshKey = "google_oauth_last_refresh"
    private static let googleOAuthRedirectURI = "http://localhost:8080/auth/google/callback"
    
    private func saveOAuthConfig() {
        UserDefaults.standard.set(googleOAuthClientId, forKey: Self.googleOAuthClientIdKey)
    }
    
    private func loadOAuthConfig() {
        googleOAuthClientId = UserDefaults.standard.string(forKey: Self.googleOAuthClientIdKey) ?? ""
    }
    
    private func loadGoogleRefreshTimestamp() {
        if let timestamp = UserDefaults.standard.object(forKey: Self.googleOAuthLastRefreshKey) as? Date {
            googleOAuthLastRefreshAt = timestamp
        }
    }
    
    private func saveGoogleRefreshTimestamp() {
        if let timestamp = googleOAuthLastRefreshAt {
            UserDefaults.standard.set(timestamp, forKey: Self.googleOAuthLastRefreshKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.googleOAuthLastRefreshKey)
        }
    }
    
    private func startGoogleTokenRefreshLoop() {
        googleRefreshTask?.cancel()
        googleRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await refreshGoogleOAuthTokenIfNeeded()
                let delay = nextGoogleRefreshInterval()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    // MARK: - Public OAuth Methods
    
    /// Store Google OAuth token from authorization flow
    func storeGoogleOAuthToken(_ token: GoogleOAuthToken) {
        Task {
            do {
                let data = try JSONEncoder().encode(token)
                guard let encoded = String(data: data, encoding: .utf8) else {
                    showToast("Auth Error", "Failed to encode token.", "exclamationmark.triangle")
                    return
                }
                try await KeychainManager.shared.save(password: encoded, for: Self.googleOAuthTokenAccount)
                googleOAuthToken = token
                googleOAuthLastRefreshAt = Date()
                onSourceConnectionChanged(.googleDrive, true)
                startGoogleTokenRefreshLoop()
                
                // When Google is linked, ensure we have a corresponding source in the daemon
                await ensureGoogleSourceExists()
            } catch {
                showToast("Auth Error", error.localizedDescription, "exclamationmark.triangle")
            }
        }
    }
    
    private func ensureGoogleSourceExists() async {
        // If we don't have a Google Drive source, add one
        if !sources.contains(where: { $0.type == .googleDrive }) {
            let source = AnigmaSource(
                name: "My Google Drive",
                type: .googleDrive,
                path: "/",
                isConnected: true,
                status: .connected
            )
            await addSource(source)
        }
    }
    
    /// Refresh Google OAuth token if needed
    func refreshGoogleOAuthTokenIfNeeded(force: Bool = false, displayToast: Bool = false) async {
        guard let token = googleOAuthToken else { return }
        let needsRefresh = force || shouldRefreshToken(token)
        guard needsRefresh else {
            if displayToast {
                showToast("Google Token", "Token is up to date.", "checkmark.circle")
            }
            return
        }
        
        guard let refreshToken = token.refreshToken else {
            if displayToast {
                showToast("Google Token", "Refresh token not available.", "exclamationmark.triangle")
            } else if token.expiresAt != nil {
                disconnectGoogle()
            }
            return
        }
        
        let clientId = googleOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientId.isEmpty else { return }
        
        logNetworkActivity("oauth2.googleapis.com", "true", "OAuth token refresh", "auth")
        
        do {
            let refreshed = try await GoogleOAuthService.refreshAccessToken(
                refreshToken: refreshToken,
                clientId: clientId
            )
            let merged = mergeGoogleTokens(current: token, refreshed: refreshed)
            storeGoogleOAuthToken(merged)
            if displayToast {
                showToast("Google Token", "Token refreshed.", "checkmark.circle.fill")
            }
        } catch {
            if displayToast {
                showToast("Google Refresh Failed", error.localizedDescription, "exclamationmark.triangle")
            }
        }
    }
    
    /// Disconnect Google account
    func disconnectGoogle() {
        Task {
            do {
                try await KeychainManager.shared.delete(account: Self.googleOAuthTokenAccount)
                googleOAuthToken = nil
                googleOAuthLastRefreshAt = nil
                onSourceConnectionChanged(.googleDrive, false)
                googleRefreshTask?.cancel()
                googleRefreshTask = nil
                
                // Also remove the source from the daemon if it exists
                if let googleSource = sources.first(where: { $0.type == .googleDrive }) {
                    await removeSource(id: googleSource.id)
                }
            } catch {
                showToast("Disconnect Failed", error.localizedDescription, "exclamationmark.triangle")
            }
        }
    }
    
    /// Get Google OAuth redirect URI
    func googleRedirectURI() -> String {
        Self.googleOAuthRedirectURI
    }
    
    // MARK: - Private Helpers
    
    private func shouldRefreshToken(_ token: GoogleOAuthToken) -> Bool {
        guard let expiresAt = token.expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow <= 300
    }
    
    private func nextGoogleRefreshInterval() -> TimeInterval {
        guard let token = googleOAuthToken, let expiresAt = token.expiresAt else {
            return 15 * 60
        }
        let interval = expiresAt.timeIntervalSinceNow - 300
        return max(60, interval)
    }
    
    private func mergeGoogleTokens(current: GoogleOAuthToken, refreshed: GoogleOAuthToken) -> GoogleOAuthToken {
        GoogleOAuthToken(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken ?? current.refreshToken,
            tokenType: refreshed.tokenType,
            scope: refreshed.scope ?? current.scope,
            expiresAt: refreshed.expiresAt ?? current.expiresAt
        )
    }
}
