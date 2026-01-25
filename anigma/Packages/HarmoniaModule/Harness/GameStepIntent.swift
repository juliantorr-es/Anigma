//
//  GameStepIntent.swift
//  HarmoniaModule
//
//  Step intent for game project domain.
//

@preconcurrency import Foundation

/// Intent for a game project step.
public enum GameStepIntent: Sendable, Codable {
    /// Run a specific scene test.
    case runSceneTest(sceneId: UUID)

    /// Resimulate a specific scene.
    case resimulateScene(sceneId: UUID)

    /// Pause playtesting with a reason.
    case pause(reason: String)

    /// Human-readable description of the intent.
    public var description: String {
        switch self {
        case .runSceneTest(let sceneId):
            return "Run scene test \(sceneId.uuidString.prefix(8))..."
        case .resimulateScene(let sceneId):
            return "Resimulate scene \(sceneId.uuidString.prefix(8))"
        case .pause(let reason):
            return "Pause: \(reason)"
        }
    }
}

/// Protocol for game step engines.
public protocol GameStepEngine: Sendable {
    /// Chooses the next step based on game project state and policy.
    /// - Parameters:
    ///   - state: Current game project state.
    ///   - policy: Game project policy.
    /// - Returns: The chosen step intent.
    func chooseNextStep(
        from state: GameProjectState,
        policy: GameProjectPolicy
    ) -> GameStepIntent
}

/// Basic deterministic step engine for game projects.
public struct BasicGameStepEngine: GameStepEngine {
    /// Creates a new basic step engine.
    public init() {}

    /// Chooses the next step using a deterministic heuristic.
    public func chooseNextStep(
        from state: GameProjectState,
        policy: GameProjectPolicy
    ) -> GameStepIntent {
        // Rule 1: If project is complete, pause
        guard !state.isComplete else {
            return .pause(reason: "Project complete - no open tasks")
        }

        // Rule 2: Get scenes with pending work
        let scenesWithWork = state.scenesWithPendingWork

        // Rule 3: Filter out scenes with recent tainted sessions if policy says to avoid them
        let candidateScenes: [SceneSummary]
        if policy.avoidTaintedAreas {
            candidateScenes = scenesWithWork.filter { !$0.hasRecentTaintedSessions }
        } else {
            candidateScenes = scenesWithWork
        }

        // Rule 4: If no candidate scenes due to failure avoidance, pause
        if policy.avoidTaintedAreas && candidateScenes.isEmpty && !scenesWithWork.isEmpty {
            return .pause(reason: "All scenes with pending work have recent tainted sessions")
        }

        // Rule 5: If no scenes with work at all, consider resimulation
        if candidateScenes.isEmpty {
            if policy.allowResimulation && !state.scenes.isEmpty {
                // Find scene with most tests that hasn't been resimulated recently
                if let sceneToResimulate = chooseSceneForResimulation(from: state.scenes),
                   let sceneUUID = UUID(uuidString: sceneToResimulate.id) {
                    return .resimulateScene(sceneId: sceneUUID)
                }
            }
            return .pause(reason: "No pending work and resimulations not allowed or no scenes to resimulate")
        }

        // Rule 6: Choose the best scene based on policy
        let chosenScene = chooseBestScene(from: candidateScenes, policy: policy)

        // Rule 7: Choose the best test from that scene
        if let chosenTest = chooseBestTest(from: chosenScene.tests),
           let sceneUUID = UUID(uuidString: chosenTest.sceneId) {
            return .runSceneTest(sceneId: sceneUUID)
        }

        // Rule 8: If scene has work but no suitable tests, resimulate it
        if policy.allowResimulation, let sceneUUID = UUID(uuidString: chosenScene.id) {
            return .resimulateScene(sceneId: sceneUUID)
        }

        // Rule 9: Fallback pause
        return .pause(reason: "No suitable tests found in chosen scene")
    }

    /// Chooses the best scene from candidates based on policy.
    private func chooseBestScene(
        from candidates: [SceneSummary],
        policy: GameProjectPolicy
    ) -> SceneSummary {
        // Sort by priority criteria
        return candidates.sorted { (scene1: SceneSummary, scene2: SceneSummary) in
            // 1. Prefer broken scenes if policy says so
            if policy.preferBrokenScenes && scene1.isBroken != scene2.isBroken {
                return scene1.isBroken && !scene2.isBroken
            }

            // 2. Prefer more open tasks
            if scene1.openTaskCount != scene2.openTaskCount {
                return scene1.openTaskCount > scene2.openTaskCount
            }

            // 3. Prefer scenes that haven't been tested recently
            let scene1LastTest = scene1.lastTestedSession ?? 0
            let scene2LastTest = scene2.lastTestedSession ?? 0
            return scene1LastTest < scene2LastTest
        }.first!
    }

    /// Chooses the best test from a scene's tests.
    private func chooseBestTest(from tests: [SceneTest]) -> SceneTest? {
        // Filter to pending tests
        let pendingTests = tests.filter { $0.status == .pending }

        // Sort by: priority (if available), then creation date (oldest first)
        return pendingTests.sorted { test1, test2 in
            // Compare by priority if both have it
            if let priority1 = test1.priority, let priority2 = test2.priority {
                if priority1 != priority2 {
                    return priority1 > priority2
                }
            }

            // Fall back to creation date (oldest first)
            return test1.createdAt < test2.createdAt
        }.first
    }

    /// Chooses a scene to resimulate.
    private func chooseSceneForResimulation(from scenes: [SceneSummary]) -> SceneSummary? {
        // Prefer scenes with tests but no recent sessions
        return scenes
            .filter { !$0.tests.isEmpty }
            .sorted { scene1, scene2 in
                // More tests first
                if scene1.tests.count != scene2.tests.count {
                    return scene1.tests.count > scene2.tests.count
                }

                // Broken scenes first
                if scene1.isBroken != scene2.isBroken {
                    return scene1.isBroken && !scene2.isBroken
                }

                // Less recently tested first
                let scene1LastTest = scene1.lastTestedSession ?? 0
                let scene2LastTest = scene2.lastTestedSession ?? 0
                return scene1LastTest < scene2LastTest
            }
            .first
    }
}

/// Factory for game step engines.
public enum GameStepEngineFactory {
    /// Creates a step engine for the given configuration.
    /// - Parameter config: Engine configuration.
    /// - Returns: A step engine instance.
    public static func create(config: String = "basic") -> any GameStepEngine {
        switch config {
        case "basic":
            return BasicGameStepEngine()
        default:
            return BasicGameStepEngine()
        }
    }
}
