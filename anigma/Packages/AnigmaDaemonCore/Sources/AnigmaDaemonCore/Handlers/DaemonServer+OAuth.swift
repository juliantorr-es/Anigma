//
//  DaemonServer+OAuth.swift
//  AnigmaDaemonCore
//
//  Handlers for Antigravity OAuth flow.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore

extension DaemonServer {
    /// Start Antigravity OAuth flow
    func handleAntigravityLogin() async -> AntigravityLoginResponse {
        let url = await antigravityAuthManager.generateAuthorizationURL()
        return AntigravityLoginResponse(authorizationUrl: url)
    }

    /// Handle Antigravity OAuth callback
    func handleAntigravityCallback(code: String, state: String) async -> AntigravityCallbackResponse {
        do {
            let tokens = try await antigravityAuthManager.handleCallback(code: code, state: state)
            return AntigravityCallbackResponse(
                success: true,
                email: tokens.email,
                projectId: tokens.projectId
            )
        } catch {
            return AntigravityCallbackResponse(
                success: false,
                error: error.localizedDescription
            )
        }
    }
    
    /// Get Antigravity Auth Status
    func handleAntigravityStatus() async -> AntigravityStatusResponse {
        do {
            if let token = try await antigravityAuthManager.getActiveToken() {
                return AntigravityStatusResponse(
                    isAuthenticated: true,
                    email: token.email,
                    projectId: token.projectId,
                    expiresAt: token.expiresAt
                )
            } else {
                return AntigravityStatusResponse(isAuthenticated: false)
            }
        } catch {
            return AntigravityStatusResponse(isAuthenticated: false, error: error.localizedDescription)
        }
    }
}

// MARK: - DTOs

public struct AntigravityLoginResponse: Codable, Sendable {
    public let authorizationUrl: String
}

public struct AntigravityCallbackResponse: Codable, Sendable {
    public let success: Bool
    public let email: String?
    public let projectId: String?
    public let error: String?

    public init(success: Bool, email: String? = nil, projectId: String? = nil, error: String? = nil) {
        self.success = success
        self.email = email
        self.projectId = projectId
        self.error = error
    }
}

public struct AntigravityStatusResponse: Codable, Sendable {
    public let isAuthenticated: Bool
    public let email: String?
    public let projectId: String?
    public let expiresAt: Date?
    public let error: String?
    
    public init(isAuthenticated: Bool, email: String? = nil, projectId: String? = nil, expiresAt: Date? = nil, error: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.email = email
        self.projectId = projectId
        self.expiresAt = expiresAt
        self.error = error
    }
}
