//
//  SourceConnectionStore.swift
//  AnigmaAppMac
//
//  Manages OAuth connections and external service integrations.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import CryptoKit
import Security

@MainActor
@Observable
final class SourceConnectionStore {
    
    // MARK: - Properties
    
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
    
    /// Callback for showing toasts (injected from AppStore)
    var showToast: (String, String, String) -> Void = { _, _, _ in }
    
    /// Callback for showing errors (injected from AppStore)
    var showError: (String) -> Void = { _ in }
    
    /// Callback for logging network activity (injected from AppStore)
    var logNetworkActivity: (String, String, String, String) -> Void = { _, _, _, _ in }
    
    /// Callback for updating source connection status (injected from AppStore)
    var onSourceConnectionChanged: (SourceType, Bool) -> Void = { _, _ in }
    
    // MARK: - Initialization
    
    init() {
        // Setup is called later after callbacks are injected
    }
    
    func setup() {
        loadOAuthConfig()
        loadOAuthToken()
        loadGoogleRefreshTimestamp()
        startGoogleTokenRefreshLoop()
    }
    
    deinit {
        googleRefreshTask?.cancel()
    }
    
    // MARK: - OAuth Configuration Persistence
    
    private static let googleOAuthClientIdKey = "google_oauth_client_id"
    private static let googleOAuthTokenAccount = "google_oauth_token"
    private static let googleOAuthRedirectURI = "com.anigma.app:/callback"
    private static let googleOAuthLastRefreshKey = "google_oauth_last_refresh_at"
    
    private func saveOAuthConfig() {
        let trimmed = googleOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.googleOAuthClientIdKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: Self.googleOAuthClientIdKey)
        }
    }
    
    private func loadOAuthConfig() {
        googleOAuthClientId = UserDefaults.standard.string(forKey: Self.googleOAuthClientIdKey) ?? ""
    }
    
    private func loadOAuthToken() {
        do {
            guard let stored = try KeychainManager.shared.retrievePassword(for: Self.googleOAuthTokenAccount),
                  let data = stored.data(using: .utf8)
            else { return }
            let token = try JSONDecoder().decode(GoogleOAuthToken.self, from: data)
            googleOAuthToken = token
            onSourceConnectionChanged(.googleDrive, true)
            Task { await refreshGoogleOAuthTokenIfNeeded() }
        } catch {
            print("Failed to load Google OAuth token: \(error)")
        }
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
        do {
            let data = try JSONEncoder().encode(token)
            guard let encoded = String(data: data, encoding: .utf8) else {
                showToast(title: "Auth Error", subtitle: "Failed to encode token.", icon: "exclamationmark.triangle")
                return
            }
            try KeychainManager.shared.save(password: encoded, for: Self.googleOAuthTokenAccount)
            googleOAuthToken = token
            googleOAuthLastRefreshAt = Date()
            onSourceConnectionChanged(.googleDrive, true)
            startGoogleTokenRefreshLoop()
        } catch {
            showToast(title: "Auth Error", subtitle: error.localizedDescription, icon: "exclamationmark.triangle")
        }
    }
    
    /// Refresh Google OAuth token if needed
    func refreshGoogleOAuthTokenIfNeeded(force: Bool = false, displayToast: Bool = false) async {
        guard let token = googleOAuthToken else { return }
        let needsRefresh = force || shouldRefreshToken(token)
        guard needsRefresh else {
            if displayToast {
                showToast(title: "Google Token", subtitle: "Token is up to date.", icon: "checkmark.circle")
            }
            return
        }
        
        guard let refreshToken = token.refreshToken else {
            if displayToast {
                showToast(title: "Google Token", subtitle: "Refresh token not available.", icon: "exclamationmark.triangle")
            } else if token.expiresAt != nil {
                disconnectGoogle()
            }
            return
        }
        
        let clientId = googleOAuthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientId.isEmpty else { return }
        
        logNetworkActivity(domain: "oauth2.googleapis.com", isAllowed: true, reason: "OAuth token refresh")
        
        do {
            let refreshed = try await GoogleOAuthService.refreshAccessToken(
                refreshToken: refreshToken,
                clientId: clientId
            )
            let merged = mergeGoogleTokens(current: token, refreshed: refreshed)
            storeGoogleOAuthToken(merged)
            if displayToast {
                showToast(title: "Google Token", subtitle: "Token refreshed.", icon: "checkmark.circle.fill")
            }
        } catch {
            if displayToast {
                showToast(title: "Google Refresh Failed", subtitle: error.localizedDescription, icon: "exclamationmark.triangle")
            }
        }
    }
    
    /// Disconnect Google account
    func disconnectGoogle() {
        do {
            try KeychainManager.shared.delete(account: Self.googleOAuthTokenAccount)
        } catch {
            showToast(title: "Disconnect Failed", subtitle: error.localizedDescription, icon: "exclamationmark.triangle")
        }
        googleOAuthToken = nil
        googleOAuthLastRefreshAt = nil
        onSourceConnectionChanged(.googleDrive, false)
        googleRefreshTask?.cancel()
        googleRefreshTask = nil
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