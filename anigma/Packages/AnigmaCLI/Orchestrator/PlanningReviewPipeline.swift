//
//  PlanningReviewPipeline.swift
//  AnigmaCLIOrchestrator
//
//  Deterministic parallel-review pipeline for plan artifacts.
//

import AnigmaCLICore
import Foundation

public enum PlanReviewMode: String, Codable, Sendable {
    case serial
    case parallel
}

public enum ReviewLane: String, Codable, Sendable, CaseIterable {
    case systemsGovernance = "systems-governance"
    case implementationRealism = "implementation-realism"
    case uxOps = "ux-ops"

    public var displayName: String {
        switch self {
        case .systemsGovernance:
            return "Systems/Governance"
        case .implementationRealism:
            return "Implementation Realism"
        case .uxOps:
            return "UX/Ops"
        }
    }

    public var precedence: Int {
        switch self {
        case .systemsGovernance:
            return 0
        case .implementationRealism:
            return 1
        case .uxOps:
            return 2
        }
    }
}

public enum PatchOperation: String, Codable, Sendable {
    case add
    case update
    case delete
}

public struct ReviewFinding: Sendable, Codable, Hashable {
    public enum Severity: String, Codable, Sendable {
        case note
        case warning
        case error
    }

    public let severity: Severity
    public let summary: String
    public let detail: String
    public let filePath: String?
    public let line: Int?

    public init(
        severity: Severity,
        summary: String,
        detail: String,
        filePath: String? = nil,
        line: Int? = nil
    ) {
        self.severity = severity
        self.summary = summary
        self.detail = detail
        self.filePath = filePath
        self.line = line
    }
}

public struct StructuredPatch: Sendable, Codable, Hashable {
    public let filePath: String
    public let operation: PatchOperation
    public let summary: String
    public let startLine: Int?
    public let endLine: Int?
    public let body: String
    public let lane: ReviewLane
    public let conflictKey: String

    public init(
        filePath: String,
        operation: PatchOperation,
        summary: String,
        startLine: Int? = nil,
        endLine: Int? = nil,
        body: String,
        lane: ReviewLane
    ) {
        self.filePath = filePath
        self.operation = operation
        self.summary = summary
        self.startLine = startLine
        self.endLine = endLine
        self.body = body
        self.lane = lane
        self.conflictKey = [
            filePath,
            operation.rawValue,
            startLine.map(String.init) ?? "nil",
            endLine.map(String.init) ?? "nil"
        ].joined(separator: "|")
    }
}

public struct ReviewIR: Sendable, Codable, Hashable {
    public let reviewID: String
    public let reviewerIndex: Int
    public let lane: ReviewLane
    public let reviewedAt: Date
    public let taskID: UUID
    public let contractID: UUID
    public let mode: PlanReviewMode
    public let findings: [ReviewFinding]
    public let patches: [StructuredPatch]

    public init(
        reviewID: String,
        reviewerIndex: Int,
        lane: ReviewLane,
        reviewedAt: Date,
        taskID: UUID,
        contractID: UUID,
        mode: PlanReviewMode,
        findings: [ReviewFinding],
        patches: [StructuredPatch]
    ) {
        self.reviewID = reviewID
        self.reviewerIndex = reviewerIndex
        self.lane = lane
        self.reviewedAt = reviewedAt
        self.taskID = taskID
        self.contractID = contractID
        self.mode = mode
        self.findings = findings
        self.patches = patches
    }
}

public struct MergeConflict: Sendable, Codable, Hashable {
    public let conflictKey: String
    public let keptPatch: StructuredPatch
    public let droppedPatch: StructuredPatch
    public let reason: String

    public init(
        conflictKey: String,
        keptPatch: StructuredPatch,
        droppedPatch: StructuredPatch,
        reason: String
    ) {
        self.conflictKey = conflictKey
        self.keptPatch = keptPatch
        self.droppedPatch = droppedPatch
        self.reason = reason
    }
}

public struct MergeIR: Sendable, Codable, Hashable {
    public let mergeID: String
    public let contractID: UUID
    public let taskID: UUID
    public let mergedAt: Date
    public let reviewIDs: [String]
    public let selectedPatches: [StructuredPatch]
    public let conflicts: [MergeConflict]
    public let resolutionOrder: [ReviewLane]

    public init(
        mergeID: String,
        contractID: UUID,
        taskID: UUID,
        mergedAt: Date,
        reviewIDs: [String],
        selectedPatches: [StructuredPatch],
        conflicts: [MergeConflict],
        resolutionOrder: [ReviewLane]
    ) {
        self.mergeID = mergeID
        self.contractID = contractID
        self.taskID = taskID
        self.mergedAt = mergedAt
        self.reviewIDs = reviewIDs
        self.selectedPatches = selectedPatches
        self.conflicts = conflicts
        self.resolutionOrder = resolutionOrder
    }
}

public struct MergeReceipt: Sendable, Codable, Hashable {
    public let receiptID: String
    public let mergeID: String
    public let contractID: UUID
    public let taskID: UUID
    public let createdAt: Date
    public let reviewIDs: [String]
    public let selectedPatchCount: Int
    public let conflictCount: Int
    public let vaultPath: String

    public init(
        receiptID: String,
        mergeID: String,
        contractID: UUID,
        taskID: UUID,
        createdAt: Date,
        reviewIDs: [String],
        selectedPatchCount: Int,
        conflictCount: Int,
        vaultPath: String
    ) {
        self.receiptID = receiptID
        self.mergeID = mergeID
        self.contractID = contractID
        self.taskID = taskID
        self.createdAt = createdAt
        self.reviewIDs = reviewIDs
        self.selectedPatchCount = selectedPatchCount
        self.conflictCount = conflictCount
        self.vaultPath = vaultPath
    }
}

public struct PlanReviewOutcome: Sendable, Codable {
    public let plan: PlanOutcome
    public let reviewMode: PlanReviewMode
    public let reviewerCount: Int
    public let reviews: [ReviewIR]
    public let merge: MergeIR
    public let receipt: MergeReceipt
    public let vaultURL: URL
    public let reviewDirectoryURL: URL
    public let mergeURL: URL
    public let receiptURL: URL

    public init(
        plan: PlanOutcome,
        reviewMode: PlanReviewMode,
        reviewerCount: Int,
        reviews: [ReviewIR],
        merge: MergeIR,
        receipt: MergeReceipt,
        vaultURL: URL,
        reviewDirectoryURL: URL,
        mergeURL: URL,
        receiptURL: URL
    ) {
        self.plan = plan
        self.reviewMode = reviewMode
        self.reviewerCount = reviewerCount
        self.reviews = reviews
        self.merge = merge
        self.receipt = receipt
        self.vaultURL = vaultURL
        self.reviewDirectoryURL = reviewDirectoryURL
        self.mergeURL = mergeURL
        self.receiptURL = receiptURL
    }
}

public enum PlanReviewError: LocalizedError {
    case invalidReviewerCount(Int)
    case fileWriteFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .invalidReviewerCount(let count):
            return "Reviewer count must be at least 1, got \(count)."
        case .fileWriteFailed(let url):
            return "Failed to write review artifact at \(url.path)."
        }
    }
}

public actor PlanReviewPipeline {
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func review(
        task: TaskIntent,
        plan: PlanOutcome,
        context: TaskContext,
        reviewers: Int,
        mode: PlanReviewMode
    ) async throws -> PlanReviewOutcome {
        guard reviewers > 0 else {
            throw PlanReviewError.invalidReviewerCount(reviewers)
        }

        let lanes = Self.reviewLanes(for: reviewers)
        let reviews = try await Self.makeReviews(
            task: task,
            plan: plan,
            mode: mode,
            lanes: lanes
        )
        let merge = Self.merge(reviews: reviews, plan: plan, task: task)
        let vaultURL = Self.resolveVaultURL(context: context, task: task)
        let reviewDirectoryURL = vaultURL.appendingPathComponent("reviews", isDirectory: true)
        let mergeURL = vaultURL.appendingPathComponent("merge.json", isDirectory: false)
        let receiptURL = vaultURL.appendingPathComponent("merge-receipt.json", isDirectory: false)

        try Self.prepareDirectory(fileManager: fileManager, url: reviewDirectoryURL)
        try write(reviews, to: reviewDirectoryURL, reviewFileName: { $0.reviewID + ".json" })
        try write(merge, to: mergeURL)

        let receipt = MergeReceipt(
            receiptID: Self.stableID(prefix: "merge-receipt", task: task, contractID: plan.contract.id),
            mergeID: merge.mergeID,
            contractID: plan.contract.id,
            taskID: task.id,
            createdAt: Date(),
            reviewIDs: reviews.map { $0.reviewID },
            selectedPatchCount: merge.selectedPatches.count,
            conflictCount: merge.conflicts.count,
            vaultPath: vaultURL.path
        )
        try write(receipt, to: receiptURL)

        return PlanReviewOutcome(
            plan: plan,
            reviewMode: mode,
            reviewerCount: reviewers,
            reviews: reviews,
            merge: merge,
            receipt: receipt,
            vaultURL: vaultURL,
            reviewDirectoryURL: reviewDirectoryURL,
            mergeURL: mergeURL,
            receiptURL: receiptURL
        )
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PlanReviewError.fileWriteFailed(url)
        }
    }

    private func write<T: Encodable>(
        _ values: [T],
        to directoryURL: URL,
        reviewFileName: (T) -> String
    ) throws {
        for value in values {
            let fileURL = directoryURL.appendingPathComponent(reviewFileName(value), isDirectory: false)
            let data = try encoder.encode(value)
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                throw PlanReviewError.fileWriteFailed(fileURL)
            }
        }
    }

    private static func reviewLanes(for reviewers: Int) -> [ReviewLane] {
        let ordered = ReviewLane.allCases.sorted { $0.precedence < $1.precedence }
        guard reviewers <= ordered.count else {
            return (0..<reviewers).map { ordered[$0 % ordered.count] }
        }
        return Array(ordered.prefix(reviewers))
    }

    private static func makeReviews(
        task: TaskIntent,
        plan: PlanOutcome,
        mode: PlanReviewMode,
        lanes: [ReviewLane]
    ) async throws -> [ReviewIR] {
        switch mode {
        case .serial:
            return lanes.enumerated().map { index, lane in
                makeReview(
                    task: task,
                    plan: plan,
                    lane: lane,
                    reviewerIndex: index + 1,
                    mode: mode
                )
            }
        case .parallel:
            return try await withThrowingTaskGroup(of: ReviewIR.self) { group in
                for (index, lane) in lanes.enumerated() {
                    group.addTask {
                        makeReview(
                            task: task,
                            plan: plan,
                            lane: lane,
                            reviewerIndex: index + 1,
                            mode: mode
                        )
                    }
                }

                var reviews: [ReviewIR] = []
                for try await review in group {
                    reviews.append(review)
                }
                return reviews.sorted {
                    if $0.lane.precedence != $1.lane.precedence {
                        return $0.lane.precedence < $1.lane.precedence
                    }
                    return $0.reviewerIndex < $1.reviewerIndex
                }
            }
        }
    }

    private static func makeReview(
        task: TaskIntent,
        plan: PlanOutcome,
        lane: ReviewLane,
        reviewerIndex: Int,
        mode: PlanReviewMode
    ) -> ReviewIR {
        let timestamp = Date()
        let reviewID = stableID(prefix: lane.rawValue, task: task, contractID: plan.contract.id, suffix: reviewerIndex)
        let findings = makeFindings(task: task, plan: plan, lane: lane)
        let patches = makePatches(task: task, plan: plan, lane: lane)
        return ReviewIR(
            reviewID: reviewID,
            reviewerIndex: reviewerIndex,
            lane: lane,
            reviewedAt: timestamp,
            taskID: task.id,
            contractID: plan.contract.id,
            mode: mode,
            findings: findings,
            patches: patches
        )
    }

    private static func makeFindings(
        task: TaskIntent,
        plan: PlanOutcome,
        lane: ReviewLane
    ) -> [ReviewFinding] {
        switch lane {
        case .systemsGovernance:
            return [
                ReviewFinding(
                    severity: .note,
                    summary: "Keep parallel review auditable.",
                    detail: "Persist review JSON, merge JSON, and merge receipts under deterministic filenames so downstream checks can verify the review spine for \(task.summary).",
                    filePath: "Packages/AnigmaCLI/Executable/Main.swift",
                    line: 437
                )
            ]
        case .implementationRealism:
            let routeLabel = plan.route.selected?.id ?? "local-fallback"
            return [
                ReviewFinding(
                    severity: .note,
                    summary: "Thread review mode through daemon-first fallback.",
                    detail: "Daemon planning still falls back locally, so the review-aware path must stay in the executable wrapper and not assume daemon support yet.",
                    filePath: "Packages/AnigmaCLI/Executable/DaemonFirstCLIOrchestrator.swift",
                    line: 252
                ),
                ReviewFinding(
                    severity: .note,
                    summary: "Current route remains \(routeLabel).",
                    detail: "Use the selected route only as plan metadata; review merge output should not mutate provider routing.",
                    filePath: "Packages/AnigmaCLI/Orchestrator/AnigmaCLIOrchestrator.swift",
                    line: 92
                )
            ]
        case .uxOps:
            return [
                ReviewFinding(
                    severity: .note,
                    summary: "Expose review vault path in plan output.",
                    detail: "The user needs the artifact directory, merge.json, and merge-receipt.json path in text and JSON output so the enhanced vault is discoverable.",
                    filePath: "Packages/AnigmaCLI/Executable/Main.swift",
                    line: 483
                )
            ]
        }
    }

    private static func makePatches(
        task: TaskIntent,
        plan: PlanOutcome,
        lane: ReviewLane
    ) -> [StructuredPatch] {
        let objective = plan.contract.objective
        switch lane {
        case .systemsGovernance:
            return [
                StructuredPatch(
                    filePath: "Packages/AnigmaCLI/Executable/Main.swift",
                    operation: .update,
                    summary: "Emit review vault and merge receipt in CLI output",
                    startLine: 442,
                    endLine: 550,
                    body: "Add --reviewers / --review-mode handling and print the review vault path, merge.json, and merge-receipt.json when parallel review is enabled for \(task.summary).",
                    lane: lane
                )
            ]
        case .implementationRealism:
            return [
                StructuredPatch(
                    filePath: "Packages/AnigmaCLI/Orchestrator/AnigmaCLIOrchestrator.swift",
                    operation: .update,
                    summary: "Add review-aware plan API",
                    startLine: 70,
                    endLine: 130,
                    body: "Expose planWithReview(task:context:reviewers:reviewMode:) so the CLI can generate review IR and deterministic merges without mutating the base plan path for \(objective).",
                    lane: lane
                ),
                StructuredPatch(
                    filePath: "Packages/AnigmaCLI/Executable/DaemonFirstCLIOrchestrator.swift",
                    operation: .update,
                    summary: "Thread reviewer options through daemon-first fallback",
                    startLine: 252,
                    endLine: 319,
                    body: "Add a reviewed planTask path that forwards reviewer count and review mode to the local fallback when daemon-side planning is not available for \(task.summary).",
                    lane: lane
                )
            ]
        case .uxOps:
            return [
                StructuredPatch(
                    filePath: "Packages/AnigmaCLI/Orchestrator/PlanningReviewPipeline.swift",
                    operation: .add,
                    summary: "Persist review and merge artifacts in a dedicated vault",
                    startLine: 1,
                    endLine: 1,
                    body: "Write reviews/*.json, merge.json, and merge-receipt.json beneath a deterministic vault derived from the task ID and worktree root for \(task.summary).",
                    lane: lane
                ),
                StructuredPatch(
                    filePath: "Packages/AnigmaCLI/Executable/Main.swift",
                    operation: .update,
                    summary: "Add reviewed plan payload fields",
                    startLine: 437,
                    endLine: 550,
                    body: "Carry review metadata in the JSON payload so downstream tools can inspect reviewer lanes, merge decisions, and file paths for \(objective).",
                    lane: lane
                )
            ]
        }
    }

    private static func merge(
        reviews: [ReviewIR],
        plan: PlanOutcome,
        task: TaskIntent
    ) -> MergeIR {
        let orderedReviews = reviews.sorted {
            if $0.lane.precedence != $1.lane.precedence {
                return $0.lane.precedence < $1.lane.precedence
            }
            return $0.reviewerIndex < $1.reviewerIndex
        }
        var selected: [StructuredPatch] = []
        var selectedByKey: [String: StructuredPatch] = [:]
        var conflicts: [MergeConflict] = []

        for review in orderedReviews {
            for patch in review.patches.sorted(by: patchSort(_:_:)) {
                if let existing = selectedByKey[patch.conflictKey] {
                    conflicts.append(
                        MergeConflict(
                            conflictKey: patch.conflictKey,
                            keptPatch: existing,
                            droppedPatch: patch,
                            reason: "Lane precedence kept \(existing.lane.displayName) over \(patch.lane.displayName)."
                        )
                    )
                    continue
                }
                selectedByKey[patch.conflictKey] = patch
                selected.append(patch)
            }
        }

        let resolutionOrder = orderedReviews.map(\.lane)
        return MergeIR(
            mergeID: stableID(prefix: "merge", task: task, contractID: plan.contract.id),
            contractID: plan.contract.id,
            taskID: task.id,
            mergedAt: Date(),
            reviewIDs: orderedReviews.map(\.reviewID),
            selectedPatches: selected.sorted(by: patchSort(_:_:)),
            conflicts: conflicts,
            resolutionOrder: resolutionOrder
        )
    }

    private static func patchSort(_ lhs: StructuredPatch, _ rhs: StructuredPatch) -> Bool {
        if lhs.lane.precedence != rhs.lane.precedence {
            return lhs.lane.precedence < rhs.lane.precedence
        }
        if lhs.filePath != rhs.filePath {
            return lhs.filePath < rhs.filePath
        }
        if lhs.startLine != rhs.startLine {
            return (lhs.startLine ?? 0) < (rhs.startLine ?? 0)
        }
        return lhs.summary < rhs.summary
    }

    private static func resolveVaultURL(context: TaskContext, task: TaskIntent) -> URL {
        let root = context.artifactsRoot ?? context.worktreeRoot
            .appendingPathComponent(".anigma", isDirectory: true)
            .appendingPathComponent("plans", isDirectory: true)
        return root.appendingPathComponent(task.id.uuidString, isDirectory: true)
    }

    private static func prepareDirectory(fileManager: FileManager, url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    private static func stableID(prefix: String, task: TaskIntent, contractID: UUID, suffix: Int? = nil) -> String {
        let suffixText = suffix.map { "-\($0)" } ?? ""
        return "\(prefix)-\(task.id.uuidString.prefix(8))-\(contractID.uuidString.prefix(8))\(suffixText)"
    }
}
