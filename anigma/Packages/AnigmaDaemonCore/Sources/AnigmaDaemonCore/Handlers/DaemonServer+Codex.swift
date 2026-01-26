//
//  DaemonServer+Codex.swift
//  AnigmaDaemonCore
//

import Foundation
import CodexModule
import AnigmaCore
import ContractsCore

extension DaemonServer {
    // MARK: - Codex Handlers

    func handleCodexCreateSpace(
        ctx: DaemonRequestContext,
        space: SpaceComponent
    ) async throws -> EntityId {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "codex.space.create")
        
        // This assumes we have a codexService accessible on DaemonServer
        // We will need to add it to DaemonServer in the next step
        return try await codexService.createSpace(space, principal: ctx.principalId ?? "system")
    }

    func handleCodexGetSpace(
        ctx: DaemonRequestContext,
        entityId: EntityId
    ) async throws -> SpaceComponent? {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "codex.space.read")
        return await codexService.getSpace(entityId)
    }

    func handleCodexListSpaces(
        ctx: DaemonRequestContext
    ) async throws -> [SpaceComponent] {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "codex.space.read")
        let results = await codexService.listSpaces()
        return results.map { $0.1 }
    }

    func handleCodexCreatePage(
        ctx: DaemonRequestContext,
        page: PageComponent
    ) async throws -> EntityId {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "codex.page.create")
        return try await codexService.createPage(page, principal: ctx.principalId ?? "system")
    }

    func handleCodexGetPage(
        ctx: DaemonRequestContext,
        entityId: EntityId
    ) async throws -> PageComponent? {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "codex.page.read")
        return await codexService.getPage(entityId)
    }

    func handleCodexUpdatePage(
        ctx: DaemonRequestContext,
        entityId: EntityId,
        title: String?,
        body: String?,
        excerpt: String?,
        changeMessage: String?
    ) async throws {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "codex.page.update")
        try await codexService.updatePage(
            entityId,
            title: title,
            body: body,
            excerpt: excerpt,
            changeMessage: changeMessage,
            principal: ctx.principalId ?? "system"
        )
    }

    func handleCodexSearch(
        ctx: DaemonRequestContext,
        query: ContentSearchQuery
    ) async throws -> [ContentSearchResult] {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "codex.page.read")
        return await codexService.search(query)
    }
}
