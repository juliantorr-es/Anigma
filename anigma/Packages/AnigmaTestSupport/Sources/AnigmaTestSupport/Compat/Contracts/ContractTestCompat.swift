//
//  ContractTestCompat.swift
//  AnigmaTestSupport
//
//  Contract definition for ContractTestCompat in AnigmaTestSupport.
//

import Foundation
import ContractsCore
import AnigmaCore

public struct ContractTestCompat {
  public static func makeID(
    name: String,
    major: Int = 1,
    minor: Int = 0,
    schemaHash: String = "legacy"
  ) -> ContractID {
    ContractID(name: name, major: major, minor: minor, schemaHash: schemaHash)
  }

  public class RegistryBuilder {
    private var registry: ContractRegistry

    public init(registry: ContractRegistry = .init()) {
      self.registry = registry
    }

    public func register<C: ContractSpec>(_ type: C.Type, using name: String) async {
      await registry.register(C.self)
    }

    public func build() -> ContractRegistry {
      registry
    }
  }

  public struct ReceiptStatusView: Sendable {
    public let legacyDescription: String

    public init(_ status: ContractStatus) {
      self.legacyDescription = status.description
    }
  }
}

public extension ContractStatus {
  var description: String {
    switch self {
    case .satisfied: return "satisfied"
    case .rejected: return "rejected"
    case .quarantined: return "quarantined"
    case .failed: return "failed"
    }
  }
}

public class PipelineGraphBuilder {
  private var stringEdges: [String: [String]] = [:]

  public init() {}

  public func addEdge(from: String, to: [String]) -> Self {
    stringEdges[from] = to
    return self
  }

  public func build() -> PipelineGraph {
    PipelineGraph(edges: stringEdges)
  }
}

public struct ContractPlanBuilder {
  public static func makePlan(
    sessionID: String = UUID().uuidString,
    graph: PipelineGraph,
    artifactRefs: [String] = []
  ) -> PipelinePlan {
    PipelinePlan(sessionID: sessionID, graph: graph, rootArtifactRefs: artifactRefs)
  }
}
