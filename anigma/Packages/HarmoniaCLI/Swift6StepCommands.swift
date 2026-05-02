//
//  Swift6StepCommands.swift
//  HarmoniaCLI
//
//  CLI commands for Swift 6 migration steps.
//

import ArgumentParser
import Foundation
import HarmoniaModule
import HarmoniaV2Surface

/// Root Swift 6 command surface (tests + migration steps).
public struct Swift6: ParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "swift6",
            abstract: "Swift 6 test runner and migration step commands",
            subcommands: [
                Swift6Test.self,
                Swift6StepRun.self,
                Swift6StepState.self
            ],
            defaultSubcommand: Swift6Test.self
        )
    }

    public init() {}
}

/// Runs the Swift test suite (legacy default behavior).
public struct Swift6Test: ParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "test",
            abstract: "Run Swift tests with optional filtering",
            discussion: "This matches the legacy `harmonia swift6 --filter <pattern>` invocation."
        )
    }

    @OptionGroup var output: OutputOptions
    @Flag(name: .long, help: "Run test mode (legacy compatibility flag).")
    var test: Bool = true

    @Option(name: .long, help: "Optional test filter.")
    var filter: String?

    @Flag(name: .long, help: "Enable code coverage.")
    var enableCodeCoverage: Bool = false

    public init() {}

    public func run() throws {
        var args = ["test", "--disable-sandbox"]
        if let filter = filter, !filter.isEmpty {
            args.append(contentsOf: ["--filter", filter])
        }
        if enableCodeCoverage {
            args.append("--enable-code-coverage")
        }

        let repoRoot = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let cacheRoot = repoRoot.appendingPathComponent(".cache", isDirectory: true)
        let clangCache = cacheRoot.appendingPathComponent("clang", isDirectory: true)
        let swiftpmCache = cacheRoot.appendingPathComponent("swiftpm", isDirectory: true)
        try? FileManager.default.createDirectory(at: clangCache, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(
            at: swiftpmCache, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift"] + args
        var environment = ProcessInfo.processInfo.environment
        environment["CLANG_MODULE_CACHE_PATH"] = clangCache.path
        environment["SWIFTPM_DIRECTORY"] = swiftpmCache.path
        environment["SWIFTPM_ENABLE_SANDBOX"] = "0"
        process.environment = environment
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExitCode.failure
        }
    }
}

/// Command group for game project steps.
public struct GameStep: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "game",
            abstract: "Game project step commands",
            subcommands: [
                GameStepRun.self,
                GameStepState.self
            ]
        )
    }

    public init() {}
}

/// Runs one or more Swift 6 migration steps.
public struct Swift6StepRun: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "step",
            abstract: "Run Swift 6 migration steps"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Option(name: .shortAndLong, help: "Number of steps to run (default: 1)")
    var count: Int = 1

    @Flag(name: .shortAndLong, help: "Show detailed output")
    var verbose: Bool = false

    public init() {}

    public func run() async throws {
        print("🧠 Running Swift 6 migration steps...")
        print("====================================\n")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                print("❌ Invalid project ID format")
                return
            }
            projectUUID = uuid
        } else {
            // Use self-host project
            let spec = try await SelfHostProjectConfig.ensureRegistered()
            projectUUID = spec.id
            print("📦 Using self-host project: \(spec.name) (\(spec.id.uuidString.prefix(8))...)")
        }

        // Get principality controller
        let provider = PrincipalityProvider.shared
        let controller = await provider.controller(for: projectUUID)

        // Run steps
        print("\n🏃 Running \(count) step(s)...")
        let results = try await controller.runSwift6Steps(count: count)

        // Print results
        print("\n📊 Step Results:")
        print("================")

        for (index, (intent, report)) in results.enumerated() {
            print("\nStep \(index + 1): \(intent.description)")

            switch intent {
            case .runTask:
                if let report = report {
                    print("   ✅ Session executed:")
                    print("      • Index: \(report.sessionIndex)")
                    print("      • Health: \(String(format: "%.2f", report.healthScore))")
                    print("      • Verdict: \(report.verdict)")
                    print("      • Duration: N/A")

                    if verbose {
                        // Governance trace display not available
                    }
                }

            case .rescoutFile(let path):
                print("   🔍 File rescouted: \(path)")
                print("      • New findings will be available in next state load")

            case .pause(let reason):
                print("   ⏸️  Migration paused:")
                print("      • Reason: \(reason)")
            }
        }

        // Summary
        print("\n🎯 Summary:")
        print("===========")
        let runTasks = results.filter {
            if case .runTask = $0.0 { return true } else { return false }
        }.count
        let rescouts = results.filter {
            if case .rescoutFile = $0.0 { return true } else { return false }
        }.count
        let pauses = results.filter { if case .pause = $0.0 { return true } else { return false } }
            .count

        print("• Tasks run: \(runTasks)")
        print("• Files rescouted: \(rescouts)")
        print("• Pauses: \(pauses)")

        if pauses > 0 && runTasks == 0 {
            print("\n💡 Tip: Migration may be stuck. Consider:")
            print("   • Running 'harmonia swift6 state' to see current state")
            print("   • Adjusting migration policy if avoiding tainted areas")
            print("   • Running 'harmonia scout swift6' to refresh findings")
        }
    }
}

/// Shows current Swift 6 migration state.
public struct Swift6StepState: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "state",
            abstract: "Show current Swift 6 migration state"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Flag(name: .shortAndLong, help: "Show detailed file information")
    var detailed: Bool = false

    public init() {}

    public func run() async throws {
        print("📊 Swift 6 Migration State")
        print("=========================\n")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                print("❌ Invalid project ID format")
                return
            }
            projectUUID = uuid
        } else {
            // Use self-host project
            let spec = try await SelfHostProjectConfig.ensureRegistered()
            projectUUID = spec.id
            print("📦 Project: \(spec.name) (\(spec.id.uuidString.prefix(8))...)\n")
        }

        // Get principality controller
        let provider = PrincipalityProvider.shared
        let controller = await provider.controller(for: projectUUID)

        // Load state
        let state = try await controller.loadSwift6MigrationState()

        // Print overview
        print("📈 Overview:")
        print("------------")
        print("• Total findings: \(state.totalFindings)")
        print("• Total tasks: \(state.totalTasks)")
        print("• Open tasks: \(state.openTasks)")
        print("• Tainted sessions: \(state.taintedSessions)")
        print("• Overall health: \(String(format: "%.2f", state.overallHealthScore))")
        print("• Migration complete: \(state.isComplete ? "✅" : "⏳")")

        // Print recent sessions
        if !state.recentSessions.isEmpty {
            print("\n🕐 Recent Sessions (\(state.recentSessions.count)):")
            print("-------------------")
            for session in state.recentSessions.prefix(5) {
                let taintIcon = session.tainted ? "⚠️" : "✅"
                print(
                    "• Session \(session.sessionIndex): \(String(format: "%.2f", session.healthScore)) \(taintIcon)"
                )
            }
            if state.recentSessions.count > 5 {
                print("  ... and \(state.recentSessions.count - 5) more")
            }
        }

        // Print files with pending work
        let filesWithWork = state.filesWithPendingWork
        if !filesWithWork.isEmpty {
            print("\n📝 Files with Pending Work (\(filesWithWork.count)):")
            print("---------------------------")
            for file in filesWithWork.prefix(detailed ? 20 : 5) {
                print("• \(file.path):")
                print("  - Findings: \(file.findingsCount)")
                print("  - Open tasks: \(file.openTaskCount)")
                print("  - Highest severity: \(file.highestSeverity)")
                if file.hasRecentTaintedSessions {
                    print("  - ⚠️ Has recent tainted sessions")
                }

                if detailed {
                    for task in file.pendingTasks.prefix(3) {
                        print("  - Task: \(task.id.uuidString.prefix(8)) (\(task.status))")
                    }
                    if file.pendingTasks.count > 3 {
                        print(
                            "  - ... and \(file.pendingTasks.count - 3) more tasks"
                        )
                    }
                }
            }

            if !detailed && filesWithWork.count > 5 {
                print("  ... and \(filesWithWork.count - 5) more files")
            }
        } else {
            print("\n✅ No files with pending work")
        }

        // Print files with tainted sessions
        let taintedFiles = state.filesWithRecentTaintedSessions
        if !taintedFiles.isEmpty {
            print("\n⚠️  Files with Recent Tainted Sessions (\(taintedFiles.count)):")
            print("----------------------------------------")
            for file in taintedFiles.prefix(5) {
                print("• \(file.path)")
                if let lastSessionIndex = file.lastSessionIndex,
                   let lastSessionHealthScore = file.lastSessionHealthScore {
                    print(
                        "  - Last session: \(lastSessionIndex) (\(String(format: "%.2f", lastSessionHealthScore)))"
                    )
                }
            }
            if taintedFiles.count > 5 {
                print("  ... and \(taintedFiles.count - 5) more")
            }
        }

        // Print recommendations
        print("\n💡 Recommendations:")
        print("------------------")
        if state.isComplete {
            print("• Migration complete! 🎉")
            print("• Consider running final validation")
        } else if filesWithWork.isEmpty {
            print("• No pending work found")
            print("• Run 'harmonia scout swift6' to refresh findings")
            print("• Or run 'harmonia swift6 step' to let engine decide next move")
        } else if state.hasRecentTaintedFiles {
            print("• Some files have recent tainted sessions")
            print("• Engine will avoid these if 'avoidTaintedAreas' policy is enabled")
            print("• Consider reviewing tainted sessions manually")
        } else {
            print("• Ready for migration steps")
            print("• Run 'harmonia swift6 step' to execute next step")
            print("• Or 'harmonia swift6 step --count 5' for multiple steps")
        }

        if detailed {
            print("\n🔧 Engine would choose from:")
            print("---------------------------")
            let intent = try await controller.previewSwift6Step(policy: .default)
            print("• Next intent: \(intent.description)")
        }
    }
}

// MARK: - Game Step Commands

/// Runs one or more game project steps.
public struct GameStepRun: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "step",
            abstract: "Run game project steps"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Option(name: .shortAndLong, help: "Number of steps to run (default: 1)")
    var count: Int = 1

    @Flag(name: .shortAndLong, help: "Show detailed output")
    var verbose: Bool = false

    public init() {}

    public func run() async throws {
        print("🎮 Running game project steps...")
        print("===============================\n")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                print("❌ Invalid project ID format")
                return
            }
            projectUUID = uuid
        } else {
            // Use self-host project
            let spec = try await SelfHostProjectConfig.ensureRegistered()
            projectUUID = spec.id
            print("📦 Project: \(spec.name) (\(spec.id.uuidString.prefix(8))...)\n")
        }

        // Get principality controller
        let provider = PrincipalityProvider.shared
        let controller = await provider.controller(for: projectUUID)

        // Run steps
        let results = try await controller.runGameSteps(count: count)

        // Print results
        print("📋 Step Results:")
        print("---------------")

        for (index, (intent, report)) in results.enumerated() {
            print("\nStep \(index + 1): \(intent.description)")

            if verbose {
                print("  Intent: \(intent)")

                if let report = report {
                    print("  Session: \(report.sessionIndex)")
                    print("  Health: \(String(format: "%.2f", report.healthScore))")
                    print("  Verdict: \(report.verdict)")

                    if let trace = report.governanceTrace {
                        print("  Governance trace: \(trace)")
                    }
                } else {
                    print("  No session report (pause or resimulation)")
                }
            }
        }

        // Summary
        print("\n📊 Summary:")
        print("----------")
        print("• Steps run: \(results.count)")

        let sessionCount = results.filter { $0.1 != nil }.count
        print("• Sessions created: \(sessionCount)")

        let pauseCount = results.filter {
            if case .pause = $0.0 { return true }
            return false
        }.count
        if pauseCount > 0 {
            print("• Pauses: \(pauseCount)")
        }

        let resimulationCount = results.filter {
            if case .resimulateScene = $0.0 { return true }
            return false
        }.count
        if resimulationCount > 0 {
            print("• Resimulations: \(resimulationCount)")
        }

        // Check if we stopped early due to pause
        if results.count < count {
            if let lastIntent = results.last?.0 {
                if case .pause(let reason) = lastIntent {
                    print("\n⏸️  Stopped early due to pause: \(reason)")
                }
            }
        }
    }
}

/// Shows the current game project state.
public struct GameStepState: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "state",
            abstract: "Show current game project state"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID (defaults to self-host project)")
    var projectId: String?

    @Flag(name: .shortAndLong, help: "Show detailed scene information")
    var detailed: Bool = false

    public init() {}

    public func run() async throws {
        print("📊 Game Project State")
        print("====================\n")

        // Get project ID (default to self-host project)
        let projectUUID: UUID
        if let projectId = projectId {
            guard let uuid = UUID(uuidString: projectId) else {
                print("❌ Invalid project ID format")
                return
            }
            projectUUID = uuid
        } else {
            // Use self-host project
            let spec = try await SelfHostProjectConfig.ensureRegistered()
            projectUUID = spec.id
            print("📦 Project: \(spec.name) (\(spec.id.uuidString.prefix(8))...)\n")
        }

        // Get principality controller
        let provider = PrincipalityProvider.shared
        let controller = await provider.controller(for: projectUUID)

        // Load state
        let state = try await controller.loadGameProjectState()

        // Print overview
        print("📈 Overview:")
        print("------------")
        print("• Total scenes: \(state.totalScenes)")
        print("• Total tests: \(state.totalTests)")
        print("• Total tasks: \(state.totalTasks)")
        print("• Open tasks: \(state.openTasks)")
        print("• Failing tests: \(state.failingTests)")
        print("• Broken scenes: \(state.brokenScenes)")
        print("• Tainted sessions: \(state.taintedSessions)")
        print("• Overall health: \(String(format: "%.2f", state.overallHealthScore))")
        print("• Project healthy: \(state.isHealthy ? "✅" : "⚠️")")
        print("• Project complete: \(state.isComplete ? "✅" : "⏳")")

        // Print recent playtests
        if !state.recentPlaytests.isEmpty {
            print("\n🕐 Recent Playtests (\(state.recentPlaytests.count)):")
            print("-------------------")
            for playtest in state.recentPlaytests.prefix(5) {
                let taintIcon = playtest.tainted ? "⚠️" : "✅"
                let sceneInfo = playtest.sceneId.map { " (scene: \($0.prefix(8))...)" } ?? ""
                print(
                    "• Session \(playtest.sessionIndex): \(String(format: "%.2f", playtest.healthScore)) \(taintIcon)\(sceneInfo)"
                )
            }
            if state.recentPlaytests.count > 5 {
                print("  ... and \(state.recentPlaytests.count - 5) more")
            }
        }

        // Print scenes with pending work
        let scenesWithWork = state.scenesWithPendingWork
        if !scenesWithWork.isEmpty {
            print("\n🎬 Scenes with Pending Work (\(scenesWithWork.count)):")
            print("---------------------------")
            for scene in scenesWithWork.prefix(detailed ? 20 : 5) {
                print("• \(scene.name) (\(scene.id)):")
                print("  - Tests: \(scene.testCount) total, \(scene.failingTestCount) failing")
                print("  - Open tasks: \(scene.openTaskCount)")
                print(
                    "  - Status: \(scene.isBroken ? "🔴 Broken" : scene.failingTestCount > 0 ? "🟡 Failing tests" : "🟢 OK")"
                )
                if scene.hasRecentTaintedSessions {
                    print("  - ⚠️ Has recent tainted sessions")
                }

                if detailed {
                    for test in scene.failedTests.prefix(3) {
                        print("  - Test: \(test.name) (\(test.status))")
                    }
                    for task in scene.pendingTasks.prefix(3) {
                        print("  - Task: \(task.title) (\(task.status))")
                    }
                    if scene.pendingTasks.count > 3 {
                        print(
                            "  - ... and \(scene.pendingTasks.count - 3) more tasks"
                        )
                    }
                }
            }

            if !detailed && scenesWithWork.count > 5 {
                print("  ... and \(scenesWithWork.count - 5) more scenes")
            }
        } else {
            print("\n✅ No scenes with pending work")
        }

        // Print scenes with tainted sessions
        let taintedScenes = state.scenesWithRecentTaintedSessions
        if !taintedScenes.isEmpty {
            print("\n⚠️  Scenes with Recent Tainted Sessions (\(taintedScenes.count)):")
            print("----------------------------------------")
            for scene in taintedScenes.prefix(5) {
                print("• \(scene.name) (\(scene.id))")
                if let lastSessionIndex = scene.lastPlaytestSessionIndex,
                   let lastSessionHealthScore = scene.lastPlaytestHealthScore {
                    print(
                        "  - Last playtest: session \(lastSessionIndex) (\(String(format: "%.2f", lastSessionHealthScore)))"
                    )
                }
            }
            if taintedScenes.count > 5 {
                print("  ... and \(taintedScenes.count - 5) more")
            }
        }

        // Print broken scenes
        let brokenScenes = state.brokenSceneSummaries
        if !brokenScenes.isEmpty {
            print("\n🔴 Broken Scenes (\(brokenScenes.count)):")
            print("-------------------")
            for scene in brokenScenes.prefix(5) {
                print("• \(scene.name) (\(scene.id))")
                print("  - Failing tests: \(scene.failingTestCount)")
                print("  - Open tasks: \(scene.openTaskCount)")
            }
            if brokenScenes.count > 5 {
                print("  ... and \(brokenScenes.count - 5) more")
            }
        }

        // Print recommendations
        print("\n💡 Recommendations:")
        print("------------------")
        if state.isComplete {
            print("• Project complete! 🎉")
            print("• Consider running final validation playtest")
        } else if scenesWithWork.isEmpty {
            print("• No pending work found")
            print("• Run game simulation to generate new tests")
            print("• Or run 'harmonia game step' to let engine decide next move")
        } else if state.hasRecentTaintedScenes {
            print("• Some scenes have recent tainted sessions")
            print("• Engine will avoid these if 'avoidTaintedAreas' policy is enabled")
            print("• Consider reviewing tainted playtests manually")
        } else if !brokenScenes.isEmpty {
            print("• Some scenes are broken (failing tests)")
            print(
                "• Engine will prioritize broken scenes if 'preferBrokenScenes' policy is enabled")
            print("• Focus on fixing broken scenes first")
        } else {
            print("• Ready for game project steps")
            print("• Run 'harmonia game step' to execute next step")
            print("• Or 'harmonia game step --count 5' for multiple steps")
        }

        if detailed {
            print("\n🔧 Engine would choose from:")
            print("---------------------------")
            let intent = try await controller.previewGameStep(policy: .default)
            print("• Next intent: \(intent.description)")
        }
    }
}
