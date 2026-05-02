//
//  PipelineGraph.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import ContractsCore
import Foundation

/// Directed acyclic graph describing contract dependencies.
public struct PipelineGraph: Sendable {
    private let adjacency: [String: [String]]
    private let reverse: [String: [String]]

    public init(edges: [String: [String]]) {
        self.adjacency = edges
        var reverse: [String: [String]] = [:]
        for (node, downstream) in edges {
            for target in downstream {
                reverse[target, default: []].append(node)
            }
        }
        self.reverse = reverse
    }

    /// Upstream contract identifiers for a node.
    public func upstream(of contractID: String) -> [String] {
        reverse[contractID] ?? []
    }

    /// Downstream contract identifiers for a node.
    public func downstream(of contractID: String) -> [String] {
        adjacency[contractID] ?? []
    }

    /// Returns a topological order if the graph is acyclic; empty array on cycle detection.
    public func topologicalOrder() -> [String] {
        var inDegree: [String: Int] = [:]
        for (node, downstream) in adjacency {
            inDegree[node, default: 0] = inDegree[node, default: 0]
            for target in downstream {
                inDegree[target, default: 0] += 1
            }
        }

        var queue = inDegree.filter { $0.value == 0 }.map(\.key)
        var order: [String] = []

        while let node = queue.first {
            queue.removeFirst()
            order.append(node)

            for target in downstream(of: node) {
                inDegree[target, default: 0] -= 1
                if inDegree[target] == 0 {
                    queue.append(target)
                }
            }
        }

        if order.count != inDegree.count {
            return []
        }
        return order
    }
}

/// Binds a pipeline graph to a session and tracks eligibility based on receipts.
public struct PipelinePlan: Sendable {
    public let sessionID: String
    public let graph: PipelineGraph
    public let rootArtifactRefs: [String]

    public init(sessionID: String, graph: PipelineGraph, rootArtifactRefs: [String]) {
        self.sessionID = sessionID
        self.graph = graph
        self.rootArtifactRefs = rootArtifactRefs
    }

    /// Contracts that can run now: all upstream contracts satisfied for this session.
    public func nextEligible(receipts: [ContractReceipt]) -> [String] {
        let satisfied = Set(
            receipts
                .filter { $0.sessionID == sessionID && $0.status == .satisfied }
                .map(\.contractID.name)
        )
        var eligible: [String] = []

        let knownNodes = Set(graph.topologicalOrder())
        for node in knownNodes {
            guard !satisfied.contains(node) else { continue }
            let upstream = graph.upstream(of: node)
            if upstream.allSatisfy({ satisfied.contains($0) }) {
                eligible.append(node)
            }
        }
        return eligible
    }

    /// Input artifact references for a contract based on upstream receipts or root inputs.
    public func inputRefs(for contractID: ContractID, receipts: [ContractReceipt]) -> [String] {
        let upstream = graph.upstream(of: contractID.name)
        if upstream.isEmpty {
            return rootArtifactRefs.sorted()
        }

        var refs: [String] = []
        for receipt in receipts where upstream.contains(receipt.contractID.name) && receipt.status == .satisfied {
            refs.append(contentsOf: receipt.outputRefs)
        }
        return refs.sorted()
    }
}
