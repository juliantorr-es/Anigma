//
//  PrincipalityProjectControllerPreviewCompat.swift
//  HarmoniaCLI
//

import Foundation
import HarmoniaModule

extension PrincipalityProjectController {
    public func previewSwift6Step(
        policy: Swift6MigrationPolicy = .default
    ) async throws -> Swift6StepIntent {
        let state = try await loadSwift6MigrationState()
        return BasicSwift6StepEngine().chooseNextStep(from: state, policy: policy)
    }

    public func previewGameStep(
        policy: GameProjectPolicy = .default
    ) async throws -> GameStepIntent {
        let state = try await loadGameProjectState()
        if state.isComplete {
            return .pause(reason: "Project complete - no open tasks")
        }

        if let scene = state.scenesWithPendingWork.first,
           let sceneId = UUID(uuidString: scene.id) {
            if policy.preferBrokenScenes && scene.isBroken {
                return .resimulateScene(sceneId: sceneId)
            }
            return .runSceneTest(sceneId: sceneId)
        }

        return .pause(reason: "No pending work available")
    }
}
