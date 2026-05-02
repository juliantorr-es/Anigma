//
//  DaemonServer+Sources.swift
//  AnigmaDaemonCore
//

import Foundation
import AnigmaCore
import ContractsCore
import AnigmaPrimitives

extension DaemonServer {
    private func resolvePrincipal(ctx: DaemonRequestContext) async throws -> Principal {
        let clientId = ctx.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedId = clientId.isEmpty ? "anonymous" : clientId
        return Principal(id: resolvedId, displayName: resolvedId)
    }
    
    func handleListSources(ctx: DaemonRequestContext) async throws -> AnigmaListSourcesResponse {
        let principal = try await resolvePrincipal(ctx: ctx)
        let sources = try await runtime.sources.listSources(principal: principal)
        return AnigmaListSourcesResponse(sources: sources)
    }
    
    func handleAddSource(ctx: DaemonRequestContext, request: AnigmaAddSourceRequest) async throws -> AnigmaAddSourceResponse {
        let principal = try await resolvePrincipal(ctx: ctx)
        let context = ExecutionContext(
            principal: principal,
            projectId: nil, // Sources are currently global
            sessionId: "add-source-\(UUID().uuidString.prefix(8))"
        )
        
        let (id, _) = try await runtime.sources.addSource(request.source, context: context)
        
        // Fetch the created source to return it (with server-side defaults applied if any)
        let sources = try await runtime.sources.listSources(principal: principal)
        let source = sources.first { $0.id == id }
        
        return AnigmaAddSourceResponse(source: source)
    }
    
    func handleUpdateSource(ctx: DaemonRequestContext, request: AnigmaUpdateSourceRequest) async throws -> AnigmaUpdateSourceResponse {
        let principal = try await resolvePrincipal(ctx: ctx)
        let context = ExecutionContext(
            principal: principal,
            projectId: nil,
            sessionId: "update-source-\(request.source.id)"
        )
        
        _ = try await runtime.sources.updateSource(request.source, context: context)
        
        return AnigmaUpdateSourceResponse(source: request.source)
    }
    
    func handleRemoveSource(ctx: DaemonRequestContext, request: AnigmaRemoveSourceRequest) async throws -> AnigmaRemoveSourceResponse {
        let principal = try await resolvePrincipal(ctx: ctx)
        let context = ExecutionContext(
            principal: principal,
            projectId: nil,
            sessionId: "remove-source-\(request.sourceId)"
        )
        
        _ = try await runtime.sources.removeSource(id: request.sourceId, context: context)
        
        return AnigmaRemoveSourceResponse(success: true)
    }
}
