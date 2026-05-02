import Foundation
import AnigmaPrimitives
import AnigmaCore

@MainActor
final class KeychainManager {
    static let shared = KeychainManager()

    private let authority = KeychainSecretAuthority(service: "com.anigma.daemon.credentials")

    func save(password: String, for account: String) async throws {
        try await authority.store(password: password, for: account)
    }

    func retrievePassword(for account: String) async throws -> String? {
        return try await authority.retrievePassword(for: account)
    }

    func delete(account: String) async throws {
        try await authority.delete(for: account)
    }
}
