//
//  LoopBreakerCommand.swift
//  AnigmaCLIExecutable
//
//  Demo command to test loop breaker functionality.
//

import AnigmaCLICore
import AnigmaCLIDatabase
import ArgumentParser
import Foundation

struct AnigmaLoopBreakerCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "loop-breaker",
            abstract: "Test and demonstrate loop breaker functionality.",
            subcommands: [
                LoopBreakerTestCommand.self,
                LoopBreakerConfigCommand.self
            ]
        )
    }
}

// MARK: - Test Command

struct LoopBreakerTestCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "test",
            abstract: "Run a test scenario to trigger loop breakers."
        )
    }

    @Option(name: .long, help: "Test scenario (max-steps|max-time|repeated-calls|no-novelty).")
    var scenario: String = "max-steps"

    @Flag(name: .long, help: "Show verbose output.")
    var verbose: Bool = false

    mutating func run() async throws {
        print("🧪 Loop Breaker Test: \(scenario)\n")

        let config: LoopBreakerConfig

        switch scenario {
        case "max-steps":
            config = LoopBreakerConfig(maxSteps: 5)
            try await testMaxSteps(config: config)

        case "max-time":
            config = LoopBreakerConfig(maxWallTimeSeconds: 2.0)
            try await testMaxTime(config: config)

        case "repeated-calls":
            config = LoopBreakerConfig(repeatedCallThreshold: 3)
            try await testRepeatedCalls(config: config)

        case "no-novelty":
            config = LoopBreakerConfig(noNoveltyWindow: 3)
            try await testNoNovelty(config: config)

        default:
            print("❌ Unknown scenario: \(scenario)")
            print("   Valid options: max-steps, max-time, repeated-calls, no-novelty")
            throw ExitCode.failure
        }
    }

    private func testMaxSteps(config: LoopBreakerConfig) async throws {
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        print("Testing max steps limit (\(config.maxSteps))...\n")

        for step in 1...10 {
            await loopBreaker.recordStep()

            if let result = await loopBreaker.shouldStop() {
                print("🛑 Loop breaker triggered at step \(step)!")
                print("   Reason: \(result.reason.rawValue)")
                print("   Message: \(result.message)")
                printCounters(result.counters)
                return
            }

            print("✅ Step \(step) passed")
        }

        print("\n⚠️  Test completed without triggering loop breaker")
    }

    private func testMaxTime(config: LoopBreakerConfig) async throws {
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        print("Testing max wall time limit (\(config.maxWallTimeSeconds)s)...\n")

        for iteration in 1...10 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            if let result = await loopBreaker.shouldStop() {
                print("🛑 Loop breaker triggered after \(Double(iteration) * 0.5)s!")
                print("   Reason: \(result.reason.rawValue)")
                print("   Message: \(result.message)")
                printCounters(result.counters)
                return
            }

            print("✅ \(Double(iteration) * 0.5)s elapsed")
        }

        print("\n⚠️  Test completed without triggering loop breaker")
    }

    private func testRepeatedCalls(config: LoopBreakerConfig) async throws {
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        print("Testing repeated calls detection (threshold: \(config.repeatedCallThreshold))...\n")

        for call in 1...10 {
            await loopBreaker.recordToolCall(toolName: "read_file", args: "/path/to/same/file.txt")

            if let result = await loopBreaker.shouldStop() {
                print("🛑 Loop breaker triggered at call \(call)!")
                print("   Reason: \(result.reason.rawValue)")
                print("   Message: \(result.message)")
                printCounters(result.counters)
                return
            }

            print("✅ Call \(call): read_file /path/to/same/file.txt")
        }

        print("\n⚠️  Test completed without triggering loop breaker")
    }

    private func testNoNovelty(config: LoopBreakerConfig) async throws {
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        print("Testing no-novelty detection (window: \(config.noNoveltyWindow))...\n")

        // First, record some initial steps without novelty
        for step in 1...5 {
            await loopBreaker.recordStep()

            if let result = await loopBreaker.shouldStop() {
                print("🛑 Loop breaker triggered at step \(step)!")
                print("   Reason: \(result.reason.rawValue)")
                print("   Message: \(result.message)")
                printCounters(result.counters)
                return
            }

            print("✅ Step \(step) (no novelty recorded)")
        }

        print("\n⚠️  Test completed without triggering loop breaker")
    }

    private func printCounters(_ counters: LoopBreakerCounters) {
        print("\n📊 Final Counters:")
        print("   Steps:      \(counters.steps)")
        print("   Tool Calls: \(counters.toolCalls)")
        print("   Tokens:     \(counters.tokens)")
        print("   Spend:      $\(String(format: "%.2f", counters.spend))")
        print("   Wall Time:  \(String(format: "%.1f", counters.wallTimeSeconds))s")
        if let lastAction = counters.lastAction {
            print("   Last Action: \(lastAction)")
        }
    }
}

// MARK: - Config Command

struct LoopBreakerConfigCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "config",
            abstract: "Show loop breaker configuration."
        )
    }

    mutating func run() async throws {
        let config = LoopBreakerConfig.default

        print("🔧 Loop Breaker Configuration (Default):\n")
        print("Max Steps:              \(config.maxSteps)")
        print("Max Tool Calls:         \(config.maxToolCalls)")
        print("Max Wall Time:          \(Int(config.maxWallTimeSeconds))s (\(Int(config.maxWallTimeSeconds / 60))m)")

        if let maxTokens = config.maxTokens {
            print("Max Tokens:             \(maxTokens)")
        } else {
            print("Max Tokens:             unlimited")
        }

        if let maxSpend = config.maxSpend {
            print("Max Spend:              $\(String(format: "%.2f", maxSpend))")
        } else {
            print("Max Spend:              unlimited")
        }

        print("Repeated Call Threshold: \(config.repeatedCallThreshold)")
        print("No-Novelty Window:      \(config.noNoveltyWindow) steps")
    }
}
