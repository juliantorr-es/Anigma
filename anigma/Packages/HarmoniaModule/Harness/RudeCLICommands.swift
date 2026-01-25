//
//  RudeCLICommands.swift
//  HarmoniaModule
//
//  CLI commands that bully you into looking at metrics.
//  No more ignoring the data.
//  Phase A: Updated to use PrincipalityProjectController instead of direct GRDB/bandit access.
//

@preconcurrency import Foundation
@preconcurrency import GRDB

// MARK: - Rude CLI Commands

/// CLI commands that aggressively surface behavioral issues.
/// Phase A: Now uses PrincipalityProjectController as the single entry point.
public struct RudeCLICommands: Sendable {
    private let store: ProjectHarnessStore
    private let inspector: ToolUsageInspector
    private let reportGenerator: SessionReportGenerator
    private let principalityProvider: PrincipalityProvider

    public init(
        store: ProjectHarnessStore = .shared,
        inspector: ToolUsageInspector = ToolUsageInspector(),
        reportGenerator: SessionReportGenerator = SessionReportGenerator(),
        principalityProvider: PrincipalityProvider = .shared
    ) {
        self.store = store
        self.inspector = inspector
        self.reportGenerator = reportGenerator
        self.principalityProvider = principalityProvider
    }

    /// Gets a principality controller for a project.
    private func principality(for projectId: UUID) async -> PrincipalityProjectController {
        return await principalityProvider.controller(for: projectId)
    }

    // MARK: - Public Commands

    /// Runs the "bully" command - aggressively surfaces issues.
    public func bully(projectId: UUID? = nil) async throws -> String {
        var output = "🔨 BEHAVIORAL BULLY MODE ACTIVATED 🔨\n\n"

        if let projectId = projectId {
            output += try await bullyProject(projectId: projectId)
        } else {
            output += try await bullyAllProjects()
        }

        output += "\n\n💀 STOP IGNORING THE DATA 💀\n"
        return output
    }

    /// Shows the worst session with brutal honesty.
    public func showWorstSession(projectId: UUID) async throws -> String {
        let principality = await principality(for: projectId)
        return try await principality.getWorstSession()
    }

    /// Checks for unacknowledged unhealthy sessions.
    public func checkUnacknowledged(projectId: UUID? = nil) async throws -> String {
        var output = "🔍 UNACKNOWLEDGED SESSIONS CHECK 🔍\n\n"

        if let projectId = projectId {
            let principality = await principality(for: projectId)
            return try await principality.checkUnacknowledged()
        } else {
            // Check all projects
            // For now, just show message
            output += "Specify a project ID to check for unacknowledged sessions.\n"
            output += "Example: `harmonia check-unacknowledged --project <project-id>`\n"
            return output
        }
    }

    /// Shows critical violations that need immediate attention.
    public func showCriticalViolations(projectId: UUID) async throws -> String {
        let principality = await principality(for: projectId)
        return try await principality.getCriticalViolations()
    }

    /// Compares two sessions brutally.
    public func compareBrutally(
        projectId: UUID,
        sessionIndex1: Int,
        sessionIndex2: Int
    ) async throws -> String {
        let principality = await principality(for: projectId)
        return try await principality.compareSessionsBrutally(
            sessionIndex1: sessionIndex1,
            sessionIndex2: sessionIndex2
        )
    }

    /// Generates a "report card" with grades.
    public func generateReportCard(projectId: UUID) async throws -> String {
        let principality = await principality(for: projectId)
        return try await principality.getReportCard()
    }

    /// Forces you to look at the last session's report.
    public func forceReadLastReport(projectId: UUID) async throws -> String {
        let principality = await principality(for: projectId)
        return try await principality.forceReadLastReport()
    }

    /// Shows bandit learning report.
    public func showBanditReport(projectId: UUID? = nil) async throws -> String {
        var output = "🎰 BANDIT LEARNING REPORT 🎰\n\n"

        if let projectId = projectId {
            let principality = await principality(for: projectId)
            let report = try await principality.getBanditReport()
            output += report
        } else {
            output += "Specify a project ID to see bandit report.\n"
            output += "Example: `harmonia bandit-report --project <project-id>`\n"
        }

        return output
    }

    /// Shows configs that should be deprecated based on performance.
    public func showDeprecationRecommendations(projectId: UUID) async throws -> String {
        let principality = await principality(for: projectId)
        let recommendations = try await principality.getDeprecationRecommendations()

        var output = "📉 CONFIG DEPRECATION RECOMMENDATIONS 📉\n\n"

        if recommendations.isEmpty {
            output += "✅ No configs need deprecation based on current performance data.\n"
            output += "All blessed configs are performing adequately.\n"
        } else {
            output += "Found \(recommendations.count) recommendations:\n\n"
            for (index, recommendation) in recommendations.enumerated() {
                output += "\(index + 1). \(recommendation)\n"
            }
            output += "\n💡 RECOMMENDATION: Review these configs and consider:\n"
            output += "1. Removing them from the blessed config registry\n"
            output +=
                "2. Adjusting their parameters if they're conceptually sound but misconfigured\n"
            output += "3. Adding stricter constraints if they're causing issues\n"
        }

        return output
    }

    // MARK: - Private Methods

    private func bullyProject(projectId: UUID) async throws -> String {
        let principality = await principality(for: projectId)
        return try await principality.bully()
    }

    private func bullyAllProjects() async throws -> String {
        // Get all projects through the store (this is a CLI helper, acceptable side door)
        let projects = try await store.listProjectSpecs()

        var output = "BULLYING ALL \(projects.count) PROJECTS\n\n"

        for project in projects {
            do {
                let principality = await principality(for: project.id)
                output += try await principality.bully()
                output += "\n" + String(repeating: "-", count: 50) + "\n\n"
            } catch {
                output +=
                    "Failed to bully project \(project.id.uuidString.prefix(8))...: \(error)\n\n"
            }
        }

        return output
    }

    private func calculateGrade(score: Double) -> String {
        switch score {
        case 0.9...1.0: return "A"
        case 0.8..<0.9: return "B"
        case 0.7..<0.8: return "C"
        case 0.6..<0.7: return "D"
        default: return "F"
        }
    }
}

// MARK: - CLI Integration

extension RudeCLICommands {
    /// Registers rude CLI commands with a command registry.
    public static func registerCommands() {
        // This would integrate with your CLI framework
        // For example:
        // CommandRegistry.shared.register(command: "bully", description: "Aggressively surface behavioral issues") { args in
        //     let rudeCLI = RudeCLICommands()
        //     let projectId = args.get("--project").flatMap { UUID(uuidString: $0) }
        //     let output = try await rudeCLI.bully(projectId: projectId)
        //     print(output)
        // }
        //
        // CommandRegistry.shared.register(command: "bandit-report", description: "Show bandit learning report") { args in
        //     let rudeCLI = RudeCLICommands()
        //     let projectId = args.get("--project").flatMap { UUID(uuidString: $0) }
        //     let output = try await rudeCLI.showBanditReport(projectId: projectId)
        //     print(output)
        // }
    }

    /// Returns help text for all rude CLI commands.
    public static func helpText() -> String {
        return """
            Rude CLI Commands - No more ignoring the data

            Available commands:
            1. `bully --project <id>` - Aggressively surface behavioral issues
            2. `worst-session --project <id>` - Show the worst session with brutal honesty
            3. `check-unacknowledged --project <id>` - Check for unacknowledged unhealthy sessions
            4. `critical-violations --project <id>` - Show critical violations that need fixing
            5. `compare --project <id> --session1 <n> --session2 <m>` - Compare two sessions brutally
            6. `report-card --project <id>` - Generate a report card with grades
            7. `force-read-last --project <id>` - Force reading of last session's report
            8. `bandit-report --project <id>` - Show bandit learning report
            9. `deprecation-recommendations --project <id>` - Show configs that should be deprecated

            Usage example:
            $ harmonia bully --project \(UUID().uuidString.prefix(8))...
            $ harmonia bandit-report --project \(UUID().uuidString.prefix(8))...
            """
    }
}
