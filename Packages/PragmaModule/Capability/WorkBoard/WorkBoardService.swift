//
//  WorkBoardService.swift
//  PragmaModule
//
//  Work board service implementing snapshots and intent handling.
//

import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import CryptoKit
import Foundation
import GovernanceCore
public actor WorkBoardService: WorkBoardProviding {
    private struct Subscription {
        let scope: WorkBoardScope
        let trustTier: TrustTier
        let continuation: AsyncThrowingStream<WorkBoardSnapshot, Error>.Continuation
    }

    private let world: World
    private let workService: WorkService
    private let governance: GovernanceController
    private let executorProfiles: ExecutorProfileProviding?
    private let evidenceRecorder: EvidenceRecording?
    private let trustTierProvider: @Sendable (ActorId) async -> TrustTier

    private var attemptIndex: [AttemptId: EntityId] = [:]
    private var latestSnapshotByProject: [WorkItemId?: String] = [:]
    private var subscriptions: [UUID: Subscription] = [:]

    /// Creates a work board service bound to the provided world and governance controller.
    public init(
        world: World,
        workService: WorkService,
        governance: GovernanceController,
        executorProfiles: ExecutorProfileProviding? = nil,
        evidenceRecorder: EvidenceRecording? = nil,
        trustTierProvider: @escaping @Sendable (ActorId) async -> TrustTier = { _ in .bronze }
    ) {
        self.world = world
        self.workService = workService
        self.governance = governance
        self.executorProfiles = executorProfiles
        self.evidenceRecorder = evidenceRecorder
        self.trustTierProvider = trustTierProvider
    }

    /// Returns the current snapshot for the given scope.
    public func boardSnapshot(scope: WorkBoardScope, trustTier: TrustTier) async throws
        -> WorkBoardSnapshot {
        let snapshot = try await buildSnapshot(scope: scope, trustTier: trustTier)
        latestSnapshotByProject[scope.projectId] = snapshot.snapshotId
        return snapshot
    }

    /// Streams snapshots for the given scope.
    public func boardStream(scope: WorkBoardScope, trustTier: TrustTier) -> AsyncThrowingStream<
        WorkBoardSnapshot, Error
    > {
        AsyncThrowingStream { continuation in
            let subscriptionId = UUID()

            Task { [weak self] in
                guard let self else { return }
                do {
                    let snapshot = try await self.buildSnapshot(scope: scope, trustTier: trustTier)
                    await self.updateLatestSnapshot(
                        scope.projectId, snapshotId: snapshot.snapshotId)
                    continuation.yield(snapshot)
                    await self.addSubscription(
                        id: subscriptionId,
                        subscription: Subscription(
                            scope: scope,
                            trustTier: trustTier,
                            continuation: continuation
                        )
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            // Note: The await is required for actor isolation, not async operations.
            // The compiler warning "no 'async' operations occur within 'await' expression"
            // is a false positive and can be safely ignored.
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.removeSubscription(id: subscriptionId)
                }
            }
        }
    }

    /// Returns whether the intent passes governance checks.
    public func canSubmitIntent(_ intent: WorkBoardIntent) async throws -> Bool {
        let context = try await resolveIntentContext(intent)
        let decision = await governance.canWrite(
            WriteProposal(
                principal: intent.header.actorId.rawValue,
                module: "Pragma",
                operation: context.operation,
                entityId: context.entityId,
                componentType: context.componentType,
                context: context.context
            )
        )
        return decision.allowed
    }

    /// Applies a work board intent with governance enforcement.
    public func submitIntent(_ intent: WorkBoardIntent) async throws -> WorkBoardIntentResult {
        let context = try await resolveIntentContext(intent, requireSnapshotMatch: true)
        let decision = await governance.canWrite(
            WriteProposal(
                principal: intent.header.actorId.rawValue,
                module: "Pragma",
                operation: context.operation,
                entityId: context.entityId,
                componentType: context.componentType,
                context: context.context
            )
        )

        guard decision.allowed else {
            throw WorkBoardError.accessDenied(
                reason: decision.failedChecks.map { $0.message }.joined(separator: "; ")
            )
        }

        let receipt = try makeReceipt(for: intent)

        switch intent.action {
        case .createTask:
            try await handleCreateTask(intent, receipt: receipt)
        case .startAttempt:
            try await handleStartAttempt(intent, receipt: receipt)
        case .attachWorktree:
            try await handleAttachWorktree(intent, receipt: receipt)
        case .recordOutput:
            try await handleRecordOutput(intent, receipt: receipt)
        case .submitReviewComment:
            try await handleSubmitReviewComment(intent, receipt: receipt)
        case .requestRerun:
            try await handleRequestRerun(intent, receipt: receipt)
        case .mergeAttempt:
            try await handleMergeAttempt(intent, receipt: receipt)
        case .cancelAttempt:
            try await handleCancelAttempt(intent, receipt: receipt)
        }

        if let evidenceRecorder {
            let data = try WorkBoardIntent.canonicalEncode(intent)
            let head = EvidenceHead(
                headId: receipt.id, headHash: receipt.intentHash,
                lastActor: intent.header.actorId.rawValue)
            try? await evidenceRecorder.recordEvidence(head: head, content: data)
        }

        let updatedSnapshot = try await buildSnapshot(
            scope: WorkBoardScope(projectId: context.projectId),
            trustTier: context.trustTier
        )
        latestSnapshotByProject[context.projectId] = updatedSnapshot.snapshotId

        await broadcastSnapshots()

        return WorkBoardIntentResult(
            receipt: receipt,
            snapshotId: updatedSnapshot.snapshotId,
            status: .success,
            message: nil
        )
    }

    // MARK: - Snapshot Assembly

    private func buildSnapshot(scope: WorkBoardScope, trustTier: TrustTier) async throws
        -> WorkBoardSnapshot {
        _ = trustTier
        let projects = await projectProjections(scope: scope)
        let tasks = await taskProjections(scope: scope)
        let taskIdSet = Set(tasks.map(\.id))

        let attemptEntities = await world.query(AttemptComponent.self)
        let attempts =
            attemptEntities
            .map(\.1)
            .filter { taskIdSet.contains($0.taskId) }

        let attemptIds = Set(attempts.map(\.id))
        let artifacts = await artifactProjections(attemptIds: attemptIds)
        let reviewThreads = await reviewThreadProjections(attemptIds: attemptIds)

        var attemptsForSnapshot: [WorkBoardAttempt] = []
        for attempt in attempts {
            let worktree = try await worktreeRef(for: attempt)
            attemptsForSnapshot.append(
                WorkBoardAttempt(
                    id: attempt.id,
                    taskId: attempt.taskId,
                    executorProfileId: attempt.executorProfileId,
                    status: attempt.status,
                    worktree: worktree,
                    startedAt: attempt.startedAt,
                    completedAt: attempt.completedAt,
                    receipts: attempt.receipts,
                    diffSummaryArtifactId: attempt.diffSummaryArtifactId
                )
            )
        }

        let latestAttemptByTask = latestAttemptLookup(attempts)
        let tasksWithLatestAttempt = tasks.map { task in
            WorkBoardTask(
                id: task.id,
                key: task.key,
                title: task.title,
                statusId: task.statusId,
                priority: task.priority,
                latestAttemptId: latestAttemptByTask[task.id]?.id
            )
        }

        let columns = attemptColumns(from: attemptsForSnapshot)

        return WorkBoardSnapshot(
            snapshotId: UUID().uuidString.lowercased(),
            generatedAt: Date(),
            scope: scope,
            projects: projects,
            tasks: tasksWithLatestAttempt,
            attempts: attemptsForSnapshot,
            artifacts: artifacts,
            reviewThreads: reviewThreads,
            columns: columns
        )
    }

    private func projectProjections(scope: WorkBoardScope) async -> [WorkBoardProject] {
        let projects = await world.query(ProjectComponent.self)
        let filtered =
            projects
            .map(\.1)
            .filter { project in
                if let projectId = scope.projectId, project.id != projectId {
                    return false
                }
                if !scope.includeArchived, project.status == .archived {
                    return false
                }
                return true
            }
        return
            filtered
            .sorted { $0.id.raw.uuidString < $1.id.raw.uuidString }
            .map { project in
                WorkBoardProject(
                    id: project.id,
                    keyPrefix: project.keyPrefix,
                    name: project.name,
                    status: project.status
                )
            }
    }

    private func taskProjections(scope: WorkBoardScope) async -> [TaskComponent] {
        let tasks = await world.query(TaskComponent.self).map(\.1)
        if let taskIds = scope.taskIds {
            let set = Set(taskIds)
            return tasks.filter { set.contains($0.id) }
        }
        if let projectId = scope.projectId {
            return tasks.filter { $0.projectId == projectId }
        }
        return tasks
    }

    private func latestAttemptLookup(_ attempts: [AttemptComponent]) -> [WorkItemId:
        AttemptComponent] {
        var latest: [WorkItemId: AttemptComponent] = [:]
        for attempt in attempts {
            if let existing = latest[attempt.taskId] {
                if existing.createdAt < attempt.createdAt {
                    latest[attempt.taskId] = attempt
                }
            } else {
                latest[attempt.taskId] = attempt
            }
        }
        return latest
    }

    private func attemptColumns(from attempts: [WorkBoardAttempt]) -> [WorkBoardColumn] {
        let ordering: [AttemptStatus] = [
            .pending, .running, .inReview, .merged, .failed, .cancelled, .quarantined
        ]
        var grouped: [AttemptStatus: [AttemptId]] = [:]
        for attempt in attempts {
            grouped[attempt.status, default: []].append(attempt.id)
        }
        return ordering.map { status in
            let ids = grouped[status, default: []].sorted { $0.raw.uuidString < $1.raw.uuidString }
            return WorkBoardColumn(status: status, attemptIds: ids)
        }
    }

    private func artifactProjections(attemptIds: Set<AttemptId>) async -> [WorkBoardArtifact] {
        let artifacts = await world.query(ArtifactComponent.self)
            .map(\.1)
            .filter { attemptIds.contains($0.attemptId) }
        return
            artifacts
            .sorted { $0.createdAt < $1.createdAt }
            .map { artifact in
                WorkBoardArtifact(
                    id: artifact.id,
                    attemptId: artifact.attemptId,
                    kind: artifact.kind,
                    uri: artifact.uri,
                    sha256: artifact.sha256,
                    summary: artifact.summary
                )
            }
    }

    private func reviewThreadProjections(attemptIds: Set<AttemptId>) async
        -> [WorkBoardReviewThread] {
        let commentEntities = await world.query(
            CommentComponent.self, AttemptReviewLinkComponent.self)
        var grouped: [AttemptId: [WorkBoardReviewComment]] = [:]

        for (_, comment, link) in commentEntities {
            guard attemptIds.contains(link.attemptId) else { continue }
            let reviewComment = WorkBoardReviewComment(
                id: comment.id,
                attemptId: link.attemptId,
                authorId: comment.authorId,
                body: comment.body,
                filePath: link.filePath,
                line: link.line,
                createdAt: comment.createdAt
            )
            grouped[link.attemptId, default: []].append(reviewComment)
        }

        return grouped.map { attemptId, comments in
            WorkBoardReviewThread(
                attemptId: attemptId,
                comments: comments.sorted { $0.createdAt < $1.createdAt }
            )
        }.sorted { $0.attemptId.raw.uuidString < $1.attemptId.raw.uuidString }
    }

    private func worktreeRef(for attempt: AttemptComponent) async throws -> WorktreeRef? {
        guard let entityId = await attemptEntity(for: attempt.id) else { return nil }
        guard let worktree = await world.getComponent(entityId, WorktreeComponent.self) else {
            return nil
        }
        return WorktreeRef(
            id: worktree.id,
            baseRef: worktree.baseRef,
            baseCommit: worktree.baseCommit,
            displayName: worktree.displayName
        )
    }

    // MARK: - Intent Handling

    private struct IntentContext {
        let operation: String
        let componentType: String?
        let entityId: EntityId?
        let projectId: WorkItemId?
        let trustTier: TrustTier
        let context: [String: String]
    }

    private func resolveIntentContext(
        _ intent: WorkBoardIntent,
        requireSnapshotMatch: Bool = false
    ) async throws -> IntentContext {
        let actorId = intent.header.actorId
        let trustTier = await trustTierProvider(actorId)

        let context: IntentContext
        switch intent.action {
        case .createTask:
            let projectId = try workItemId(from: intent, key: "projectId")
            context = IntentContext(
                operation: "work_board_create_task",
                componentType: "TaskComponent",
                entityId: nil,
                projectId: projectId,
                trustTier: trustTier,
                context: ["project_id": projectId.raw.uuidString]
            )
        case .startAttempt:
            let taskId = try workItemId(from: intent, key: "taskId")
            let task = try await findTask(by: taskId)
            context = IntentContext(
                operation: "work_board_start_attempt",
                componentType: "AttemptComponent",
                entityId: nil,
                projectId: task.projectId,
                trustTier: trustTier,
                context: ["task_id": taskId.raw.uuidString]
            )
        case .attachWorktree:
            let attempt = try await findAttempt(from: intent)
            context = IntentContext(
                operation: "work_board_attach_worktree",
                componentType: "WorktreeComponent",
                entityId: attempt.entityId,
                projectId: attempt.task.projectId,
                trustTier: trustTier,
                context: ["attempt_id": attempt.component.id.raw.uuidString]
            )
        case .recordOutput:
            let attempt = try await findAttempt(from: intent)
            context = IntentContext(
                operation: "work_board_record_output",
                componentType: "ArtifactComponent",
                entityId: nil,
                projectId: attempt.task.projectId,
                trustTier: trustTier,
                context: ["attempt_id": attempt.component.id.raw.uuidString]
            )
        case .submitReviewComment:
            let attempt = try await findAttempt(from: intent)
            context = IntentContext(
                operation: "work_board_submit_review_comment",
                componentType: "CommentComponent",
                entityId: nil,
                projectId: attempt.task.projectId,
                trustTier: trustTier,
                context: ["attempt_id": attempt.component.id.raw.uuidString]
            )
        case .requestRerun:
            let attempt = try await findAttempt(from: intent)
            context = IntentContext(
                operation: "work_board_request_rerun",
                componentType: "AttemptComponent",
                entityId: attempt.entityId,
                projectId: attempt.task.projectId,
                trustTier: trustTier,
                context: ["attempt_id": attempt.component.id.raw.uuidString]
            )
        case .mergeAttempt:
            let attempt = try await findAttempt(from: intent)
            context = IntentContext(
                operation: "work_board_merge_attempt",
                componentType: "AttemptComponent",
                entityId: attempt.entityId,
                projectId: attempt.task.projectId,
                trustTier: trustTier,
                context: ["attempt_id": attempt.component.id.raw.uuidString]
            )
        case .cancelAttempt:
            let attempt = try await findAttempt(from: intent)
            context = IntentContext(
                operation: "work_board_cancel_attempt",
                componentType: "AttemptComponent",
                entityId: attempt.entityId,
                projectId: attempt.task.projectId,
                trustTier: trustTier,
                context: ["attempt_id": attempt.component.id.raw.uuidString]
            )
        }

        if requireSnapshotMatch {
            try await validateSnapshot(intent, projectId: context.projectId)
        }

        return context
    }

    private func validateSnapshot(_ intent: WorkBoardIntent, projectId: WorkItemId?) async throws {
        let expected = latestSnapshotByProject[projectId]
        guard let expected else {
            throw WorkBoardError.staleSnapshot(expected: "none", actual: intent.header.irSnapshotId)
        }
        if expected != intent.header.irSnapshotId {
            throw WorkBoardError.staleSnapshot(
                expected: expected, actual: intent.header.irSnapshotId)
        }
    }

    private func handleCreateTask(_ intent: WorkBoardIntent, receipt: ReceiptRef) async throws {
        _ = receipt
        let projectId = try workItemId(from: intent, key: "projectId")
        let title = try stringValue(from: intent, key: "title")
        let description = stringValueIfPresent(from: intent, key: "description")
        let tags = stringArrayValue(from: intent, key: "tags") ?? []

        let projectEntityId = try await projectEntityId(for: projectId)

        let config = CreateTaskConfiguration(
            projectId: projectEntityId,
            title: title,
            description: description ?? "",
            itemType: WorkItemType.task,
            priority: WorkPriority.medium,
            assigneeId: nil as String?,
            reporterId: intent.header.actorId.rawValue,
            dueDate: nil as Date?,
            tags: tags,
            principal: intent.header.actorId.rawValue
        )
        _ = try await workService.createTask(config: config)
    }

    private func handleStartAttempt(_ intent: WorkBoardIntent, receipt: ReceiptRef) async throws {
        let taskId = try workItemId(from: intent, key: "taskId")
        let executorProfileId = try stringValue(from: intent, key: "executorProfileId")
        let baseRef = stringValueIfPresent(from: intent, key: "baseRef")
        let baseCommit = stringValueIfPresent(from: intent, key: "baseCommit")
        let allowUnattended =
            boolValueIfPresent(from: intent, key: "allowUnattendedExecution") ?? false

        if allowUnattended {
            throw WorkBoardError.governanceViolation(
                code: "unattended_execution", message: "Unattended execution requires policy allow")
        }

        if let executorProfiles {
            let trustTier = await trustTierProvider(intent.header.actorId)
            let allowed = try await executorProfiles.canUseProfile(
                id: executorProfileId, trustTier: trustTier)
            guard allowed else {
                throw WorkBoardError.accessDenied(reason: "Executor profile not allowed")
            }
        }

        _ = try await findTask(by: taskId)

        let entityId = await world.createEntity()
        let attempt = AttemptComponent(
            taskId: taskId,
            executorProfileId: executorProfileId,
            baseRef: baseRef,
            baseCommit: baseCommit,
            status: .running,
            startedAt: Date(),
            receipts: [receipt]
        )
        await world.addComponent(entityId, attempt)
        attemptIndex[attempt.id] = entityId

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: intent.header.actorId.rawValue,
            module: "WorkBoardService",
            description: "Started attempt \(attempt.id) for task \(taskId)",
            metadata: [
                "original_event_type": "attempt_started",
                "attempt_id": attempt.id.raw.uuidString,
                "task_id": taskId.raw.uuidString
            ]
        )
    }

    private func handleAttachWorktree(_ intent: WorkBoardIntent, receipt: ReceiptRef) async throws {
        let attempt = try await findAttempt(from: intent)
        let worktreeId = try stringValue(from: intent, key: "worktreeId")
        let baseRef = try stringValue(from: intent, key: "baseRef")
        let baseCommit = try stringValue(from: intent, key: "baseCommit")
        let displayName = "worktree-\(worktreeId)"

        let worktree = WorktreeComponent(
            id: worktreeId,
            attemptId: attempt.component.id,
            baseRef: baseRef,
            baseCommit: baseCommit,
            displayName: displayName
        )
        await world.addComponent(attempt.entityId, worktree)

        var updated = attempt.component
        updated = updated.appendingReceipt(receipt)
        await world.addComponent(attempt.entityId, updated)
    }

    private func handleRecordOutput(_ intent: WorkBoardIntent, receipt: ReceiptRef) async throws {
        let attempt = try await findAttempt(from: intent)
        let kindRaw = try stringValue(from: intent, key: "artifactKind")
        guard let kind = ArtifactKind(rawValue: kindRaw) else {
            throw WorkBoardError.invalidParameters(message: "Unknown artifact kind: \(kindRaw)")
        }
        let uri = try stringValue(from: intent, key: "uri")
        let sha256 = try stringValue(from: intent, key: "sha256")
        let summary = stringValueIfPresent(from: intent, key: "summary")

        let artifactEntityId = await world.createEntity()
        let artifact = ArtifactComponent(
            attemptId: attempt.component.id,
            kind: kind,
            uri: uri,
            sha256: sha256,
            summary: summary
        )
        await world.addComponent(artifactEntityId, artifact)

        var updated = attempt.component.appendingReceipt(receipt)
        if kind == .diffSummary {
            updated = updated.withDiffSummary(artifact.id)
        }
        await world.addComponent(attempt.entityId, updated)
    }

    private func handleSubmitReviewComment(_ intent: WorkBoardIntent, receipt: ReceiptRef)
        async throws {
        let attempt = try await findAttempt(from: intent)
        let body = try stringValue(from: intent, key: "body")
        let filePath = stringValueIfPresent(from: intent, key: "filePath")
        let line = intValueIfPresent(from: intent, key: "line")

        let commentEntityId = await world.createEntity()
        let comment = CommentComponent(
            workItemId: attempt.task.id,
            authorId: intent.header.actorId.rawValue,
            body: body,
            isSystemComment: false,
            commentType: .review
        )
        await world.addComponent(commentEntityId, comment)

        let link = AttemptReviewLinkComponent(
            attemptId: attempt.component.id, filePath: filePath, line: line)
        await world.addComponent(commentEntityId, link)

        var updated = attempt.component.appendingReceipt(receipt)
        if updated.status == .running || updated.status == .pending {
            updated = updated.withStatus(.inReview)
        }
        await world.addComponent(attempt.entityId, updated)
    }

    private func handleRequestRerun(_ intent: WorkBoardIntent, receipt: ReceiptRef) async throws {
        let attempt = try await findAttempt(from: intent)
        var updated = attempt.component
        updated.status = .pending
        updated.startedAt = nil
        updated.completedAt = nil
        updated = updated.appendingReceipt(receipt)
        await world.addComponent(attempt.entityId, updated)
    }

    private func handleMergeAttempt(_ intent: WorkBoardIntent, receipt: ReceiptRef) async throws {
        let attempt = try await findAttempt(from: intent)
        _ = try stringValue(from: intent, key: "mergeStrategy")
        _ = try stringValue(from: intent, key: "expectedHeadCommit")

        var updated = attempt.component
        updated = updated.withStatus(.merged, completedAt: Date())
        updated = updated.appendingReceipt(receipt)
        await world.addComponent(attempt.entityId, updated)
    }

    private func handleCancelAttempt(_ intent: WorkBoardIntent, receipt: ReceiptRef) async throws {
        let attempt = try await findAttempt(from: intent)
        _ = stringValueIfPresent(from: intent, key: "reason")

        var updated = attempt.component
        updated = updated.withStatus(.cancelled, completedAt: Date())
        updated = updated.appendingReceipt(receipt)
        await world.addComponent(attempt.entityId, updated)
    }

    // MARK: - Intent Helpers

    private func makeReceipt(for intent: WorkBoardIntent) throws -> ReceiptRef {
        let data = try WorkBoardIntent.canonicalEncode(intent)
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        return ReceiptRef(id: UUID().uuidString.lowercased(), intentHash: hash)
    }

    private func workItemId(from intent: WorkBoardIntent, key: String) throws -> WorkItemId {
        let raw = try stringValue(from: intent, key: key)
        guard let id = WorkItemId(uuidString: raw) else {
            throw WorkBoardError.invalidParameters(message: "Invalid WorkItemId for \(key)")
        }
        return id
    }

    private func attemptId(from intent: WorkBoardIntent, key: String) throws -> AttemptId {
        let raw = try stringValue(from: intent, key: key)
        guard let uuid = UUID(uuidString: raw) else {
            throw WorkBoardError.invalidParameters(message: "Invalid AttemptId for \(key)")
        }
        return AttemptId(raw: uuid)
    }

    private func stringValue(from intent: WorkBoardIntent, key: String) throws -> String {
        guard let value = intent.parameters[key] else {
            throw WorkBoardError.invalidParameters(message: "Missing parameter: \(key)")
        }
        guard case .string(let string) = value else {
            throw WorkBoardError.invalidParameters(message: "Expected string for \(key)")
        }
        return string
    }

    private func stringValueIfPresent(from intent: WorkBoardIntent, key: String) -> String? {
        guard let value = intent.parameters[key] else { return nil }
        guard case .string(let string) = value else { return nil }
        return string
    }

    private func boolValueIfPresent(from intent: WorkBoardIntent, key: String) -> Bool? {
        guard let value = intent.parameters[key] else { return nil }
        guard case .bool(let flag) = value else { return nil }
        return flag
    }

    private func intValueIfPresent(from intent: WorkBoardIntent, key: String) -> Int? {
        guard let value = intent.parameters[key] else { return nil }
        guard case .number(let number) = value else { return nil }
        return Int(number)
    }

    private func stringArrayValue(from intent: WorkBoardIntent, key: String) -> [String]? {
        guard let value = intent.parameters[key] else { return nil }
        guard case .array(let values) = value else { return nil }
        let strings = values.compactMap { element -> String? in
            guard case .string(let string) = element else { return nil }
            return string
        }
        return strings
    }

    private func projectEntityId(for projectId: WorkItemId) async throws -> EntityId {
        let projects = await world.query(ProjectComponent.self)
        guard let match = projects.first(where: { $0.1.id == projectId }) else {
            throw WorkBoardError.projectNotFound(projectId)
        }
        return match.0
    }

    private func findTask(by taskId: WorkItemId) async throws -> TaskComponent {
        let tasks = await world.query(TaskComponent.self)
        guard let task = tasks.first(where: { $0.1.id == taskId })?.1 else {
            throw WorkBoardError.taskNotFound(taskId)
        }
        return task
    }

    private func attemptEntity(for attemptId: AttemptId) async -> EntityId? {
        if let cached = attemptIndex[attemptId] {
            return cached
        }
        let attempts = await world.query(AttemptComponent.self)
        if let match = attempts.first(where: { $0.1.id == attemptId }) {
            attemptIndex[attemptId] = match.0
            return match.0
        }
        return nil
    }

    private struct AttemptLookup {
        let entityId: EntityId
        let component: AttemptComponent
        let task: TaskComponent
    }

    private func findAttempt(from intent: WorkBoardIntent) async throws -> AttemptLookup {
        let attemptId = try attemptId(from: intent, key: "attemptId")
        guard let entityId = await attemptEntity(for: attemptId),
            let component = await world.getComponent(entityId, AttemptComponent.self)
        else {
            throw WorkBoardError.attemptNotFound(attemptId)
        }
        let task = try await findTask(by: component.taskId)
        return AttemptLookup(entityId: entityId, component: component, task: task)
    }

    // MARK: - Subscriptions

    private func broadcastSnapshots() async {
        let activeSubscriptions = subscriptions
        for (id, subscription) in activeSubscriptions {
            do {
                let snapshot = try await buildSnapshot(
                    scope: subscription.scope, trustTier: subscription.trustTier)
                latestSnapshotByProject[subscription.scope.projectId] = snapshot.snapshotId
                subscription.continuation.yield(snapshot)
            } catch {
                subscription.continuation.finish(throwing: error)
                subscriptions.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Actor-Isolated Helpers

    private func updateLatestSnapshot(_ projectId: WorkItemId?, snapshotId: String) {
        latestSnapshotByProject[projectId] = snapshotId
    }

    private func addSubscription(id: UUID, subscription: Subscription) {
        subscriptions[id] = subscription
    }

    private func removeSubscription(id: UUID) {
        subscriptions.removeValue(forKey: id)
    }
}

extension WorkBoardIntent {
    fileprivate static func canonicalEncode(_ intent: WorkBoardIntent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(intent)
    }
}
