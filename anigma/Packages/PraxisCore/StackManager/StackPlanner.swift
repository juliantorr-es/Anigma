//
//  StackPlanner.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

public enum StackPlannerError: Error, CustomStringConvertible, Sendable {
    case cycleDetected
    case missingParent(branch: String, parent: String)

    public var description: String {
        switch self {
        case .cycleDetected: return "StackPlanner cycle detected"
        case .missingParent(let b, let p): return "StackPlanner missing parent: \(b) -> \(p)"
        }
    }
}

public struct StackPlanner: Sendable {
    public init() {}

    public func orderedBranches(record: StackRecord) throws -> [StackRecord.Branch] {
        let byName = Dictionary(uniqueKeysWithValues: record.branches.map { ($0.name, $0) })
        for b in record.branches {
            if b.parent != record.baseBranch, byName[b.parent] == nil {
                throw StackPlannerError.missingParent(branch: b.name, parent: b.parent)
            }
        }

        var visiting = Set<String>()
        var visited = Set<String>()
        var output: [StackRecord.Branch] = []

        func dfs(_ name: String) throws {
            if visited.contains(name) { return }
            if visiting.contains(name) { throw StackPlannerError.cycleDetected }
            visiting.insert(name)
            if let b = byName[name] {
                if b.parent != record.baseBranch {
                    try dfs(b.parent)
                }
                visited.insert(name)
                visiting.remove(name)
                output.append(b)
            }
        }

        for b in record.branches {
            try dfs(b.name)
        }

        let uniq = Array(Dictionary(uniqueKeysWithValues: output.map { ($0.name, $0) }).values)
        return uniq.sorted { a, b in
            if a.parent == b.parent { return a.createdAt < b.createdAt }
            return a.parent < b.parent
        }
    }

    public func tipBranchName(record: StackRecord) -> String? {
        guard !record.branches.isEmpty else { return nil }
        var children = Set(record.branches.map { $0.name })
        for b in record.branches {
            children.remove(b.parent)
        }
        if let only = children.first { return only }
        return record.branches.sorted { $0.createdAt < $1.createdAt }.last?.name
    }
}
