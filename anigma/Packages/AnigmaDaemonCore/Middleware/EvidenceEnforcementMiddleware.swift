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
    
    func apply<Context: RequestContext>(
        to request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        return try await next(request, context)
    }
}
