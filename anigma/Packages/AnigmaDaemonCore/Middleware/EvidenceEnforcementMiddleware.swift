//
//  EvidenceEnforcementMiddleware.swift
//  AnigmaDaemonCore
//
//  Hummingbird middleware for Cathedral evidence enforcement.
//

import Hummingbird
import AnigmaCore
import CathedralModule
import Foundation

struct EvidenceEnforcementMiddleware: HBMiddleware {
    let evidenceSubstrate: EvidenceSubstrate
    
    func apply(
        to request: Request,
        context: some RequestContext,
        next: (Request, some RequestContext) async throws -> Response
    ) async throws -> Response {
        // Extract operation from path
        let operation = extractOperation(from: request.uri.path)
        
        // Enforce evidence requirements
        do {
            try await evidenceSubstrate.enforceEvidenceSubstrate(
                operation: operation,
                evidenceLevel: .moderate
            )
        } catch CathedralError.operationBlocked(let reason) {
            // Return 403 with reason
            return Response(
                status: .forbidden,
                headers: [.contentType: "text/plain"],
                body: .init(byteBuffer: ByteBuffer(string: reason))
            )
        }
        
        return try await next(request, context)
    }
    
    private func extractOperation(from path: String) -> String {
        // Extract operation type from path
        // e.g., "/api/v1/ml/embed" -> "ml.embed"
        // e.g., "/models/install" -> "models.install"
        
        // Remove query parameters
        let cleanPath = path.split(separator: "?").first ?? ""
        let components = cleanPath.split(separator: "/")
        
        // Handle /api/v1/ml/embed pattern
        if components.count >= 4 && components[0] == "api" {
            return "\(components[2]).\(components[3])"
        }
        
        // Handle /models/list pattern
        if components.count >= 2 {
            return "\(components[0]).\(components[1])"
        }
        
        return "unknown"
    }
}
