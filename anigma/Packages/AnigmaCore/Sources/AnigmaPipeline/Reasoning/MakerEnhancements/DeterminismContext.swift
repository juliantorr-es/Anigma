//
//  DeterminismContext.swift
//  AnigmaCore
//
//  Helper for deterministic seeding of MakerEngine enhancements.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation

public struct DeterminismContext: Sendable {
    public let seed: String
    public let deterministicStepId: String

    public init(seed: String, deterministicStepId: String) {
        self.seed = seed
        self.deterministicStepId = deterministicStepId
    }
}
