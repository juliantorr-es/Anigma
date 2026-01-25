//
//  SelfHostProjectConfig.swift
//  HarmoniaModule
//
//  Configuration for the self-hosted Anigma project.
//  Provides a canonical project ID and helper for ensuring the project exists.
//

@preconcurrency import Foundation

/// Configuration for the self-hosted Anigma project.
public enum SelfHostProjectConfig {
    /// Default hardcoded UUID for the self-host project.
    /// Environment variable ANIGMA_SELF_HOST_PROJECT_ID can override this.
    private static var defaultId: UUID {
        guard let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else {
            fatalError("Failed to unwrap defaultId")
        }
        return id
    }

    /// The actual project ID to use (default or environment override).
    public static var projectId: UUID {
        if let override = ProcessInfo.processInfo.environment["ANIGMA_SELF_HOST_PROJECT_ID"],
           let uuid = UUID(uuidString: override) {
            return uuid
        }
        return defaultId
    }

    /// Name of the self-host project.
    public static let projectName = "anigma-core-selfhost"

    /// Default repository path (current working directory).
    public static var defaultRepoPath: String {
        FileManager.default.currentDirectoryPath
    }

    /// Feature categories for self-hosted work.
    /// These are used for scout and task categorization.
    public static let featureCategories = [
        "swift6-migration",
        "governance-hardening",
        "mlx-scouts",
        "provider-optimization",
        "tests-cleanup"
    ]

    /// Checks if the current directory looks like the Anigma repo.
    public static var isAnigmaRepo: Bool {
        let fileManager = FileManager.default
        let currentPath = defaultRepoPath

        // Check for Package.swift with Anigma product names
        let packagePath = (currentPath as NSString).appendingPathComponent("Package.swift")
        guard fileManager.fileExists(atPath: packagePath) else {
            return false
        }

        // Quick check for Anigma-specific content
        do {
            let packageContent = try String(contentsOfFile: packagePath, encoding: .utf8)
            return packageContent.contains("Anigma") ||
                   packageContent.contains("HarmoniaModule") ||
                   packageContent.contains("AnigmaCore")
        } catch {
            return false
        }
    }

    /// Ensures the self-host project is registered in the harness store.
    /// Returns the project spec if it exists or was created.
    public static func ensureRegistered() async throws -> ProjectSpec {
        let store = ProjectHarnessStore.shared

        // Ensure store is initialized before use
        do {
            print("Initializing store...")
            try await store.initialize()
            print("Store initialized successfully")
        } catch {
            print("Store initialization failed: \(error)")
            throw error
        }

        // Check if project already exists
        if let existing = try await store.loadProject(id: projectId.uuidString) {
            return existing
        }

        // Create new project spec
        let spec = ProjectSpec(
            id: projectId,
            name: projectName,
            specText: "Self-hosted Anigma project for evolving the Anigma codebase.",
            status: .uninitialized,
            projectDirectory: defaultRepoPath,
            gitRepositoryURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await store.saveProject(spec)
        return spec
    }

    /// Gets the principality controller for the self-host project.
    /// Ensures the project is registered first.
    public static func getPrincipality() async throws -> PrincipalityProjectController {
        _ = try await ensureRegistered()
        let provider = PrincipalityProvider.shared
        return await provider.controller(for: projectId)
    }
}
