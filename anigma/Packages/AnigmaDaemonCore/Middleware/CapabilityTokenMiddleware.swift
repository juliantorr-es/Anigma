//
//  CapabilityTokenMiddleware.swift
//  AnigmaDaemonCore
//
//  Hummingbird middleware for scoped capability token authentication.
//

import Hummingbird
import Foundation
import AnigmaCore
import AnigmaPrimitives

struct CapabilityTokenMiddleware: HBMiddleware {
    let tokenManager: CapabilityTokenManager
    let requiredScope: String
    
    func apply<Context: RequestContext>(
        to request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        // Extract Authorization header
        guard let authHeader = request.headers[.authorization] else {
            return Response(
                status: .unauthorized,
                headers: [.contentType: "text/plain"],
                body: .init(byteBuffer: ByteBuffer(string: "Missing Authorization header"))
            )
        }
        
        let components = authHeader.split(separator: " ")
        guard components.count == 2, components[0].lowercased() == "bearer" else {
            return Response(
                status: .unauthorized,
                headers: [.contentType: "text/plain"],
                body: .init(byteBuffer: ByteBuffer(string: "Invalid Authorization header format"))
            )
        }
        
        let tokenString = String(components[1])
        guard let tokenData = Data(base64Encoded: tokenString) else {
            return Response(
                status: .unauthorized,
                headers: [.contentType: "text/plain"],
                body: .init(byteBuffer: ByteBuffer(string: "Invalid token encoding"))
            )
        }
        
        // Validate token
        do {
            _ = try await tokenManager.validateToken(tokenData, requiredScope: requiredScope)
        } catch {
            return Response(
                status: .forbidden,
                headers: [.contentType: "text/plain"],
                body: .init(byteBuffer: ByteBuffer(string: "Authentication failed: \(error.localizedDescription)"))
            )
        }
        
        return try await next(request, context)
    }
}
