//
//  PragmaModuleTests.swift
//  PragmaModuleTests
//
//  Tests/PragmaModuleTests
//
//  Tests for the Pragma work management module.
//

import XCTest
@testable import AnigmaCore
@testable import PragmaModule

final class PragmaModuleTests: XCTestCase {

    // MARK: - Test Fixtures

    var world: World!
    var governance: GovernanceController!
    var workService: WorkService!

    override func setUp() async throws {
        world = World()
        governance = GovernanceController()
        await governance.initialize()
        await governance.setMode(.autopilot, by: "test")
        workService = WorkService(world: world, governance: governance)
    }

    // MARK: - WorkItemId Tests

    func testWorkItemIdGeneration() {
        let id1 = WorkItemId()
        let id2 = WorkItemId()

        XCTAssertNotEqual(id1, id2)
        XCTAssertFalse(id1.raw.uuidString.isEmpty)
    }

    func testWorkItemIdFromString() {
        let id: WorkItemId = "test-item"
        XCTAssertNotNil(id.raw)
    }

    // MARK: - WorkItemType Tests

    func testWorkItemTypeHierarchy() {
        XCTAssertTrue(WorkItemType.project.isContainer)
        XCTAssertTrue(WorkItemType.epic.isContainer)
        XCTAssertFalse(WorkItemType.task.isContainer)
        XCTAssertFalse(WorkItemType.bug.isContainer)

        XCTAssertTrue(WorkItemType.project.validChildTypes.contains(.task))
        XCTAssertTrue(WorkItemType.project.validChildTypes.contains(.epic))
        XCTAssertFalse(WorkItemType.subtask.validChildTypes.contains(.task))
    }

    // MARK: - Priority Tests

    func testPriorityOrdering() {
        XCTAssertTrue(WorkPriority.low < WorkPriority.medium)
        XCTAssertTrue(WorkPriority.medium < WorkPriority.high)
        XCTAssertTrue(WorkPriority.high < WorkPriority.critical)
    }

    // MARK: - Workflow Tests

    func testSimpleWorkflow() {
        let workflow = WorkflowDefinition.simple

        XCTAssertEqual(workflow.id, "simple")
        XCTAssertEqual(workflow.initialStatusId, "todo")
        XCTAssertTrue(workflow.isValidTransition(from: "todo", to: "in_progress"))
        XCTAssertTrue(workflow.isValidTransition(from: "in_progress", to: "done"))
        XCTAssertFalse(workflow.isValidTransition(from: "done", to: "todo"))
    }

    func testSoftwareWorkflow() {
        let workflow = WorkflowDefinition.software

        XCTAssertEqual(workflow.id, "software")
        XCTAssertEqual(workflow.initialStatusId, "backlog")
        XCTAssertTrue(workflow.isValidTransition(from: "in_review", to: "done"))
        XCTAssertTrue(workflow.isValidTransition(from: "in_review", to: "in_progress"))
    }

    func testValidTransitions() {
        let workflow = WorkflowDefinition.simple

        let fromTodo = workflow.validTransitions(from: "todo")
        XCTAssertTrue(fromTodo.contains { $0.id == "in_progress" })
        XCTAssertTrue(fromTodo.contains { $0.id == "cancelled" })
    }

    // MARK: - TaskComponent Tests

    func testTaskComponentCreation() {
        let task = TaskComponent(
            key: "TEST-1",
            title: "Test Task",
            reporterId: "user1"
        )

        XCTAssertEqual(task.key, "TEST-1")
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertEqual(task.statusId, "todo")
        XCTAssertEqual(task.priority, .medium)
        XCTAssertNil(task.assigneeId)
        XCTAssertEqual(task.version, 1)
    }

    func testTaskMutations() {
        var task = TaskComponent(
            key: "TEST-1",
            title: "Test Task",
            reporterId: "user1"
        )

        // Status change
        task = task.withStatus("in_progress")
        XCTAssertEqual(task.statusId, "in_progress")
        XCTAssertEqual(task.version, 2)

        // Assignment
        task = task.withAssignee("user2")
        XCTAssertEqual(task.assigneeId, "user2")
        XCTAssertEqual(task.version, 3)

        // Priority
        task = task.withPriority(.high)
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.version, 4)

        // Tag
        task = task.withTag("urgent")
        XCTAssertTrue(task.tags.contains("urgent"))
        XCTAssertEqual(task.version, 5)

        // Time logging
        task = task.withTimeLogged(2.5)
        XCTAssertEqual(task.timeLogged, 2.5)
        XCTAssertEqual(task.version, 6)
    }

    func testTaskOverdue() {
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            fatalError("Failed to unwrap pastDate")
        }
        guard let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            fatalError("Failed to unwrap futureDate")
        }

        let overdueTask = TaskComponent(
            key: "TEST-1",
            title: "Overdue",
            reporterId: "user1",
            dueDate: pastDate
        )
        XCTAssertTrue(overdueTask.isOverdue)

        let futureTask = TaskComponent(
            key: "TEST-2",
            title: "Future",
            reporterId: "user1",
            dueDate: futureDate
        )
        XCTAssertFalse(futureTask.isOverdue)
    }

    // MARK: - ProjectComponent Tests

    func testProjectKeyGeneration() {
        var project = ProjectComponent(
            keyPrefix: "TEST",
            name: "Test Project",
            leadId: "user1"
        )

        XCTAssertEqual(project.previewNextKey(), "TEST-1")

        let key1 = project.generateNextKey()
        XCTAssertEqual(key1, "TEST-1")

        let key2 = project.generateNextKey()
        XCTAssertEqual(key2, "TEST-2")

        XCTAssertEqual(project.nextTaskNumber, 3)
    }

    func testProjectStatus() {
        XCTAssertTrue(ProjectStatus.active.isActive)
        XCTAssertTrue(ProjectStatus.planning.isActive)
        XCTAssertFalse(ProjectStatus.completed.isActive)

        XCTAssertTrue(ProjectStatus.completed.isTerminal)
        XCTAssertTrue(ProjectStatus.archived.isTerminal)
        XCTAssertFalse(ProjectStatus.active.isTerminal)
    }

    // MARK: - CommentComponent Tests

    func testCommentCreation() {
        let workItemId = WorkItemId()
        let comment = CommentComponent(
            workItemId: workItemId,
            authorId: "user1",
            body: "This is a comment"
        )

        XCTAssertEqual(comment.workItemId, workItemId)
        XCTAssertEqual(comment.body, "This is a comment")
        XCTAssertFalse(comment.isSystemComment)
        XCTAssertFalse(comment.isReply)
        XCTAssertFalse(comment.isEdited)
    }

    func testSystemCommentBuilders() {
        let workItemId = WorkItemId()

        let statusComment = CommentComponent.statusChange(
            workItemId: workItemId,
            userId: "user1",
            from: "todo",
            to: "in_progress"
        )
        XCTAssertTrue(statusComment.isSystemComment)
        XCTAssertEqual(statusComment.commentType, .statusChange)
        XCTAssertTrue(statusComment.body.contains("todo"))
        XCTAssertTrue(statusComment.body.contains("in_progress"))

        let assignComment = CommentComponent.assignmentChange(
            workItemId: workItemId,
            userId: "user1",
            oldAssignee: nil,
            newAssignee: "user2"
        )
        XCTAssertTrue(assignComment.isSystemComment)
        XCTAssertEqual(assignComment.commentType, .assignmentChange)
    }

    // MARK: - NotificationComponent Tests

    func testNotificationCreation() {
        let notification = NotificationComponent.assigned(
            to: "user1",
            workItemId: WorkItemId(),
            workItemTitle: "Test Task",
            by: "user2"
        )

        XCTAssertEqual(notification.recipientId, "user1")
        XCTAssertEqual(notification.notificationType, .assigned)
        XCTAssertEqual(notification.priority, .high)
        XCTAssertEqual(notification.category, .direct)
        XCTAssertFalse(notification.isRead)
    }

    func testNotificationPreferences() {
        var prefs = NotificationPreferences.default

        let notification = NotificationComponent(
            recipientId: "user1",
            notificationType: .statusChanged,
            title: "Status changed",
            body: "Test"
        )

        XCTAssertTrue(prefs.shouldDeliver(notification))

        // Disable status changed notifications
        prefs.enabledTypes.remove(.statusChanged)
        XCTAssertFalse(prefs.shouldDeliver(notification))
    }

    // MARK: - WorkService Tests

    func testCreateProject() async throws {
        let (entityId, project) = try await workService.createProject(
            keyPrefix: "TEST",
            name: "Test Project",
            leadId: "user1",
            principal: "test"
        )

        XCTAssertEqual(project.keyPrefix, "TEST")
        XCTAssertEqual(project.name, "Test Project")

        let retrieved = await workService.getProject(entityId: entityId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test Project")
    }

    func testCreateTask() async throws {
        let (projectId, _) = try await workService.createProject(
            keyPrefix: "TEST",
            name: "Test Project",
            leadId: "user1",
            principal: "test"
        )

        let (taskEntityId, task) = try await workService.createTask(
            projectId: projectId,
            title: "First Task",
            reporterId: "user1",
            principal: "test"
        )

        XCTAssertEqual(task.key, "TEST-1")
        XCTAssertEqual(task.title, "First Task")
        XCTAssertEqual(task.statusId, "todo")

        let retrieved = await workService.getTask(entityId: taskEntityId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.key, "TEST-1")
    }

    func testTaskTransition() async throws {
        let (projectId, _) = try await workService.createProject(
            keyPrefix: "TEST",
            name: "Test Project",
            leadId: "user1",
            principal: "test"
        )

        let (taskEntityId, _) = try await workService.createTask(
            projectId: projectId,
            title: "Task to Transition",
            reporterId: "user1",
            principal: "test"
        )

        let updated = try await workService.transitionTask(
            entityId: taskEntityId,
            to: "in_progress",
            principal: "test"
        )

        XCTAssertEqual(updated.statusId, "in_progress")
        XCTAssertEqual(updated.version, 2)
    }

    func testInvalidTransition() async throws {
        let (projectId, _) = try await workService.createProject(
            keyPrefix: "TEST",
            name: "Test Project",
            leadId: "user1",
            principal: "test"
        )

        let (taskEntityId, _) = try await workService.createTask(
            projectId: projectId,
            title: "Task",
            reporterId: "user1",
            principal: "test"
        )

        // Try invalid transition from todo directly to done
        do {
            _ = try await workService.transitionTask(
                entityId: taskEntityId,
                to: "done",
                principal: "test"
            )
            XCTFail("Should have thrown invalidTransition error")
        } catch let error as PragmaError {
            if case .invalidTransition(let from, let to) = error {
                XCTAssertEqual(from, "todo")
                XCTAssertEqual(to, "done")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testTaskAssignment() async throws {
        let (projectId, _) = try await workService.createProject(
            keyPrefix: "TEST",
            name: "Test Project",
            leadId: "user1",
            principal: "test"
        )

        let (taskEntityId, _) = try await workService.createTask(
            projectId: projectId,
            title: "Task to Assign",
            reporterId: "user1",
            principal: "test"
        )

        let updated = try await workService.assignTask(
            entityId: taskEntityId,
            to: "user2",
            principal: "test"
        )

        XCTAssertEqual(updated.assigneeId, "user2")
        XCTAssertTrue(updated.watcherIds.contains("user2"))
    }

    func testProjectTasks() async throws {
        let (projectId, _) = try await workService.createProject(
            keyPrefix: "TEST",
            name: "Test Project",
            leadId: "user1",
            principal: "test"
        )

        _ = try await workService.createTask(
            projectId: projectId,
            title: "Task 1",
            reporterId: "user1",
            principal: "test"
        )

        _ = try await workService.createTask(
            projectId: projectId,
            title: "Task 2",
            reporterId: "user1",
            principal: "test"
        )

        let tasks = await workService.getProjectTasks(projectId: projectId)
        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.contains { $0.key == "TEST-1" })
        XCTAssertTrue(tasks.contains { $0.key == "TEST-2" })
    }

    // MARK: - Filter Tests

    func testTaskFilter() {
        let task = TaskComponent(
            key: "TEST-1",
            title: "Important Bug Fix",
            priority: .high,
            assigneeId: "user1",
            reporterId: "user2",
            tags: ["urgent", "bug"]
        )

        // Matches assignee
        let assigneeFilter = TaskFilter(assigneeId: "user1")
        XCTAssertTrue(assigneeFilter.matches(task))

        // Wrong assignee
        let wrongAssignee = TaskFilter(assigneeId: "user3")
        XCTAssertFalse(wrongAssignee.matches(task))

        // Matches priority
        let priorityFilter = TaskFilter(priorities: [.high, .critical])
        XCTAssertTrue(priorityFilter.matches(task))

        // Matches tags
        let tagFilter = TaskFilter(tags: ["urgent"])
        XCTAssertTrue(tagFilter.matches(task))

        // Matches search
        let searchFilter = TaskFilter(searchText: "bug")
        XCTAssertTrue(searchFilter.matches(task))

        // Search in key
        let keySearch = TaskFilter(searchText: "test-1")
        XCTAssertTrue(keySearch.matches(task))
    }

    // MARK: - Automation Tests

    func testAutomationTriggerMatching() {
        let trigger = AutomationTrigger.onStatusChange(to: "done")

        let matchingEvent = WorkEvent(
            eventType: .statusChanged,
            principal: "user1",
            metadata: ["new_status": "done"]
        )
        XCTAssertTrue(trigger.matches(matchingEvent))

        let nonMatchingEvent = WorkEvent(
            eventType: .statusChanged,
            principal: "user1",
            metadata: ["new_status": "in_progress"]
        )
        XCTAssertFalse(trigger.matches(nonMatchingEvent))

        let wrongTypeEvent = WorkEvent(
            eventType: .assigned,
            principal: "user1"
        )
        XCTAssertFalse(trigger.matches(wrongTypeEvent))
    }

    func testAutomationRuleTemplates() {
        let bugRule = AutomationRule.autoAssignBugs(to: "bug-fixer")
        XCTAssertEqual(bugRule.trigger.eventType, .created)
        XCTAssertEqual(bugRule.actions.count, 1)
        XCTAssertEqual(bugRule.actions.first?.actionType, .assignTo)

        let celebrateRule = AutomationRule.celebrateDone()
        XCTAssertEqual(celebrateRule.trigger.eventType, .statusChanged)
        XCTAssertEqual(celebrateRule.actions.first?.actionType, .addComment)
    }
}
