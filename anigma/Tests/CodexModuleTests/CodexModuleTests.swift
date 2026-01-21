//
//  CodexModuleTests.swift
//  CodexModuleTests
//
//  Tests for the Codex knowledge base module.
//

import Testing
import Foundation
@testable import AnigmaCore
@testable import CodexModule

@Suite("Codex Module Tests")
struct CodexModuleTests {

    // MARK: - Space Tests

    @Test("Space component basic properties")
    func spaceBasicProperties() {
        let space = SpaceComponent(
            spaceType: .knowledgeBase,
            key: "kb",
            name: "Knowledge Base",
            description: "Help articles and documentation",
            visibility: .public,
            ownerId: "admin"
        )

        #expect(space.key == "KB")  // Should be uppercased
        #expect(space.name == "Knowledge Base")
        #expect(space.spaceType == .knowledgeBase)
        #expect(!space.isArchived)
    }

    @Test("Space archiving")
    func spaceArchiving() {
        var space = SpaceComponent(
            key: "old",
            name: "Old Space",
            ownerId: "admin"
        )

        #expect(!space.isArchived)

        space.archive()
        #expect(space.isArchived)

        space.unarchive()
        #expect(!space.isArchived)
    }

    // MARK: - Page Tests

    @Test("Page component basic properties")
    func pageBasicProperties() {
        let spaceId = SpaceId()
        let page = PageComponent(
            spaceId: spaceId,
            pageType: .article,
            title: "Getting Started Guide",
            body: "# Introduction\n\nWelcome to the guide.",
            author: "writer"
        )

        #expect(page.title == "Getting Started Guide")
        #expect(page.slug == "getting-started-guide")
        #expect(page.pageType == .article)
        #expect(page.status == .draft)
        #expect(page.isEditable)
        #expect(!page.isPublished)
    }

    @Test("Page slug generation")
    func pageSlugGeneration() {
        #expect(PageComponent.generateSlug(from: "Hello World") == "hello-world")
        #expect(PageComponent.generateSlug(from: "Test: Special Characters!") == "test-special-characters")
        #expect(PageComponent.generateSlug(from: "Multiple   Spaces") == "multiple-spaces")
    }

    @Test("Page content update and versioning")
    func pageContentUpdate() {
        let spaceId = SpaceId()
        var page = PageComponent(
            spaceId: spaceId,
            title: "Original Title",
            body: "Original content",
            author: "author1"
        )

        let v1 = page.versionNumber

        page.updateContent(
            title: "Updated Title",
            body: "Updated content",
            editor: "editor1"
        )

        #expect(page.title == "Updated Title")
        #expect(page.versionNumber == v1 + 1)
        #expect(page.contributors.contains("editor1"))
        #expect(page.slug == "updated-title")
    }

    @Test("Page publishing")
    func pagePublishing() {
        let spaceId = SpaceId()
        var page = PageComponent(
            spaceId: spaceId,
            title: "Draft Article",
            author: "writer"
        )

        #expect(page.status == .draft)

        page.publish(by: "reviewer")
        #expect(page.status == .published)
        #expect(page.isPublished)
        #expect(page.approvedBy == "reviewer")
        #expect(page.publishedAt != nil)
    }

    @Test("Page locking")
    func pageLocking() {
        let spaceId = SpaceId()
        var page = PageComponent(
            spaceId: spaceId,
            title: "Lockable Page",
            author: "writer"
        )

        #expect(!page.isLocked)

        let acquired = page.acquireLock(by: "editor1", duration: 3600)
        #expect(acquired)
        #expect(page.isLocked)
        #expect(page.lockedBy == "editor1")

        // Same user can't lock again
        let reacquired = page.acquireLock(by: "editor1")
        #expect(reacquired)  // Extend their own lock

        // Different user can't lock
        let otherAcquired = page.acquireLock(by: "editor2")
        #expect(!otherAcquired)

        // Release lock
        let released = page.releaseLock(by: "editor1")
        #expect(released)
        #expect(!page.isLocked)
    }

    @Test("Page feedback tracking")
    func pageFeedbackTracking() {
        let spaceId = SpaceId()
        var page = PageComponent(
            spaceId: spaceId,
            pageType: .article,
            title: "Help Article",
            author: "writer"
        )

        page.recordFeedback(helpful: true)
        page.recordFeedback(helpful: true)
        page.recordFeedback(helpful: false)

        #expect(page.helpfulCount == 2)
        #expect(page.notHelpfulCount == 1)
        #expect(page.helpfulnessScore! > 0.6)
    }

    // MARK: - Template Tests

    @Test("Template placeholder application")
    func templatePlaceholderApplication() {
        let template = TemplateComponent.meetingNotes(author: "admin")

        let values = [
            "meeting_title": "Sprint Planning",
            "date": "2024-01-15",
            "attendees": "Alice, Bob, Carol",
            "facilitator": "Alice"
        ]

        let (title, body) = template.apply(values: values)

        #expect(title.contains("Sprint Planning"))
        #expect(title.contains("2024-01-15"))
        #expect(body.contains("Alice, Bob, Carol"))
    }

    @Test("Template validation")
    func templateValidation() {
        let template = TemplateComponent.decisionRecord(author: "admin")

        // Missing required fields
        let missing = template.validate(values: [:])
        #expect(missing.contains("number"))
        #expect(missing.contains("title"))
        #expect(missing.contains("date"))

        // With required fields
        let complete = template.validate(values: [
            "number": "1",
            "title": "Use Swift",
            "date": "2024-01-15"
        ])
        #expect(complete.isEmpty)
    }

    @Test("Built-in templates")
    func builtInTemplates() {
        let meetingNotes = TemplateComponent.meetingNotes(author: "admin")
        #expect(meetingNotes.category == .meeting)
        #expect(meetingNotes.defaultPageType == .meeting)

        let adr = TemplateComponent.decisionRecord(author: "admin")
        #expect(adr.category == .software)
        #expect(adr.defaultPageType == .decision)

        let runbook = TemplateComponent.runbook(author: "admin")
        #expect(runbook.category == .software)
        #expect(runbook.defaultPageType == .runbook)

        let altMedia = TemplateComponent.altMediaRequest(author: "admin")
        #expect(altMedia.category == .accessibility)
    }

    // MARK: - Version Tests

    @Test("Page version creation")
    func pageVersionCreation() {
        let spaceId = SpaceId()
        let page = PageComponent(
            spaceId: spaceId,
            title: "Test Page",
            body: "Line 1\nLine 2\nLine 3",
            author: "author"
        )

        let version = PageVersionComponent.from(
            page: page,
            previousVersion: nil,
            changeMessage: "Initial version",
            changedFields: ["title", "body"]
        )

        #expect(version.pageId == page.pageId)
        #expect(version.versionNumber == 1)
        #expect(version.changeMessage == "Initial version")
    }

    // MARK: - Comment Tests

    @Test("Comment with mentions")
    func commentWithMentions() {
        let pageId = PageId()
        let comment = PageCommentComponent(
            pageId: pageId,
            body: "Hey @alice and @bob, please review this section",
            author: "carol"
        )

        #expect(comment.mentions.contains("alice"))
        #expect(comment.mentions.contains("bob"))
        #expect(comment.mentions.count == 2)
    }

    @Test("Comment resolution")
    func commentResolution() {
        let pageId = PageId()
        var comment = PageCommentComponent(
            pageId: pageId,
            body: "This needs clarification",
            author: "reviewer"
        )

        #expect(!comment.isResolved)

        comment.resolve(by: "author")
        #expect(comment.isResolved)
        #expect(comment.resolvedBy == "author")

        comment.reopen()
        #expect(!comment.isResolved)
    }

    @Test("Comment reactions")
    func commentReactions() {
        let pageId = PageId()
        var comment = PageCommentComponent(
            pageId: pageId,
            body: "Great suggestion!",
            author: "user1"
        )

        comment.addReaction("👍", by: "user2")
        comment.addReaction("👍", by: "user3")
        comment.addReaction("❤️", by: "user2")

        #expect(comment.reactions.count == 2)

        let thumbsUp = comment.reactions.first { $0.emoji == "👍" }
        #expect(thumbsUp?.count == 2)

        comment.removeReaction("👍", by: "user2")
        let updatedThumbsUp = comment.reactions.first { $0.emoji == "👍" }
        #expect(updatedThumbsUp?.count == 1)
    }

    @Test("Inline comment")
    func inlineComment() {
        let pageId = PageId()
        let comment = PageCommentComponent(
            pageId: pageId,
            body: "This term needs definition",
            isInline: true,
            anchorText: "accessibility",
            anchorPosition: 150,
            author: "editor"
        )

        #expect(comment.isInline)
        #expect(comment.anchorText == "accessibility")
    }

    // MARK: - Service Integration Tests

    @Test("CodexService creates space")
    func serviceCreatesSpace() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        let space = SpaceComponent(
            spaceType: .documentation,
            key: "docs",
            name: "Documentation",
            ownerId: "admin"
        )

        let entityId = try await service.createSpace(space, principal: "admin")

        let retrieved = await service.getSpace(entityId)
        #expect(retrieved != nil)
        #expect(retrieved?.name == "Documentation")
    }

    @Test("CodexService finds space by key")
    func serviceFindsSpaceByKey() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        let space = SpaceComponent(
            key: "findme",
            name: "Find Me Space",
            ownerId: "admin"
        )

        _ = try await service.createSpace(space, principal: "admin")

        let found = await service.findSpace(byKey: "FINDME")
        #expect(found != nil)
        #expect(found?.1.name == "Find Me Space")
    }

    @Test("CodexService creates and updates page")
    func serviceManagesPage() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        // Create space first
        let space = SpaceComponent(key: "test", name: "Test Space", ownerId: "admin")
        _ = try await service.createSpace(space, principal: "admin")

        // Create page
        let page = PageComponent(
            spaceId: space.spaceId,
            title: "Test Article",
            body: "Initial content",
            author: "writer"
        )

        let entityId = try await service.createPage(page, principal: "writer")

        // Update page
        try await service.updatePage(
            entityId,
            title: "Updated Article",
            body: "Updated content",
            changeMessage: "Fixed typo",
            principal: "editor"
        )

        let updated = await service.getPage(entityId)
        #expect(updated?.title == "Updated Article")
        #expect(updated?.versionNumber == 2)
    }

    @Test("CodexService publishes page")
    func servicePublishesPage() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        let space = SpaceComponent(key: "pub", name: "Publish Test", ownerId: "admin")
        _ = try await service.createSpace(space, principal: "admin")

        let page = PageComponent(
            spaceId: space.spaceId,
            title: "To Be Published",
            author: "writer"
        )

        let entityId = try await service.createPage(page, principal: "writer")
        try await service.publishPage(entityId, principal: "reviewer")

        let published = await service.getPage(entityId)
        #expect(published?.status == .published)
    }

    @Test("CodexService manages templates")
    func serviceManagesTemplates() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        // Register templates
        await service.registerTemplate(TemplateComponent.meetingNotes(author: "admin"))
        await service.registerTemplate(TemplateComponent.decisionRecord(author: "admin"))
        await service.registerTemplate(TemplateComponent.altMediaRequest(author: "admin"))

        let allTemplates = await service.listTemplates()
        #expect(allTemplates.count == 3)

        let accessibilityTemplates = await service.listTemplates(category: .accessibility)
        #expect(accessibilityTemplates.count == 1)
    }

    @Test("CodexService creates page from template")
    func serviceCreatesPageFromTemplate() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        let space = SpaceComponent(key: "tmpl", name: "Template Test", ownerId: "admin")
        _ = try await service.createSpace(space, principal: "admin")

        let template = TemplateComponent.meetingNotes(author: "admin")
        await service.registerTemplate(template)

        let entityId = try await service.createPageFromTemplate(
            templateId: template.templateId,
            spaceId: space.spaceId,
            values: [
                "meeting_title": "Sprint Review",
                "date": "2024-01-20",
                "attendees": "Team Alpha",
                "facilitator": "Lead"
            ],
            principal: "organizer"
        )

        let page = await service.getPage(entityId)
        #expect(page?.title.contains("Sprint Review") == true)
    }

    @Test("CodexService search")
    func serviceSearch() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        let space = SpaceComponent(key: "search", name: "Search Test", ownerId: "admin")
        _ = try await service.createSpace(space, principal: "admin")

        // Create pages
        _ = try await service.createPage(
            PageComponent(spaceId: space.spaceId, title: "Swift Guide", body: "Learn Swift programming", author: "writer"),
            principal: "writer"
        )
        _ = try await service.createPage(
            PageComponent(spaceId: space.spaceId, title: "Python Tutorial", body: "Learn Python basics", author: "writer"),
            principal: "writer"
        )
        _ = try await service.createPage(
            PageComponent(spaceId: space.spaceId, title: "Swift Best Practices", body: "Advanced Swift patterns", author: "writer"),
            principal: "writer"
        )

        let swiftResults = await service.search(ContentSearchQuery(text: "swift"))
        #expect(swiftResults.count == 2)

        let pythonResults = await service.search(ContentSearchQuery(text: "python"))
        #expect(pythonResults.count == 1)
    }

    @Test("CodexService manages comments")
    func serviceManagesComments() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        let space = SpaceComponent(key: "comment", name: "Comment Test", ownerId: "admin")
        _ = try await service.createSpace(space, principal: "admin")

        let page = PageComponent(
            spaceId: space.spaceId,
            title: "Commentable Page",
            author: "writer"
        )
        let pageEntityId = try await service.createPage(page, principal: "writer")
        guard let pageComp = await service.getPage(pageEntityId) else {
            fatalError("Failed to unwrap pageComp")
        }

        // Add comments
        let comment1 = PageCommentComponent(
            pageId: pageComp.pageId,
            body: "Great article!",
            author: "reader1"
        )
        _ = try await service.addComment(comment1, principal: "reader1")

        let comment2 = PageCommentComponent(
            pageId: pageComp.pageId,
            body: "Could use more examples",
            author: "reader2"
        )
        _ = try await service.addComment(comment2, principal: "reader2")

        let comments = await service.getComments(pageId: pageComp.pageId)
        #expect(comments.count == 2)
    }

    @Test("CodexService version history")
    func serviceVersionHistory() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = CodexService(world: world, governance: governance)

        let space = SpaceComponent(key: "ver", name: "Version Test", ownerId: "admin")
        _ = try await service.createSpace(space, principal: "admin")

        let page = PageComponent(
            spaceId: space.spaceId,
            title: "Versioned Page",
            body: "Version 1",
            author: "writer"
        )
        let entityId = try await service.createPage(page, principal: "writer")
        guard let pageComp = await service.getPage(entityId) else {
            fatalError("Failed to unwrap pageComp")
        }

        // Make updates
        try await service.updatePage(entityId, body: "Version 2", changeMessage: "Update 1", principal: "editor")
        try await service.updatePage(entityId, body: "Version 3", changeMessage: "Update 2", principal: "editor")

        let history = await service.getVersionHistory(pageId: pageComp.pageId)
        #expect(history.count == 3)
        #expect(history.first?.versionNumber == 3)  // Newest first
    }
}
