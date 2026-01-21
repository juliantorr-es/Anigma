//
//  PrincipalityProvider+SelfHost.swift
//  HarmoniaModule
//
//  Self-host convenience extensions for PrincipalityProvider.
//

import Foundation

extension PrincipalityProvider {
    /// Gets the principality controller for the self-host project.
    /// Ensures the project is registered first.
    public func selfHostController() async throws -> PrincipalityProjectController {
        _ = try await SelfHostProjectConfig.ensureRegistered()
        return controller(for: SelfHostProjectConfig.projectId)
    }

    /// Convenience method to get self-host controller with default dependencies.
    public func selfHostController() -> PrincipalityProjectController {
        // This is a synchronous version that assumes the project is already registered
        // or will be registered on first use through the controller
        return controller(for: SelfHostProjectConfig.projectId)
    }

    /// Checks if a given project ID is the self-host project.
    public func isSelfHostProject(_ projectId: UUID) -> Bool {
        return projectId == SelfHostProjectConfig.projectId
    }

    /// Gets the self-host project spec if it exists.
    public func getSelfHostProject() async throws -> ProjectSpec? {
        let store = ProjectHarnessStore.shared
        return try await store.loadProject(id: SelfHostProjectConfig.projectId.uuidString)
    }

    /// CLI helper to resolve project ID, defaulting to self-host if in Anigma repo.
    public func resolveProjectIdWithSelfHostDefault(
        projectId: UUID? = nil,
        projectName: String? = nil,
        interactive: Bool = false
    ) async throws -> UUID {
        // 1. Use explicit ID if provided
        if let projectId = projectId {
            return projectId
        }

        // 2. Try to find by name
        if let projectName = projectName {
            let store = ProjectHarnessStore.shared
            let projects = try await store.loadAllProjects()
            if let project = projects.first(where: { $0.name == projectName }) {
                return project.id
            }
        }

        // 3. If we're in the Anigma repo, default to self-host project
        if SelfHostProjectConfig.isAnigmaRepo {
            _ = try await SelfHostProjectConfig.ensureRegistered()
            return SelfHostProjectConfig.projectId
        }

        // 4. Fall back to interactive resolution
        if interactive {
            if let resolvedId = try await resolveProjectId(
                projectId: nil,
                projectName: projectName,
                interactive: true
            ) {
                return resolvedId
            }
        }

        // 5. No project found
        throw PrincipalityError.projectIdRequired
    }

    /// CLI helper to get controller with self-host default.
    public func controllerWithSelfHostDefault(
        projectId: UUID? = nil,
        projectName: String? = nil,
        interactive: Bool = false
    ) async throws -> PrincipalityProjectController {
        let resolvedId = try await resolveProjectIdWithSelfHostDefault(
            projectId: projectId,
            projectName: projectName,
            interactive: interactive
        )
        return controller(for: resolvedId)
    }
}
