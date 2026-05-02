//
//  AuthTypes.swift
//  AnigmaPrimitives
//
//  OAuth 2.0 request/response types.
//

import Foundation

public struct OAuthTokenRequest: Codable, Sendable {
    public let grantType: String
    public let username: String?
    public let password: String?
    public let clientId: String
    public let scope: String?
    public let refreshToken: String?
    
    public init(
        grantType: String,
        username: String? = nil,
        password: String? = nil,
        clientId: String,
        scope: String? = nil,
        refreshToken: String? = nil
    ) {
        self.grantType = grantType
        self.username = username
        self.password = password
        self.clientId = clientId
        self.scope = scope
        self.refreshToken = refreshToken
    }
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case username
        case password
        case clientId = "client_id"
        case scope
        case refreshToken = "refresh_token"
    }
}
