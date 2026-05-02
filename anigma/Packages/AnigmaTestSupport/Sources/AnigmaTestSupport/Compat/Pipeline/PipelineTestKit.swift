//
//  PipelineTestKit.swift
//  AnigmaTestSupport
//
//  [Brief description of file purpose]
//

import Foundation
import AnigmaCore
import ContractsCore
import DatabaseCore
import AnigmaPrimitives

public struct PipelineTestConfig {
  public var budgets: ContractBudgets
  public var trustTier: TrustTier
  public var securityZone: SecurityZone
  public var executorIdentity: String
  public var grapheneEngine: GrapheneEngine
  public var artifactStore: PipelineArtifactStore
  public var receiptStore: ReceiptStore
  public var jobQueue: ContractJobQueue

  public init(
    budgets: ContractBudgets,
    trustTier: TrustTier,
    securityZone: SecurityZone,
    executorIdentity: String,
    grapheneEngine: GrapheneEngine,
    artifactStore: PipelineArtifactStore,
    receiptStore: ReceiptStore,
    jobQueue: ContractJobQueue
  ) {
    self.budgets = budgets
    self.trustTier = trustTier
    self.securityZone = securityZone
    self.executorIdentity = executorIdentity
    self.grapheneEngine = grapheneEngine
    self.artifactStore = artifactStore
    self.receiptStore = receiptStore
    self.jobQueue = jobQueue
  }
}

public enum PipelineTestKit {
  public static func makeHarness(
    plan: PipelinePlan,
    config: PipelineTestConfig,
    registryBuilder: ContractTestCompat.RegistryBuilder? = nil
  ) async throws -> GrapheneTestHarness {
    let registry = registryBuilder?.build() ?? ContractRegistry()
    let runner = try await PipelineRunner(
      plan: plan,
      registry: registry,
      jobQueue: config.jobQueue,
      receiptStore: config.receiptStore,
      artifactStore: config.artifactStore,
      defaultBudgets: config.budgets,
      trustTier: config.trustTier,
      securityZone: config.securityZone,
      executorIdentity: config.executorIdentity,
      grapheneEngine: config.grapheneEngine
    )
    return GrapheneTestHarness(runner: runner)
  }
}
