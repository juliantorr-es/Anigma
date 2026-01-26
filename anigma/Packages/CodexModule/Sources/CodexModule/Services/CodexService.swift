//
//  CodexService.swift
//  CodexModule
//
//  Main service for knowledge base operations, integrating with ECS and governance.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import GovernanceCore

/// Main service for Codex knowledge base operations.
public actor CodexService {
    private let world: World
    private let governance: GovernanceController
    private var templates: [TemplateId: TemplateComponent] = [:]

    public init(world: World, governance: GovernanceController) {
        self.world = world
        self.governance = governance
    }

    // MARK: - Space Operations

    /// Creates a new space.
    public func createSpace(
        _ space: SpaceComponent,
        principal: String
    ) async throws -> EntityId {
        let entityId = await world.createEntity()

        let proposal = WriteProposal(
            principal: principal,
            module: "Codex",
            operation: "create",
            entityId: entityId,
            componentType: "SpaceComponent",
            context: ["space_type": space.spaceType.rawValue]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw CodexError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        await world.addComponent(entityId, space)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "CodexService",
            description: "Created space: \(space.name) [\(space.key)]",
            metadata: [
                "original_event_type": "space_created",
                "entity_id": entityId.raw.uuidString,
                "component_type": "SpaceComponent",
                "space_name": space.name,
                "space_key": space.key
            ]
        )

        return entityId
    }

    /// Gets a space by entity ID.
    public func getSpace(_ entityId: EntityId) async -> SpaceComponent? {
        await world.getComponent(entityId, SpaceComponent.self)
    }

    /// Finds a space by key.
    public func findSpace(byKey key: String) async -> (EntityId, SpaceComponent)? {
        let entities = await world.entitiesWith(SpaceComponent.self)
        for entityId in entities {
            if let space = await world.getComponent(entityId, SpaceComponent.self),
               space.key == key.uppercased() {
                return (entityId, space)
            }
        }
        return nil
    }

    /// Lists all spaces visible to a principal.
    public func listSpaces(
        visibility: [ContentVisibility]? = nil
    ) async -> [(EntityId, SpaceComponent)] {
        let entities = await world.entitiesWith(SpaceComponent.self)
        var results: [(EntityId, SpaceComponent)] = []

        for entityId in entities {
            if let space = await world.getComponent(entityId, SpaceComponent.self) {
                if let visibility = visibility {
                    if visibility.contains(space.visibility) {
                        results.append((entityId, space))
                    }
                } else {
                    results.append((entityId, space))
                }
            }
        }

        return results.sorted { $0.1.name < $1.1.name }
    }

    // MARK: - Page Operations

    /// Creates a new page.
    public func createPage(
        _ page: PageComponent,
        principal: String
    ) async throws -> EntityId {
        let entityId = await world.createEntity()

        let proposal = WriteProposal(
            principal: principal,
            module: "Codex",
            operation: "create",
            entityId: entityId,
            componentType: "PageComponent",
            context: [
                "space_id": page.spaceId.raw.uuidString,
                "page_type": page.pageType.rawValue
            ]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw CodexError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        await world.addComponent(entityId, page)

        // Process links
        try await processLinks(for: entityId, principal: principal)

        // Create initial version
        let version = PageVersionComponent.from(
            page: page,
            previousVersion: nil,
            changeMessage: "Initial version",
            changedFields: ["title", "body"]
        )
        let versionEntityId = await world.createEntity()
        await world.addComponent(versionEntityId, version)

        // Update space page count
        if let spaceResult = await findSpaceEntity(page.spaceId) {
            var space = spaceResult.1
            space.pageCount += 1
            await world.addComponent(spaceResult.0, space)
        }

        // If has parent, update parent
        if let parentId = page.parentPageId {
            try await addChildToParent(pageId: page.pageId, parentId: parentId)
        }

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "CodexService",
            description: "Created page: \(page.title)",
            metadata: [
                "original_event_type": "page_created",
                "entity_id": entityId.raw.uuidString,
                "page_title": page.title,
                "space_id": page.spaceId.raw.uuidString
            ]
        )

        return entityId
    }

    /// Gets a page by entity ID.
    public func getPage(_ entityId: EntityId) async -> PageComponent? {
        await world.getComponent(entityId, PageComponent.self)
    }

    /// Updates a page.
    public func updatePage(
        _ entityId: EntityId,
        title: String? = nil,
        body: String? = nil,
        excerpt: String? = nil,
        changeMessage: String? = nil,
        principal: String
    ) async throws {
        guard var page = await world.getComponent(entityId, PageComponent.self) else {
            throw CodexError.pageNotFound(PageId())
        }

        guard page.isEditable else {
            if page.isLocked {
                throw CodexError.contentLocked(by: page.lockedBy ?? "unknown")
            }
            throw CodexError.invalidStatus("Page is not editable in status: \(page.status.rawValue)")
        }

        // Get previous version for diff
        let previousVersion = await getLatestVersion(pageId: page.pageId)

        // Track changed fields
        var changedFields: [String] = []
        if let newTitle = title, newTitle != page.title { changedFields.append("title") }
        if let newBody = body, newBody != page.body { changedFields.append("body") }
        if let newExcerpt = excerpt, newExcerpt != page.excerpt { changedFields.append("excerpt") }

        // Update page
        page.updateContent(title: title, body: body, excerpt: excerpt, editor: principal)
        await world.addComponent(entityId, page)

        // Process links if body updated
        if body != nil {
            try await processLinks(for: entityId, principal: principal)
        }

        // Create new version
        let version = PageVersionComponent.from(
            page: page,
            previousVersion: previousVersion,
            changeMessage: changeMessage,
            changedFields: changedFields
        )
        let versionEntityId = await world.createEntity()
        await world.addComponent(versionEntityId, version)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "CodexService",
            description: "Updated page: \(page.title) (v\(page.versionNumber))",
            metadata: [
                "original_event_type": "page_updated",
                "entity_id": entityId.raw.uuidString,
                "page_title": page.title,
                "page_version": "\(page.versionNumber)"
            ]
        )
    }

    /// Publishes a page.
    public func publishPage(
        _ entityId: EntityId,
        principal: String
    ) async throws {
        guard var page = await world.getComponent(entityId, PageComponent.self) else {
            throw CodexError.pageNotFound(PageId())
        }

        let proposal = WriteProposal(
            principal: principal,
            module: "Codex",
            operation: "publish",
            entityId: entityId,
            context: ["page_id": page.pageId.raw.uuidString]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw CodexError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        page.publish(by: principal)
        await world.addComponent(entityId, page)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "CodexService",
            description: "Published page: \(page.title)",
            metadata: [
                "original_event_type": "page_published",
                "entity_id": entityId.raw.uuidString,
                "page_title": page.title
            ]
        )
    }

    /// Archives a page.
    public func archivePage(
        _ entityId: EntityId,
        principal: String
    ) async throws {
        guard var page = await world.getComponent(entityId, PageComponent.self) else {
            throw CodexError.pageNotFound(PageId())
        }

        page.archive()
        await world.addComponent(entityId, page)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "CodexService",
            description: "Archived page: \(page.title)",
            metadata: [
                "original_event_type": "page_archived",
                "entity_id": entityId.raw.uuidString,
                "page_title": page.title
            ]
        )
    }

    /// Moves a page to a different space or parent.
    public func movePage(
        _ entityId: EntityId,
        newSpaceId: SpaceId? = nil,
        newParentPageId: PageId? = nil,
        principal: String
    ) async throws {
        guard var page = await world.getComponent(entityId, PageComponent.self) else {
            throw CodexError.pageNotFound(PageId())
        }

        let oldSpaceId = page.spaceId
        let oldParentId = page.parentPageId

        if let newSpaceId = newSpaceId, newSpaceId != oldSpaceId {
            // Check for circular reference if moving under a parent in new space
            // (Simplified check here)
            
            page.spaceId = newSpaceId
            
            // Update space counts
            if let oldSpace = await findSpaceEntity(oldSpaceId) {
                var space = oldSpace.1
                space.pageCount = max(0, space.pageCount - 1)
                await world.addComponent(oldSpace.0, space)
            }
            if let newSpace = await findSpaceEntity(newSpaceId) {
                var space = newSpace.1
                space.pageCount += 1
                await world.addComponent(newSpace.0, space)
            }
        }

        if newParentPageId != oldParentId {
            // Check for circular hierarchy
            if let newParentId = newParentPageId {
                if try await isDescendant(parentId: page.pageId, potentialChildId: newParentId) {
                    throw CodexError.circularHierarchy(newParentId)
                }
            }

            // Remove from old parent
            if let oldParentId = oldParentId {
                try await removeChildFromParent(pageId: page.pageId, parentId: oldParentId)
            }

            // Add to new parent
            page.parentPageId = newParentPageId
            if let newParentId = newParentPageId {
                try await addChildToParent(pageId: page.pageId, parentId: newParentId)
            }
        }

        await world.addComponent(entityId, page)
        
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "CodexService",
            description: "Moved page: \(page.title)",
            metadata: [
                "original_event_type": "page_moved",
                "entity_id": entityId.raw.uuidString,
                "old_space_id": oldSpaceId.raw.uuidString,
                "new_space_id": page.spaceId.raw.uuidString
            ]
        )
    }

    /// Gets pages in a space.
    public func getPages(
        inSpace spaceId: SpaceId,
        status: [PageStatus]? = nil,
        pageType: [PageType]? = nil,
        limit: Int = 50
    ) async -> [(EntityId, PageComponent)] {
        let entities = await world.entitiesWith(PageComponent.self)
        var results: [(EntityId, PageComponent)] = []

        for entityId in entities {
            guard let page = await world.getComponent(entityId, PageComponent.self),
                  page.spaceId == spaceId else { continue }

            if let status = status, !status.contains(page.status) { continue }
            if let pageType = pageType, !pageType.contains(page.pageType) { continue }

            results.append((entityId, page))
            if results.count >= limit { break }
        }

        return results.sorted { $0.1.title < $1.1.title }
    }

    /// Gets child pages of a parent page.
    public func getChildPages(_ parentPageId: PageId) async -> [(EntityId, PageComponent)] {
        let entities = await world.entitiesWith(PageComponent.self)
        var results: [(EntityId, PageComponent)] = []

        for entityId in entities {
            if let page = await world.getComponent(entityId, PageComponent.self),
               page.parentPageId == parentPageId {
                results.append((entityId, page))
            }
        }

        return results.sorted { $0.1.order < $1.1.order }
    }

    // MARK: - Version Operations

    /// Gets version history for a page.
    public func getVersionHistory(
        pageId: PageId,
        limit: Int = 20
    ) async -> [PageVersionComponent] {
        let entities = await world.entitiesWith(PageVersionComponent.self)
        var versions: [PageVersionComponent] = []

        for entityId in entities {
            if let version = await world.getComponent(entityId, PageVersionComponent.self),
               version.pageId == pageId {
                versions.append(version)
            }
        }

        return versions
            .sorted { $0.versionNumber > $1.versionNumber }
            .prefix(limit)
            .map { $0 }
    }

    /// Gets the latest version of a page.
    public func getLatestVersion(pageId: PageId) async -> PageVersionComponent? {
        let versions = await getVersionHistory(pageId: pageId, limit: 1)
        return versions.first
    }

    // MARK: - Comment Operations

    /// Adds a comment to a page.
    public func addComment(
        _ comment: PageCommentComponent,
        principal: String
    ) async throws -> EntityId {
        let entityId = await world.createEntity()

        await world.addComponent(entityId, comment)

        // Update page comment count
        let pageEntities = await world.entitiesWith(PageComponent.self)
        for pageEntityId in pageEntities {
            if var page = await world.getComponent(pageEntityId, PageComponent.self),
               page.pageId == comment.pageId {
                page.commentCount += 1
                await world.addComponent(pageEntityId, page)
                break
            }
        }

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "CodexService",
            description: "Added comment to page",
            metadata: [
                "original_event_type": "comment_added",
                "entity_id": entityId.raw.uuidString,
                "page_id": comment.pageId.raw.uuidString
            ]
        )

        return entityId
    }

    /// Gets comments on a page.
    public func getComments(
        pageId: PageId,
        includeResolved: Bool = true
    ) async -> [PageCommentComponent] {
        let entities = await world.entitiesWith(PageCommentComponent.self)
        var comments: [PageCommentComponent] = []

        for entityId in entities {
            if let comment = await world.getComponent(entityId, PageCommentComponent.self),
               comment.pageId == pageId,
               !comment.isDeleted {
                if includeResolved || !comment.isResolved {
                    comments.append(comment)
                }
            }
        }

        return comments.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Template Operations

    /// Registers a template.
    public func registerTemplate(_ template: TemplateComponent) {
        templates[template.templateId] = template
    }

    /// Gets a template by ID.
    public func getTemplate(_ templateId: TemplateId) -> TemplateComponent? {
        templates[templateId]
    }

    /// Lists templates for a space.
    public func listTemplates(
        forSpace spaceId: SpaceId? = nil,
        category: TemplateCategory? = nil
    ) -> [TemplateComponent] {
        var results = Array(templates.values)

        if let spaceId = spaceId {
            results = results.filter { $0.isGlobal || $0.spaceIds.contains(spaceId) }
        }

        if let category = category {
            results = results.filter { $0.category == category }
        }

        return results.sorted { $0.name < $1.name }
    }

    /// Creates a page from a template.
    public func createPageFromTemplate(
        templateId: TemplateId,
        spaceId: SpaceId,
        values: [String: String],
        principal: String
    ) async throws -> EntityId {
        guard var template = templates[templateId] else {
            throw CodexError.templateNotFound(templateId)
        }

        let missing = template.validate(values: values)
        guard missing.isEmpty else {
            throw CodexError.validationFailed("Missing required fields: \(missing.joined(separator: ", "))")
        }

        let (title, body) = template.apply(values: values)

        let page = PageComponent(
            spaceId: spaceId,
            pageType: template.defaultPageType,
            title: title,
            body: body,
            contentFormat: template.contentFormat,
            author: principal
        )

        let entityId = try await createPage(page, principal: principal)

        template.useCount += 1
        templates[templateId] = template

        return entityId
    }

    // MARK: - Search Operations

    /// Searches content.
    public func search(_ query: ContentSearchQuery) async -> [ContentSearchResult] {
        let entities = await world.entitiesWith(PageComponent.self)
        var results: [ContentSearchResult] = []

        for entityId in entities {
            guard let page = await world.getComponent(entityId, PageComponent.self) else { continue }

            // Apply filters
            if let spaceIds = query.spaceIds, !spaceIds.contains(page.spaceId) { continue }
            if let pageTypes = query.pageTypes, !pageTypes.contains(page.pageType) { continue }
            if let status = query.status, !status.contains(page.status) { continue }
            if let visibility = query.visibility, !visibility.contains(page.visibility) { continue }
            if let author = query.author, page.author != author { continue }
            if let after = query.modifiedAfter, page.updatedAt < after { continue }
            if let before = query.modifiedBefore, page.updatedAt > before { continue }
            if let tags = query.tags, !tags.allSatisfy({ page.tags.contains($0) }) { continue }

            // Text search
            var relevanceScore = 1.0
            var matchedTerms: [String] = []

            if let text = query.text?.lowercased(), !text.isEmpty {
                let titleMatch = page.title.lowercased().contains(text)
                let bodyMatch = page.body.lowercased().contains(text)
                let excerptMatch = page.excerpt?.lowercased().contains(text) ?? false

                if !titleMatch && !bodyMatch && !excerptMatch { continue }

                if titleMatch {
                    relevanceScore += 2.0
                    matchedTerms.append("title")
                }
                if bodyMatch {
                    relevanceScore += 1.0
                    matchedTerms.append("body")
                }
                if excerptMatch {
                    relevanceScore += 0.5
                    matchedTerms.append("excerpt")
                }
            }

            let excerpt = page.excerpt ?? String(page.body.prefix(200))

            results.append(ContentSearchResult(
                pageId: page.pageId,
                entityId: entityId,
                title: page.title,
                excerpt: excerpt,
                spaceId: page.spaceId,
                relevanceScore: relevanceScore,
                matchedTerms: matchedTerms
            ))
        }

        return results
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .dropFirst(query.offset)
            .prefix(query.limit)
            .map { $0 }
    }

    // MARK: - Linking and Hierarchy Helpers

    private func processLinks(for entityId: EntityId, principal: String) async throws {
        guard var page = await world.getComponent(entityId, PageComponent.self) else { return }
        
        let foundPageIds = extractPageLinks(from: page.body)
        
        // Update related pages
        page.relatedPageIds = Array(foundPageIds)
        await world.addComponent(entityId, page)
        
        // Update backlinks (linkedFromPageIds) on target pages
        for targetPageId in foundPageIds {
            if let targetResult = await findPageEntity(targetPageId) {
                var targetPage = targetResult.1
                if !targetPage.linkedFromPageIds.contains(page.pageId) {
                    targetPage.linkedFromPageIds.append(page.pageId)
                    await world.addComponent(targetResult.0, targetPage)
                }
            }
        }
    }

    private func extractPageLinks(from text: String) -> Set<PageId> {
        // Simple regex to find [[UUID]] or [text](page:UUID) style links
        // For this implementation, we'll look for UUID-like strings in double brackets
        var pageIds = Set<PageId>()
        
        let pattern = "\\[\\[([0-9a-fA-F-]{36})\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        for result in results {
            let uuidString = nsString.substring(with: result.range(at: 1))
            if let id = PageId(uuidString: uuidString) {
                pageIds.insert(id)
            }
        }
        
        return pageIds
    }

    private func addChildToParent(pageId: PageId, parentId: PageId) async throws {
        if let parentResult = await findPageEntity(parentId) {
            var parentPage = parentResult.1
            if !parentPage.childPageIds.contains(pageId) {
                parentPage.childPageIds.append(pageId)
                await world.addComponent(parentResult.0, parentPage)
            }
        }
    }

    private func removeChildFromParent(pageId: PageId, parentId: PageId) async throws {
        if let parentResult = await findPageEntity(parentId) {
            var parentPage = parentResult.1
            parentPage.childPageIds.removeAll(where: { $0 == pageId })
            await world.addComponent(parentResult.0, parentPage)
        }
    }

    private func isDescendant(parentId: PageId, potentialChildId: PageId) async throws -> Bool {
        let children = await getChildPages(parentId)
        for (_, child) in children {
            if child.pageId == potentialChildId { return true }
            if try await isDescendant(parentId: child.pageId, potentialChildId: potentialChildId) {
                return true
            }
        }
        return false
    }

    // MARK: - Helpers

    private func findSpaceEntity(_ spaceId: SpaceId) async -> (EntityId, SpaceComponent)? {
        let entities = await world.entitiesWith(SpaceComponent.self)
        for entityId in entities {
            if let space = await world.getComponent(entityId, SpaceComponent.self),
               space.spaceId == spaceId {
                return (entityId, space)
            }
        }
        return nil
    }

    private func findPageEntity(_ pageId: PageId) async -> (EntityId, PageComponent)? {
        let entities = await world.entitiesWith(PageComponent.self)
        for entityId in entities {
            if let page = await world.getComponent(entityId, PageComponent.self),
               page.pageId == pageId {
                return (entityId, page)
            }
        }
        return nil
    }
}
