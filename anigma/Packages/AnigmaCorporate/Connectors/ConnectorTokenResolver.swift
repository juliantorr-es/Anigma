import Foundation
import AnigmaSystemSpine

extension ConnectorConfig {
    func resolveAccessToken() async throws -> ConnectorAccessToken {
        if let accessToken, !accessToken.isExpired {
            return accessToken
        }

        if let tokenProvider {
            return try await tokenProvider.accessToken(for: self)
        }

        if accessToken == nil, let clientSecret, !clientSecret.isEmpty {
            return ConnectorAccessToken(value: clientSecret)
        }

        throw CorporateError.invalidConfiguration("Missing access token for \(type.rawValue)")
    }
}
