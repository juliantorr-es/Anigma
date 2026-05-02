//
//  AuthenticationService.swift
//  AnigmaAppMac
//
//  Manages system browser authentication flows (ASWebAuthenticationSession).
//  Acts as the bridge between Anigma and Identity Providers.
//

import AuthenticationServices
import Foundation

@MainActor
final class AuthenticationService: NSObject {
    static let shared = AuthenticationService()

    private var currentSession: ASWebAuthenticationSession?

    // Starts an OAuth flow
    func startAuthSession(
        authURL: URL,
        callbackURLScheme: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackURLScheme
        ) { callbackURL, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let callbackURL = callbackURL {
                completion(.success(callbackURL))
            } else {
                completion(.failure(AuthError.noCallbackURL))
            }
        }

        session.presentationContextProvider = self
        // Ephemeral by default to avoid cookie reuse unless user explicitly wants persistence
        session.prefersEphemeralWebBrowserSession = false

        self.currentSession = session
        session.start()
    }

    enum AuthError: Error {
        case noCallbackURL
    }
}

extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the main window
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
