//
//  GrapheneTestHarness.swift
//  AnigmaTestSupport
//
//  [Brief description of file purpose]
//

import Foundation
import ContractsCore
import AnigmaCore

public actor GrapheneTestHarness {
  private let runner: PipelineRunner

  public init(runner: PipelineRunner) {
    self.runner = runner
  }

  public func runUntilIdle() async throws -> [ContractReceipt] {
    try await runner.runUntilIdle()
    return await runner.allReceipts()
  }

  public func snapshot() async -> [ContractReceipt] {
    await runner.allReceipts()
  }
}
