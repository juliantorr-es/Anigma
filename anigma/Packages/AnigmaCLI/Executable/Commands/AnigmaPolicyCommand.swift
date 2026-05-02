import ArgumentParser
import Foundation
import AnigmaCLIDatabase

/// Policy management commands for anigma-cli.
struct AnigmaPolicyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "policy",
        abstract: "Manage security policies and trust levels",
        subcommands: [
            ListCommand.self,
            AllowPathCommand.self,
            DenyPathCommand.self,
            AllowCommandCommand.self,
            DenyCommandCommand.self,
            SetTrustCommand.self,
            CheckCommand.self,
            ResetCommand.self
        ]
    )

    // MARK: - List Policies

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List current policy configuration"
        )

        func run() async throws {
            let config = CLIDatabaseConfig.default
            let policyEngine = CLIPolicyEngine(dbPath: config.path)

            print("📋 Policy Configuration")
            print("")
            print("Default Action: require_approval")
            print("")

            // Load and display rules
            let rules = await policyEngine.listRules()
            if rules.isEmpty {
                print("No custom rules defined")
            } else {
                print("Rules:")
                for rule in rules {
                    print("  [\(rule.priority)] \(rule.name) - \(rule.action)")
                }
            }
        }
    }

    // MARK: - Path Management

    struct AllowPathCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "allow-path",
            abstract: "Add a path to the allowlist"
        )

        @Argument(help: "Path to allow")
        var path: String

        func run() async throws {
            let config = CLIDatabaseConfig.default
            let policyEngine = CLIPolicyEngine(dbPath: config.path)

            await policyEngine.addAllowedPath(path)
            try await policyEngine.saveConfig()

            print("✅ Path added to allowlist: \(path)")
        }
    }

    struct DenyPathCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "deny-path",
            abstract: "Add a path to the denylist"
        )

        @Argument(help: "Path to deny")
        var path: String

        func run() async throws {
            let config = CLIDatabaseConfig.default
            let policyEngine = CLIPolicyEngine(dbPath: config.path)

            await policyEngine.addDeniedPath(path)
            try await policyEngine.saveConfig()

            print("✅ Path added to denylist: \(path)")
        }
    }

    // MARK: - Command Management

    struct AllowCommandCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "allow-command",
            abstract: "Add a command to the allowlist"
        )

        @Argument(help: "Command name to allow")
        var command: String

        func run() async throws {
            let config = CLIDatabaseConfig.default
            let policyEngine = CLIPolicyEngine(dbPath: config.path)

            await policyEngine.addAllowedCommand(command)
            try await policyEngine.saveConfig()

            print("✅ Command added to allowlist: \(command)")
        }
    }

    struct DenyCommandCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "deny-command",
            abstract: "Add a command to the denylist"
        )

        @Argument(help: "Command to deny")
        var command: String

        func run() async throws {
            let config = CLIDatabaseConfig.default
            let policyEngine = CLIPolicyEngine(dbPath: config.path)

            await policyEngine.addDeniedCommand(command)
            try await policyEngine.saveConfig()

            print("✅ Command added to denylist: \(command)")
        }
    }

    // MARK: - Trust Management

    struct SetTrustCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "trust",
            abstract: "Set trust level for an MCP server"
        )

        @Argument(help: "Server name")
        var server: String

        @Option(help: "Trust level (untrusted, read_only, restricted, trusted)")
        var level: String

        func run() async throws {
            let config = CLIDatabaseConfig.default
            let mcpTrust = CLIMCPTrustModel(dbPath: config.path)

            guard let trustLevel = parseTrustLevel(level) else {
                print("❌ Invalid trust level: \(level)")
                print("   Valid levels: untrusted, read_only, restricted, trusted")
                throw ExitCode.failure
            }

            await mcpTrust.setTrustLevel(
                server: server,
                level: trustLevel,
                grantedBy: "cli"
            )

            print("✅ Trust level set: \(server) -> \(level)")
        }

        private func parseTrustLevel(_ level: String) -> CLIMCPTrustModel.TrustLevel.Level? {
            switch level.lowercased() {
            case "untrusted": return .untrusted
            case "read_only", "readonly": return .read_only
            case "restricted": return .restricted
            case "trusted": return .trusted
            default: return nil
            }
        }
    }

    // MARK: - Policy Check

    struct CheckCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "check",
            abstract: "Check if an operation is allowed by policy"
        )

        @Option(help: "Operation type (read, write, delete, shell, git)")
        var operation: String

        @Argument(help: "Target (path or command)")
        var target: String

        func run() async throws {
            let config = CLIDatabaseConfig.default
            let policyEngine = CLIPolicyEngine(dbPath: config.path)

            let decision: CLIPolicyEngine.PolicyDecision

            switch operation.lowercased() {
            case "read":
                decision = await policyEngine.evaluateFileRead(path: target)
            case "write":
                decision = await policyEngine.evaluateFileWrite(path: target, size: 0)
            case "delete":
                decision = await policyEngine.evaluateFileDelete(path: target)
            case "shell":
                decision = await policyEngine.evaluateShellCommand(command: target)
            case "git":
                decision = await policyEngine.evaluateGitOperation(operation: target, path: ".")
            default:
                print("❌ Unknown operation: \(operation)")
                throw ExitCode.failure
            }

            switch decision {
            case .allow:
                print("✅ ALLOWED: \(operation) \(target)")
            case .deny(let reason):
                print("❌ DENIED: \(reason)")
            case .requireApproval(let op):
                print("⚠️  REQUIRES APPROVAL: \(op)")
            }
        }
    }

    // MARK: - Reset

    struct ResetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reset",
            abstract: "Reset policy configuration to defaults"
        )

        @Flag(help: "Confirm reset")
        var confirm: Bool = false

        func run() async throws {
            if !confirm {
                print("⚠️  This will reset all policy configuration to defaults")
                print("   Run with --confirm to proceed")
                throw ExitCode.failure
            }

            let config = CLIDatabaseConfig.default
            let policyEngine = CLIPolicyEngine(dbPath: config.path)

            await policyEngine.clearApprovalCache()
            try await policyEngine.saveConfig()

            print("✅ Policy configuration reset to defaults")
        }
    }
}
