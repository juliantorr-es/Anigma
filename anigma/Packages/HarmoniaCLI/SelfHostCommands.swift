//
//  SelfHostCommands.swift
//  HarmoniaCLI
//
//  CLI commands for self-hosted Anigma project management.
//

import ArgumentParser
import Foundation
import HarmoniaModule

public struct SelfHostInit: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "self-host-init",
            abstract: "Initialize the self-host Anigma project"
        )
    }

    public init() {}

    @Flag(name: .shortAndLong, help: "Force re-initialization even if project exists")
    var force: Bool = false

    public func run() async throws {
        print("🚀 Initializing self-host Anigma project...")

        do {
            let spec = try await SelfHostProjectConfig.ensureRegistered()
            print("✅ Self-host project registered:")
            print("   • Name: \(spec.name)")
            print("   • ID: \(spec.id.uuidString.prefix(8))...")
            print("   • Directory: \(spec.projectDirectory ?? "not set")")
            print(
                "   • Feature categories: \(SelfHostProjectConfig.featureCategories.joined(separator: ", "))"
            )

            // Get principality to ensure it's working
            let provider = PrincipalityProvider.shared
            let controller = try await provider.selfHostController()
            let status = try await controller.getStatus()

            print("\n📊 Project status:")
            print("   • Health rate: \(String(format: "%.1f%%", status.healthRate * 100))")
            print("   • Total sessions: \(status.totalSessions)")
            print("   • Healthy sessions: \(status.healthySessions)")
            print("   • Quarantined: \(status.isQuarantined ? "🚨 Yes" : "✅ No")")

            if SelfHostProjectConfig.isAnigmaRepo {
                print("\n🎯 You are in the Anigma repository.")
                print("   Run `harmonia self-host-status` to see governance board.")
                print("   Run `harmonia scout swift6` to scan for Swift 6 migration tasks.")
            } else {
                print("\n⚠️  You are not in the Anigma repository.")
                print("   Current directory: \(SelfHostProjectConfig.defaultRepoPath)")
                print("   This project will use the current directory as its workspace.")
            }

        } catch {
            print("❌ Failed to initialize self-host project: \(error)")
            throw error
        }
    }
}

public struct SelfHostStatus: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "self-host-status",
            abstract: "Show status and governance board for self-host project"
        )
    }

    public init() {}

    @Flag(name: .shortAndLong, help: "Show detailed governance report")
    var detailed: Bool = false

    public func run() async throws {
        print("🏛️  Self-Host Anigma Project Status")
        print("====================================\n")

        do {
            let provider = PrincipalityProvider.shared
            let controller = try await provider.selfHostController()

            // Get basic status
            let status = try await controller.getStatus()

            print("📋 Project Overview:")
            print("   • Name: \(status.name)")
            print("   • ID: \(status.projectId.uuidString.prefix(8))...")
            print("   • Health rate: \(String(format: "%.1f%%", status.healthRate * 100))")
            print("   • Sessions: \(status.healthySessions)/\(status.totalSessions) healthy")
            print("   • Unacknowledged issues: \(status.unacknowledgedIssueCount)")
            print("   • Quarantined: \(status.isQuarantined ? "🚨 Yes" : "✅ No")")

            if let reason = status.quarantineReason {
                print("   • Quarantine reason: \(reason)")
            }

            // Get governance status
            let governance = try await controller.getGovernanceStatus()

            print("\n👼 Governance Triage Board:")
            print("   • Recent sessions: \(governance.recentSessionCount)")
            print("   • Tainted sessions: \(governance.taintedCount)")
            print("   • Escalated sessions: \(governance.escalatedCount)")
            print("   • Policy denials: \(governance.policyDenials)")

            if !governance.trustTierBreakdown.isEmpty {
                print("\n   Trust Tier Breakdown:")
                for (tier, count) in governance.trustTierBreakdown.sorted(by: {
                    $0.key.hashValue < $1.key.hashValue
                }) {
                    let tierIcon = tier == .system ? "🔧" : tier == .trusted ? "✅" : "👿"
                    print("     • \(tierIcon) \(tier): \(count) sessions")
                }
            }

            if let lastDenial = governance.lastPolicyDenial {
                print("\n   Last policy denial: \(lastDenial)")
            }

            if let lastQuarantine = governance.lastQuarantineDecision {
                print("   Last quarantine: \(lastQuarantine)")
            }

            // Summary judgment
            print("\n📋 Summary:")
            if governance.isQuarantined {
                print("   🚨 PROJECT QUARANTINED - All execution blocked")
            } else if governance.taintedCount > governance.recentSessionCount / 2 {
                print("   ⚠️  HIGH TAINT RATE - Consider quarantine")
            } else if governance.policyDenials > 0 {
                print("   ⚠️  POLICY VIOLATIONS - Review trust tiers")
            } else {
                print("   ✅ Governance operational - Choir singing")
            }

            // Show directory info
            print("\n📁 Workspace:")
            let currentDir = SelfHostProjectConfig.defaultRepoPath
            print("   • Current directory: \(currentDir)")
            print("   • Is Anigma repo: \(SelfHostProjectConfig.isAnigmaRepo ? "✅ Yes" : "❌ No")")

            if detailed {
                print("\n" + governance.detailedReport)
            }

        } catch {
            print("❌ Failed to get self-host status: \(error)")
            throw error
        }
    }
}

// Register self-host commands
// Note: Configuration is defined in Main.swift and already includes
// SelfHostInit and SelfHostStatus subcommands
