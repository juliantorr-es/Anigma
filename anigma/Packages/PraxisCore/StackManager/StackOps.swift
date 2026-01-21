//
//  StackOps.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public enum StackOpsError: Error, CustomStringConvertible, Sendable {
    case dirtyWorktree
    case missingStack(String)
    case branchExists(String)
    case noBranches
    case validationBlocked
    case gitConflict(String)

    public var description: String {
        switch self {
        case .dirtyWorktree: return "Working tree must be clean"
        case .missingStack(let id): return "Missing stack: \(id)"
        case .branchExists(let name): return "Branch already exists: \(name)"
        case .noBranches: return "Stack has no branches"
        case .validationBlocked: return "ValidationMatrixGate blocked landing"
        case .gitConflict(let msg): return "Git conflict: \(msg)"
        }
    }
}

public struct StackOps: Sendable {
    public let cwd: URL
    public let repoRoot: URL
    public let git: GitRunner
    public let store: StackStore
    public let planner: StackPlanner
    public let repoGate: RepoIdentityGate
    public let validationGate: ValidationMatrixGate
    public let receipts: ReceiptWriter
    public let worktreeManager: WorktreeManager

    public init(cwd: URL) throws {
        let tempGit = GitRunner(repoRoot: cwd)
        let root = try tempGit.repoRoot(cwd: cwd)
        self.cwd = cwd
        self.repoRoot = root
        self.git = GitRunner(repoRoot: root)
        self.store = StackStore(repoRoot: root)
        self.planner = StackPlanner()
        self.repoGate = RepoIdentityGate()
        self.validationGate = ValidationMatrixGate()
        self.receipts = ReceiptWriter(repoRoot: root)
        self.worktreeManager = WorktreeManager(repoRoot: root)
    }

    public func stackInit(stackID: String, base: String, remote: String?, force: Bool) throws -> (StackRecord, String) {
        let artifacts = ArtifactWriter(repoRoot: repoRoot)
        let gate = try repoGate.evaluate(mode: .mutation, cwd: cwd, git: git)

        let record = try store.create(stackID: stackID, baseBranch: base, remote: remote, force: force)

        let receipt = PraxisReceipt(
            command: "stack init",
            repo: .init(repoRoot: repoRoot.path, worktreeRoot: cwd.path, branchName: gate.branchName, headSHA: gate.headSHA),
            gates: .init(repoIdentity: gate, validationMatrix: nil),
            gitOps: [],
            outcome: .success,
            message: "Created stack \(record.stackID)",
            payload: ["stackID": record.stackID, "base": record.baseBranch, "remote": record.remote ?? ""]
        )
        let receiptPath = try receipts.writeReceipt(receipt)
        _ = artifacts
        return (record, receiptPath)
    }

    public func stackCreate(stackID: String, branchName: String, parent: String?, checkout: Bool, worktree: String?) throws -> (StackRecord, String) {
        var artifacts = ArtifactWriter(repoRoot: repoRoot)
        let gate = try repoGate.evaluate(mode: .mutation, cwd: cwd, git: git)
        if try git.isDirty(cwd: cwd) { throw StackOpsError.dirtyWorktree }

        var record = try store.load(stackID: stackID)
        if try git.branchExists(branchName, cwd: cwd) { throw StackOpsError.branchExists(branchName) }

        let parentRef: String
        if let parent { parentRef = parent } else if let tip = planner.tipBranchName(record: record) { parentRef = tip } else { parentRef = record.baseBranch }

        var ops: [GitOpResult] = []
        if checkout {
            ops.append(try git.checkoutNewBranch(branchName, from: parentRef, cwd: cwd, artifacts: artifacts))
        } else {
            ops.append(try git.createBranch(branchName, from: parentRef, cwd: cwd, artifacts: artifacts))
        }

        var worktreePath: String?
        if let worktree, !worktree.isEmpty {
            let path: String? = (worktree == "auto" || worktree == "managed") ? nil : worktree

            // Get parent SHA for lease
            let (parentSHA, _) = try git.revParse(parentRef, cwd: cwd, artifacts: artifacts)

            let lease = try worktreeManager.createLease(
                branchName: branchName,
                baseCommit: parentSHA,
                runId: nil,
                customPath: path
            )

            worktreePath = lease.worktreePath
            let wtURL = URL(fileURLWithPath: lease.worktreePath, isDirectory: true)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = ["git", "worktree", "add", wtURL.path, branchName]
            proc.currentDirectoryURL = cwd
            let out = Pipe()
            let err = Pipe()
            proc.standardOutput = out
            proc.standardError = err
            try proc.run()
            proc.waitUntilExit()
            let outData = out.fileHandleForReading.readDataToEndOfFile()
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            _ = artifacts.writeArtifact(kind: "git", label: "stdout", data: outData)
            _ = artifacts.writeArtifact(kind: "git", label: "stderr", data: errData)
            ops.append(GitOpResult(argv: ["git", "worktree", "add", wtURL.path, branchName], cwd: cwd.path, exitCode: proc.terminationStatus, durationMS: 0, artifacts: .init(stdoutPath: artifacts.lastStdoutPath, stderrPath: artifacts.lastStderrPath)))
        }

        record.branches.append(.init(name: branchName, parent: parentRef, worktreePath: worktreePath))
        try store.save(record, overwrite: true)

        let receipt = PraxisReceipt(
            command: "stack create",
            repo: .init(repoRoot: repoRoot.path, worktreeRoot: cwd.path, branchName: gate.branchName, headSHA: gate.headSHA),
            gates: .init(repoIdentity: gate, validationMatrix: nil),
            gitOps: ops,
            outcome: .success,
            message: "Created branch \(branchName) on stack \(record.stackID)",
            payload: ["stackID": record.stackID, "branch": branchName, "parent": parentRef]
        )
        let receiptPath = try receipts.writeReceipt(receipt)
        return (record, receiptPath)
    }

    public func stackStatus(stackID: String) throws -> (String, String) {
        let artifacts = ArtifactWriter(repoRoot: repoRoot)
        let gate = try repoGate.evaluate(mode: .readOnly, cwd: cwd, git: git)

        let record = try store.load(stackID: stackID)
        var ops: [GitOpResult] = []

        let baseSHA: String
        do {
            let (sha, op) = try git.revParse(record.baseBranch, cwd: cwd, artifacts: artifacts)
            baseSHA = sha
            if let op { ops.append(op) }
        }

        var payload: [String: String] = [
            "stackID": record.stackID,
            "base": record.baseBranch,
            "baseSHA": baseSHA
        ]

        let ordered = try planner.orderedBranches(record: record)
        for b in ordered {
            let (sha, op) = try git.revParse(b.name, cwd: cwd, artifacts: artifacts)
            if let op { ops.append(op) }
            payload["branch:\(b.name)"] = sha
            payload["parent:\(b.name)"] = b.parent
        }

        let receipt = PraxisReceipt(
            command: "stack status",
            repo: .init(repoRoot: repoRoot.path, worktreeRoot: cwd.path, branchName: gate.branchName, headSHA: gate.headSHA),
            gates: .init(repoIdentity: gate, validationMatrix: nil),
            gitOps: ops,
            outcome: .success,
            message: "Status for stack \(record.stackID)",
            payload: payload
        )
        let receiptPath = try receipts.writeReceipt(receipt)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let statusJSON = String(data: try enc.encode(payload), encoding: .utf8) ?? "{}"
        return (statusJSON, receiptPath)
    }

    public func stackSync(stackID: String, remoteOverride: String?) throws -> (StackRecord, String) {
        let artifacts = ArtifactWriter(repoRoot: repoRoot)
        let gate = try repoGate.evaluate(mode: .mutation, cwd: cwd, git: git)
        if try git.isDirty(cwd: cwd) { throw StackOpsError.dirtyWorktree }

        let record = try store.load(stackID: stackID)
        let remote = remoteOverride ?? record.remote
        var ops: [GitOpResult] = []

        if let remote, !remote.isEmpty {
            ops.append(try git.fetch(remote: remote, cwd: cwd, artifacts: artifacts))
        }

        let ordered = try planner.orderedBranches(record: record)
        for b in ordered {
            ops.append(try git.checkout(b.name, cwd: cwd, artifacts: artifacts))
            do {
                ops.append(try git.rebase(onto: b.parent, cwd: cwd, artifacts: artifacts))
            } catch {
                throw StackOpsError.gitConflict(error.localizedDescription)
            }
        }

        try store.save(record, overwrite: true)

        let receipt = PraxisReceipt(
            command: "stack sync",
            repo: .init(repoRoot: repoRoot.path, worktreeRoot: cwd.path, branchName: gate.branchName, headSHA: gate.headSHA),
            gates: .init(repoIdentity: gate, validationMatrix: nil),
            gitOps: ops,
            outcome: .success,
            message: "Restacked stack \(record.stackID)",
            payload: ["stackID": record.stackID, "remote": remote ?? ""]
        )
        let receiptPath = try receipts.writeReceipt(receipt)
        return (record, receiptPath)
    }

    public enum LandStrategy: String, Sendable { case mergeNoFF, squash }

    public func stackLand(stackID: String, branch: String?, strategy: LandStrategy, cleanup: Bool, remotePush: Bool) throws -> (String, String) {
        var artifacts = ArtifactWriter(repoRoot: repoRoot)
        let gate = try repoGate.evaluate(mode: .mutation, cwd: cwd, git: git)
        if try git.isDirty(cwd: cwd) { throw StackOpsError.dirtyWorktree }

        var record = try store.load(stackID: stackID)
        guard let tip = branch ?? planner.tipBranchName(record: record) else { throw StackOpsError.noBranches }

        let validation = validationGate.run(repoRoot: repoRoot, artifacts: &artifacts)
        if validation.verdict == .block {
            let failReceipt = PraxisReceipt(
                command: "stack land",
                repo: .init(repoRoot: repoRoot.path, worktreeRoot: cwd.path, branchName: gate.branchName, headSHA: gate.headSHA),
                gates: .init(repoIdentity: gate, validationMatrix: validation),
                gitOps: [],
                outcome: .failure,
                message: "ValidationMatrixGate blocked landing",
                payload: ["stackID": record.stackID, "tip": tip]
            )
            let receiptPath = try receipts.writeReceipt(failReceipt)
            let ticketService = BoundaryTicketService(storageURL: repoRoot)
            let event = BlockageEvent(
                sessionID: gate.branchName ?? "unknown-session",
                patchHash: nil,
                violatedRuleIDs: ["validation-matrix"],
                gateName: "ValidationMatrixGate",
                receiptIDs: [receiptPath],
                reason: "One or more validate-target runs failed",
                acceptanceRefs: [],
                stopState: .blocked
            )
            let ticket = try ticketService.createTicket(from: event)
            _ = try ticketService.persist(ticket)
            throw StackOpsError.validationBlocked
        }

        var ops: [GitOpResult] = []
        ops.append(try git.checkout(record.baseBranch, cwd: cwd, artifacts: artifacts))

        switch strategy {
        case .mergeNoFF:
            ops.append(try git.mergeNoFF(tip, cwd: cwd, artifacts: artifacts))
        case .squash:
            ops.append(try git.mergeSquash(tip, cwd: cwd, artifacts: artifacts))
        }

        if remotePush, let remote = record.remote, !remote.isEmpty {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = ["git", "push", remote, record.baseBranch]
            proc.currentDirectoryURL = cwd
            let out = Pipe()
            let err = Pipe()
            proc.standardOutput = out
            proc.standardError = err
            try proc.run()
            proc.waitUntilExit()
            let outData = out.fileHandleForReading.readDataToEndOfFile()
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            _ = artifacts.writeArtifact(kind: "git", label: "stdout", data: outData)
            _ = artifacts.writeArtifact(kind: "git", label: "stderr", data: errData)
            ops.append(GitOpResult(argv: ["git", "push", remote, record.baseBranch], cwd: cwd.path, exitCode: proc.terminationStatus, durationMS: 0, artifacts: .init(stdoutPath: artifacts.lastStdoutPath, stderrPath: artifacts.lastStderrPath)))
        }

        if cleanup {
            for b in record.branches.map(\.name) {
                if b == record.baseBranch { continue }
                _ = try? git.deleteBranch(b, cwd: cwd, artifacts: artifacts)
            }
            record.branches.removeAll()
            try store.save(record, overwrite: true)
        }

        let (mergeSHA, _) = try git.revParse("HEAD", cwd: cwd, artifacts: artifacts)

        let receipt = PraxisReceipt(
            command: "stack land",
            repo: .init(repoRoot: repoRoot.path, worktreeRoot: cwd.path, branchName: gate.branchName, headSHA: gate.headSHA),
            gates: .init(repoIdentity: gate, validationMatrix: validation),
            gitOps: ops,
            outcome: .success,
            message: "Landed \(tip) into \(record.baseBranch)",
            payload: ["stackID": record.stackID, "tip": tip, "base": record.baseBranch, "mergeSHA": mergeSHA]
        )
        let receiptPath = try receipts.writeReceipt(receipt)
        return (mergeSHA, receiptPath)
    }
}
