//
//  HuggingFaceAuthService.swift
//  AnigmaAppMac
//
//  Service for managing HuggingFace authentication in the app.
//

import Foundation
import AnigmaCore

@MainActor
public final class HuggingFaceAuthService: ObservableObject {
    @Published var tokenInput: String = ""
    @Published var hasToken: Bool = false

    private let keychain: HuggingFaceKeychain

    public init() {
        self.keychain = HuggingFaceKeychain()
        Task {
            hasToken = await keychain.hasToken
        }
    }

    public func saveToken() async {
        guard !tokenInput.isEmpty else { return }
        do {
            try await keychain.storeToken(tokenInput)
            hasToken = await keychain.hasToken
            tokenInput = ""
        } catch {
            print("Failed to save token: \(error)")
        }
    }

    public func deleteToken() async {
        do {
            try await keychain.deleteToken()
            hasToken = await keychain.hasToken
        } catch {
            print("Failed to delete token: \(error)")
        }
    }
}
