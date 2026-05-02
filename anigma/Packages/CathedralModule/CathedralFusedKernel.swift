//
//  CathedralFusedKernel.swift
//  CathedralModule
//
//  Mission planning and fused execution surface for Cathedral.
//

import Foundation
import ContractsCore

public struct CathedralMission: Sendable, Codable {
    public let missionId: String
    public let operationType: String
    public let batchSize: Int
    public let evidenceCount: Int
    public let sessionId: String
    public let modelId: String?
    public let preferredEngine: String
    public let privacyContract: MissionPrivacyContract
    public let createdAt: Date

    public init(
        missionId: String = UUID().uuidString,
        operationType: String,
        batchSize: Int,
        evidenceCount: Int,
        sessionId: String,
        modelId: String? = nil,
        preferredEngine: String = "coreml",
        privacyContract: MissionPrivacyContract = .default(purpose: .retrieval),
        createdAt: Date = Date()
    ) {
        self.missionId = missionId
        self.operationType = operationType
        self.batchSize = batchSize
        self.evidenceCount = evidenceCount
        self.sessionId = sessionId
        self.modelId = modelId
        self.preferredEngine = preferredEngine
        self.privacyContract = privacyContract
        self.createdAt = createdAt
    }
}

public struct CathedralFusedKernelReceipt: Sendable, Codable {
    public let missionId: String
    public let plannedStages: [String]
    public let rootHash: String
    public let privacyContract: MissionPrivacyContract
    public let timestamp: Date

    public init(
        missionId: String,
        plannedStages: [String],
        rootHash: String,
        privacyContract: MissionPrivacyContract,
        timestamp: Date = Date()
    ) {
        self.missionId = missionId
        self.plannedStages = plannedStages
        self.rootHash = rootHash
        self.privacyContract = privacyContract
        self.timestamp = timestamp
    }
}

public actor CathedralFusedKernelPlanner {
    public init() {}

    public func plan(
        operation: MLOperation,
        evidenceCount: Int,
        modelId: String? = nil
    ) -> CathedralMission {
        CathedralMission(
            operationType: operation.type.rawValue,
            batchSize: max(1, evidenceCount),
            evidenceCount: evidenceCount,
            sessionId: operation.sessionId,
            modelId: modelId,
            preferredEngine: "coreml"
        )
    }

    public func execute(_ mission: CathedralMission) -> CathedralFusedKernelReceipt {
        let stages = [
            "hash",
            "validate",
            "seal"
        ]
        let hashInput = [
            mission.missionId,
            mission.operationType,
            String(mission.batchSize),
            String(mission.evidenceCount),
            mission.sessionId,
            mission.modelId ?? "",
            mission.preferredEngine
        ].joined(separator: "|")

        return CathedralFusedKernelReceipt(
            missionId: mission.missionId,
            plannedStages: stages,
            rootHash: hashInput.blake3Hash,
            privacyContract: mission.privacyContract
        )
    }
}
