//
//  ProjectInitializerSystem.swift
//  HarmoniaModule
//
//  System that initializes projects by breaking down PRDs into feature test cases
//  and generating project scaffolding.
//

import Foundation
import AnigmaCore

// MARK: - Project Initializer System

/// System that initializes projects by breaking down PRDs into feature test cases.
public struct ProjectInitializerSystem: System {
    public let name = "ProjectInitializer"

    /// Project execution surface - workers talk to this, not to GRDB directly.
    private let project: ProjectExecutionSurface

    /// Tool registry for LLM calls.
    private let toolRegistry: SimpleToolRegistry

    public init(
        project: ProjectExecutionSurface,
        toolRegistry: SimpleToolRegistry = SimpleToolRegistry()
    ) {
        self.project = project
        self.toolRegistry = toolRegistry
    }

    public func update(world: World) async {
        let harnessStore = ProjectHarnessStore.shared
        try? await harnessStore.initialize()

        let candidates = await world.query(ProjectSpecComponent.self)
            .filter { $0.1.status == .uninitialized }

        guard !candidates.isEmpty else {
            await Logger.shared.info(
                "ProjectInitializerSystem: No uninitialized projects found",
                category: "Harness"
            )
            return
        }

        let service = ProjectInitializationService(
            harnessStore: harnessStore,
            toolRegistry: toolRegistry
        )

        for (entityId, component) in candidates {
            guard let spec = try? await harnessStore.loadProject(id: component.projectSpecId.uuidString) else {
                await Logger.shared.error(
                    "ProjectInitializerSystem: Missing spec for \(component.projectSpecId)",
                    category: "Harness"
                )
                continue
            }

            do {
                _ = try await service.initializeProject(projectSpec: spec)
                var updated = component
                updated.status = .initialized
                updated.updatedAt = Date()
                await world.addComponent(entityId, updated)
            } catch {
                await Logger.shared.error(
                    "ProjectInitializerSystem: Failed to initialize \(spec.name): \(error.localizedDescription)",
                    category: "Harness"
                )
            }
        }
    }
}

// MARK: - Project Spec Component

/// ECS component for project specifications.
public struct ProjectSpecComponent: Component, Codable {
    /// Project spec ID (references ProjectSpec in GRDB store).
    public var projectSpecId: UUID

    /// Current status of the project.
    public var status: ProjectStatus

    /// When this component was last updated.
    public var updatedAt: Date

    public init(
        projectSpecId: UUID,
        status: ProjectStatus = .uninitialized,
        updatedAt: Date = Date()
    ) {
        self.projectSpecId = projectSpecId
        self.status = status
        self.updatedAt = updatedAt
    }
}

// MARK: - Feature Test Case Component

/// ECS component for feature test cases.
public struct FeatureTestCaseComponent: Component, Codable {
    /// Feature test case ID (references FeatureTestCase in GRDB store).
    public var featureTestCaseId: UUID

    /// Project spec ID this feature belongs to.
    public var projectSpecId: UUID

    /// Current status of the feature.
    public var status: FeatureTestStatus

    /// When this component was last updated.
    public var updatedAt: Date

    public init(
        featureTestCaseId: UUID,
        projectSpecId: UUID,
        status: FeatureTestStatus = .pending,
        updatedAt: Date = Date()
    ) {
        self.featureTestCaseId = featureTestCaseId
        self.projectSpecId = projectSpecId
        self.status = status
        self.updatedAt = updatedAt
    }
}

// MARK: - Helper Types

/// Configuration for project initialization.
public struct ProjectInitializationConfig: Sendable {
    /// Whether to generate a git repository.
    public var initializeGit: Bool

    /// Whether to generate a scaffolding script.
    public var generateScaffolding: Bool

    /// Default test framework to use (e.g., "swift-test", "jest", "pytest").
    public var defaultTestFramework: String?

    /// Default build system to use (e.g., "swift-package", "npm", "cargo").
    public var defaultBuildSystem: String?

    public init(
        initializeGit: Bool = true,
        generateScaffolding: Bool = true,
        defaultTestFramework: String? = nil,
        defaultBuildSystem: String? = nil
    ) {
        self.initializeGit = initializeGit
        self.generateScaffolding = generateScaffolding
        self.defaultTestFramework = defaultTestFramework
        self.defaultBuildSystem = defaultBuildSystem
    }

    public static let `default` = ProjectInitializationConfig()
}

/// Result of project initialization.
public struct ProjectInitializationResult: Sendable {
    /// Number of feature test cases created.
    public var featureCount: Int

    /// Whether git repository was initialized.
    public var gitInitialized: Bool

    /// Path to scaffolding script (if generated).
    public var scaffoldingScriptPath: String?

    /// Summary of initialization.
    public var summary: String

    public init(
        featureCount: Int,
        gitInitialized: Bool,
        scaffoldingScriptPath: String? = nil,
        summary: String
    ) {
        self.featureCount = featureCount
        self.gitInitialized = gitInitialized
        self.scaffoldingScriptPath = scaffoldingScriptPath
        self.summary = summary
    }
}

// MARK: - Initialization Service

/// Service for project initialization logic.
public actor ProjectInitializationService {
    private let harnessStore: ProjectHarnessStore
    private let toolRegistry: SimpleToolRegistry

    public init(
        harnessStore: ProjectHarnessStore = ProjectHarnessStore.shared,
        toolRegistry: SimpleToolRegistry = SimpleToolRegistry()
    ) {
        self.harnessStore = harnessStore
        self.toolRegistry = toolRegistry
    }

    /// Initializes a project by breaking down its PRD into feature test cases.
    public func initializeProject(
        projectSpec: ProjectSpec,
        config: ProjectInitializationConfig = .default
    ) async throws -> ProjectInitializationResult {
        try? await harnessStore.initialize()

        // Step 1: Call LLM to break down PRD into features
        let features = try await breakDownPRDIntoFeatures(projectSpec: projectSpec)

        // Step 2: Create feature test cases in store
        try await harnessStore.createFeatureTestCases(features)

        // Step 3: Generate scaffolding script if requested
        var scaffoldingScriptPath: String?
        if config.generateScaffolding {
            scaffoldingScriptPath = try await generateScaffoldingScript(
                projectSpec: projectSpec,
                features: features,
                config: config
            )
        }

        // Step 4: Initialize git repository if requested
        var gitInitialized = false
        if config.initializeGit {
            gitInitialized = try await initializeGitRepository(projectSpec: projectSpec)
        }

        // Step 5: Update project status
        var updatedSpec = projectSpec
        updatedSpec.status = .initialized
        updatedSpec.updatedAt = Date()
        try await harnessStore.updateProjectSpec(updatedSpec)

        // Step 6: Create initial progress snapshot
        let snapshot = ProjectProgressSnapshot(
            projectId: projectSpec.id,
            sessionIndex: 0,
            summary: "Project initialized with \(features.count) feature test cases.",
            featureIdsTouched: features.map { $0.id },
            gitCommitHash: gitInitialized ? "INITIAL_COMMIT" : nil
        )
        _ = try await harnessStore.createProgressSnapshot(snapshot)

        return ProjectInitializationResult(
            featureCount: features.count,
            gitInitialized: gitInitialized,
            scaffoldingScriptPath: scaffoldingScriptPath,
            summary: "Initialized project '\(projectSpec.name)' with \(features.count) features."
        )
    }

    // MARK: - Private Methods

    /// Breaks down a PRD into feature test cases using LLM.
    private func breakDownPRDIntoFeatures(projectSpec: ProjectSpec) async throws -> [FeatureTestCase] {
        await Logger.shared.info("Breaking down PRD into features for project: \(projectSpec.name)", category: "Harness")

        if let _ = await toolRegistry.handler(for: "analyze_prd") {
            let response = try await toolRegistry.execute(
                request: ToolRequest(
                    name: "analyze_prd",
                    arguments: ["content": projectSpec.specText],
                    sessionId: "init-\(projectSpec.id.uuidString)"
                )
            )
            if response.success {
                let parsed = parseFeatures(from: response.output, projectId: projectSpec.id)
                if !parsed.isEmpty {
                    await Logger.shared.info(
                        "LLM-derived \(parsed.count) feature test cases for project: \(projectSpec.name)",
                        category: "Harness"
                    )
                    return parsed
                }
            }
        }

        let heuristicFeatures = parseFeatures(from: projectSpec.specText, projectId: projectSpec.id)
        if !heuristicFeatures.isEmpty {
            await Logger.shared.info(
                "Created \(heuristicFeatures.count) feature test cases for project: \(projectSpec.name)",
                category: "Harness"
            )
            return heuristicFeatures
        }

        let defaultFeature = FeatureTestCase(
            projectId: projectSpec.id,
            name: "Initial Implementation",
            category: "Core",
            description: "Initial implementation based on PRD: \(projectSpec.name)",
            validationSteps: [
                "Set up project structure",
                "Implement core functionality",
                "Write basic tests"
            ],
            priority: 1,
            estimatedComplexity: 3
        )

        await Logger.shared.info("Created default feature for project: \(projectSpec.name)", category: "Harness")
        return [defaultFeature]
    }

    /// Generates a scaffolding script for the project.
    private func generateScaffoldingScript(
        projectSpec: ProjectSpec,
        features: [FeatureTestCase],
        config: ProjectInitializationConfig
    ) async throws -> String {
        let scriptContent = """
        #!/bin/bash
        # Project scaffolding script for: \(projectSpec.name)
        # Generated by Harmonia Project Harness

        echo "Setting up project: \(projectSpec.name)"

        # Create basic directory structure
        mkdir -p src
        mkdir -p tests
        mkdir -p scripts

        # Create README
        cat > README.md << 'EOF'
        # \(projectSpec.name)

        \(projectSpec.specText)

        ## Features

        \(features.map { "- **\($0.name)**: \($0.description)" }.joined(separator: "\n"))

        ## Development

        This project was initialized by Harmonia Project Harness.
        EOF

        # Create basic .gitignore if git is enabled
        if [ "$1" = "--with-git" ]; then
            cat > .gitignore << 'EOF'
        .DS_Store
        .build/
        *.swiftpm
        xcuserdata/
        DerivedData/
        .swiftpm/
        .cache/
        EOF
        fi

        echo "Project scaffolding complete for: \(projectSpec.name)"
        echo "Total features: \(features.count)"
        """
        await Logger.shared.info("Prepared scaffolding script template (\(scriptContent.count) bytes)", category: "Harness")

        let fileName = "\(projectSpec.name.lowercased().replacingOccurrences(of: " ", with: "_"))_scaffold.sh"
        let baseDirectory = projectSpec.projectDirectory ?? FileManager.default.currentDirectoryPath
        let scriptPath = FileToolRuntime.resolvePath(fileName, relativeTo: baseDirectory)

        if let _ = await toolRegistry.handler(for: "write_file") {
            let response = try await toolRegistry.execute(
                request: ToolRequest(
                    name: "write_file",
                    arguments: ["path": fileName, "content": scriptContent],
                    sessionId: "init-\(projectSpec.id.uuidString)",
                    projectId: projectSpec.id.uuidString
                )
            )
            if !response.success {
                throw HarnessError.invalidProjectState("Failed to write scaffolding script: \(response.error ?? "unknown error")")
            }
        } else {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        }

        await Logger.shared.info("Generated scaffolding script at: \(scriptPath)", category: "Harness")
        return scriptPath
    }

    /// Initializes a git repository for the project.
    private func initializeGitRepository(projectSpec: ProjectSpec) async throws -> Bool {
        let baseDirectory = projectSpec.projectDirectory ?? FileManager.default.currentDirectoryPath
        let command = "cd \(shellEscape(baseDirectory)) && git init"

        if let _ = await toolRegistry.handler(for: "run_shell") {
            let response = try await toolRegistry.execute(
                request: ToolRequest(
                    name: "run_shell",
                    arguments: ["command": command],
                    sessionId: "init-\(projectSpec.id.uuidString)",
                    projectId: projectSpec.id.uuidString
                )
            )
            return response.success
        }

        return false
    }

    private func parseFeatures(from content: String, projectId: UUID) -> [FeatureTestCase] {
        let lines = content.split(separator: "\n")
        var features: [FeatureTestCase] = []
        var currentCategory = "Core"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("feature:") ||
                trimmed.lowercased().hasPrefix("functionality:") ||
                trimmed.lowercased().hasPrefix("requirement:") ||
                trimmed.hasPrefix("- ") {
                let raw = trimmed
                    .replacingOccurrences(of: "Feature:", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "Functionality:", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "Requirement:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "- "))

                if !raw.isEmpty {
                    let feature = FeatureTestCase(
                        projectId: projectId,
                        name: raw,
                        category: currentCategory,
                        description: "Feature extracted from PRD: \(raw)",
                        validationSteps: [
                            "Implement \(raw) functionality",
                            "Write tests for \(raw)",
                            "Verify \(raw) works as specified"
                        ],
                        priority: features.count + 1,
                        estimatedComplexity: 3
                    )
                    features.append(feature)
                }
            }

            if trimmed.hasPrefix("# ") {
                currentCategory = String(trimmed.dropFirst(2))
            }
        }

        return features
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
