//
//  ResearchRegistry.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  Phase 4C registry storage for research bundles and tasks.
//

import Foundation
import HarmoniaModule

/// Research registry for Phase 4C.
public actor ResearchRegistry {
    private let dbPath: String
    private var bundles: [ResearchBundle] = []
    private var tasks: [ResearchTask] = []
    private var debtTasks: [ResearchDebtTask] = []

    public init(dbPath: String = ":memory:") {
        self.dbPath = dbPath
        loadIfNeeded()
    }

    public init() {
        self.dbPath = ":memory:"
        loadIfNeeded()
    }

    // MARK: - Bundle Management

    public func getLatestAdequateBundle(for topicSpec: TopicSpec) throws -> ResearchBundle? {
        return bundles
            .filter { matches($0.topicSpec, topicSpec) && $0.isAdequate && $0.isValid }
            .sorted { $0.researchedAt > $1.researchedAt }
            .first
    }

    public func getBundle(id: String) throws -> ResearchBundle? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return bundles.first { $0.id == uuid }
    }

    public func saveBundle(_ bundle: ResearchBundle) throws {
        if let index = bundles.firstIndex(where: { $0.id == bundle.id }) {
            bundles[index] = bundle
        } else {
            bundles.append(bundle)
        }
        persist()
    }

    public func hasAdequateResearch(for topicSpec: TopicSpec) throws -> Bool {
        return getLatestAdequateBundle(for: topicSpec) != nil
    }

    // MARK: - Task Management

    public func getPendingResearchTasks(limit: Int = 100) throws -> [ResearchTask] {
        let pending = tasks.filter { $0.status == .pending }
        return Array(pending.prefix(limit))
    }

    public func getPendingResearchTasks() throws -> [ResearchTask] {
        return try getPendingResearchTasks(limit: 100)
    }

    public func saveResearchTask(_ task: ResearchTask) throws {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        persist()
    }

    // MARK: - Debt Task Management

    public func getUnresolvedDebtTasks(limit: Int = 100) throws -> [ResearchDebtTask] {
        let unresolved = debtTasks.filter { $0.resolvedAt == nil }
        return Array(unresolved.prefix(limit))
    }

    public func saveResearchDebtTask(_ task: ResearchDebtTask) throws {
        if let index = debtTasks.firstIndex(where: { $0.id == task.id }) {
            debtTasks[index] = task
        } else {
            debtTasks.append(task)
        }
        persist()
    }

    // MARK: - Statistics

    public func getStatistics() throws -> ResearchRegistryStats {
        return ResearchRegistryStats(
            totalBundles: bundles.count,
            adequateBundles: bundles.filter { $0.isAdequate && $0.isValid }.count,
            pendingTasks: tasks.filter { $0.status == .pending }.count,
            debtTasks: debtTasks.filter { $0.resolvedAt == nil }.count
        )
    }

    private func matches(_ lhs: TopicSpec, _ rhs: TopicSpec) -> Bool {
        lhs.moduleName == rhs.moduleName && lhs.purpose == rhs.purpose
    }

    private func loadIfNeeded() {
        guard dbPath != ":memory:" else { return }
        let url = storageURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(ResearchRegistrySnapshot.self, from: data)
        else {
            return
        }
        bundles = snapshot.bundles
        tasks = snapshot.tasks
        debtTasks = snapshot.debtTasks
    }

    private func persist() {
        guard dbPath != ":memory:" else { return }
        let url = storageURL()
        let snapshot = ResearchRegistrySnapshot(
            bundles: bundles,
            tasks: tasks,
            debtTasks: debtTasks
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(snapshot) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    private func storageURL() -> URL {
        let base = URL(fileURLWithPath: dbPath)
        if base.pathExtension == "json" {
            return base
        }
        return base.appendingPathComponent("research_registry.json")
    }
}

private struct ResearchRegistrySnapshot: Codable {
    let bundles: [ResearchBundle]
    let tasks: [ResearchTask]
    let debtTasks: [ResearchDebtTask]
}

/// Statistics for research registry.
public struct ResearchRegistryStats: Sendable, Codable {
    public let totalBundles: Int
    public let adequateBundles: Int
    public let pendingTasks: Int
    public let debtTasks: Int

    public init(totalBundles: Int, adequateBundles: Int, pendingTasks: Int, debtTasks: Int) {
        self.totalBundles = totalBundles
        self.adequateBundles = adequateBundles
        self.pendingTasks = pendingTasks
        self.debtTasks = debtTasks
    }
}
