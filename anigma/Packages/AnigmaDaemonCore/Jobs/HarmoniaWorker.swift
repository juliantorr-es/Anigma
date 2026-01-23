//
//  HarmoniaWorker.swift
//  AnigmaDaemonCore
//
//  Worker that executes Harmonia reasoning tasks within the daemon context.
//  Uses the RLM (Runtime Loop Manager) stack for "Stupid-Fast RAG" capabilities.
//

import Foundation
import HarmoniaModule
import AnigmaCore
import AnigmaPrimitives
import DatabaseCore
import ContractsCore
import RLMModule
import VectorIndexCapsule
import ContextumModule
import InferenceCore

/// Configuration payload for a Harmonia task.
public struct HarmoniaJobConfig: Codable, Sendable {
    public let taskSummary: String
    public let sessionID: String
    public let governancePolicy: String
    public let useFastRAG: Bool
    
    public init(taskSummary: String, sessionID: String, governancePolicy: String, useFastRAG: Bool = true) {
        self.taskSummary = taskSummary
        self.sessionID = sessionID
        self.governancePolicy = governancePolicy
        self.useFastRAG = useFastRAG
    }
}

/// Worker that wraps the Harmonia reasoning engine.
public final class HarmoniaWorker: BaseWorker, JobWorker {
    public static let kind = "harmonia.execute"
    
    public override init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let jobConfig = try JSONDecoder().decode(HarmoniaJobConfig.self, from: config)
        
        // 2. Initialize Infrastructure
        let dbPath = (NSHomeDirectory() as NSString).appendingPathComponent(".anigma/anigma.db")
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        
        // Initialize Contextum Database (The Engram Store)
        let contextumDB = try await ContextumDatabase(database: dbActor)
        
        // Initialize RAG Engine Capsules
        // Note: In a production environment, we might share these instances across jobs
        // or rely on the daemon's global state, but for now we instantiate per job.
        let vectorIndex = try VectorIndexCapsuleWrapper(config: VectorIndexConfig(dimension: 384))
        // TODO: Initialize RankFusionCapsuleWrapper if available
        // let rankFusion = try RankFusionCapsuleWrapper() 
        
        // Create Inference Authority for code generation
        // Use DaemonInferenceAuthority for real ml-worker execution
        // Falls back to mock behavior if ml-worker not available
        let inferenceAuthority = DaemonInferenceAuthority()
        
        // Initialize Artifact Authority wrapper for RLM
        // We might need a bridge here if ArtifactAuthority is protocol based
        // let artifactAuthority = ... 
        
        // 3. Create RLM Environment
        // This is the "Context Environment" that holds Engrams
        // We currently pass nil for some optional capsules until we wire them fully
        let environment = try await ContextEnvironment(
            contextumDatabase: contextumDB,
            artifactAuthority: nil, // TODO: Wire up artifact authority from daemon context
            evidenceAuthority: nil,  // TODO: Wire up evidence authority
            embeddingComputing: nil,
             inferenceAuthority: inferenceAuthority,
            capsules: ["vectorIndex": vectorIndex]
        )
        
        // 4. Create Governor
        // The Governor manages the execution loop and budgets
        let governor = try await RLMGovernor(
            policy: .default,
            budgets: .default,
            environment: environment,
            evidenceAuthority: nil
        )
        
        // 5. Execute Task via RLM
        // This uses the RetrievalPlanner inside RLM to do the fast lookups
        let artifact: RLMArtifact
        
        if jobConfig.useFastRAG {
            // Use the "Stupid-Fast" path
            // In a real implementation, we would have a planner model instance here
            // For this worker, we might be running a "One-Shot" or "Planning Loop"
            
            // Placeholder: We need to adapt the executePlanningLoop to work with the worker inputs
            // artifact = try await governor.executePlanningLoop(...)
            
            // For now, we simulate the result to confirm wiring
            artifact = RLMArtifact(
                artifactType: "harmonia.result",
                content: "Task executed via RLM Governor with Fast RAG.",
                format: "json",
                evidenceChain: [],
                sourceSpans: []
            )
        } else {
            // Fallback to legacy Themis Orchestrator
            let themis = await HarmoniaModule.createThemisOrchestrator()
            let taskIntent = TaskIntent(summary: jobConfig.taskSummary)
            let session = await themis.startSession(tenantId: "local", principalId: "daemon", domain: .coding)
            let result = try await themis.runTask(task: taskIntent, session: session)
            
            // Convert Themis result to RLMArtifact
            artifact = RLMArtifact(
                artifactType: "harmonia.result",
                content: "Task executed via Legacy Themis.",
                format: "json",
                evidenceChain: [],
                sourceSpans: []
            )
        }
        
        // 6. Package Results
        let resultData = try JSONEncoder().encode(artifact)
        let resultArtifact = JobOutputPayload(
            kind: "harmonia.result",
            mediaType: "application/json",
            data: resultData,
            filenameHint: "harmonia_result_\(jobConfig.sessionID).json"
        )
        
        return [resultArtifact]
    }
}

