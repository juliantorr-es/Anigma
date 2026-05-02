//
//  StackCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import Foundation
import PraxisCore

struct StackCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "stack",
            abstract: "Praxis-native branch stack manager with receipts and gates.",
            subcommands: [
                StackInit.self, StackCreate.self, StackStatus.self, StackSync.self, StackLand.self, StackWorktree.self
            ]
        )
    }
}

struct StackWorktree: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "worktree",
            abstract: "Manage git worktree leases.",
            subcommands: [WorktreeList.self, WorktreePrune.self, WorktreeLock.self, WorktreeUnlock.self]
        )
    }
}

struct WorktreeList: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "list") }

    func run() async throws {
        let ops = try StackOps(cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let leases = try ops.worktreeManager.listLeases()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        let json = String(data: try enc.encode(leases), encoding: .utf8) ?? "[]"
        print(json)
    }
}

struct WorktreePrune: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "prune") }

    @Flag(name: .long) var dryRun: Bool = false

    func run() async throws {
        let ops = try StackOps(cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let actions = try ops.worktreeManager.housekeeping(dryRun: dryRun, git: ops.git)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json = String(data: try enc.encode(actions), encoding: .utf8) ?? "[]"
        print(json)
    }
}

struct WorktreeLock: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "lock") }

    @Argument(help: "Path to worktree") var path: String
    @Option(name: .long) var reason: String

    func run() async throws {
        let ops = try StackOps(cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        try ops.worktreeManager.lock(path: path, reason: reason)
        print(#"{"ok":true,"message":"Locked worktree"}"#)
    }
}

struct WorktreeUnlock: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "unlock") }

    @Argument(help: "Path to worktree") var path: String

    func run() async throws {
        let ops = try StackOps(cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        try ops.worktreeManager.unlock(path: path)
        print(#"{"ok":true,"message":"Unlocked worktree"}"#)
    }
}

struct StackInit: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "init") }

    @Option(name: .long) var id: String
    @Option(name: .long) var base: String = "main"
    @Option(name: .long) var remote: String?
    @Flag(name: .long) var force: Bool = false

    func run() async throws {
        let ops = try StackOps(
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let (_, receiptPath) = try ops.stackInit(
            stackID: id, base: base, remote: remote, force: force)
        print(#"{"ok":true,"receipt":"\#(receiptPath)"}"#)
    }
}

struct StackCreate: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "create") }

    @Option(name: .long) var id: String
    @Option(name: .long) var branch: String
    @Option(name: .long) var parent: String?
    @Flag(name: .long) var noCheckout: Bool = false
    @Option(name: .long) var worktree: String?

    func run() async throws {
        let ops = try StackOps(
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let (_, receiptPath) = try ops.stackCreate(
            stackID: id, branchName: branch, parent: parent, checkout: !noCheckout,
            worktree: worktree)
        print(#"{"ok":true,"receipt":"\#(receiptPath)"}"#)
    }
}

struct StackStatus: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "status") }

    @Option(name: .long) var id: String

    func run() async throws {
        let ops = try StackOps(
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let (statusJSON, receiptPath) = try ops.stackStatus(stackID: id)
        print(#"{"ok":true,"status":\#(statusJSON),"receipt":"\#(receiptPath)"}"#)
    }
}

struct StackSync: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "sync") }

    @Option(name: .long) var id: String
    @Option(name: .long) var remote: String?

    func run() async throws {
        let ops = try StackOps(
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let (_, receiptPath) = try ops.stackSync(stackID: id, remoteOverride: remote)
        print(#"{"ok":true,"receipt":"\#(receiptPath)"}"#)
    }
}

struct StackLand: AsyncParsableCommand {
    static var configuration: CommandConfiguration { CommandConfiguration(commandName: "land") }

    @Option(name: .long) var id: String
    @Option(name: .long) var branch: String?
    @Option(name: .long) var strategy: String = "mergeNoFF"
    @Flag(name: .long) var cleanup: Bool = false
    @Flag(name: .long) var push: Bool = false

    func run() async throws {
        let ops = try StackOps(
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        let strat = StackOps.LandStrategy(rawValue: strategy) ?? .mergeNoFF
        let (mergeSHA, receiptPath) = try ops.stackLand(
            stackID: id, branch: branch, strategy: strat, cleanup: cleanup, remotePush: push)
        print(#"{"ok":true,"mergeSHA":"\#(mergeSHA)","receipt":"\#(receiptPath)"}"#)
    }
}
