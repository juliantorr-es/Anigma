import AnigmaPrimitives

import AnigmaPrimitives

import ContractsCore

//
//  HarmoniaSurface.swift
//  HarmoniaSurface
//
//  [Brief description of file purpose]
//

import AnigmaCore
import ArgumentParser
import Foundation
    case reasoner
    case oracle
}

public struct ConcurrencyLimits: Sendable {
    public let chat: Int
    public let reasoner: Int
    public let oracle: Int

    public static let `default` = ConcurrencyLimits(chat: 3, reasoner: 2, oracle: 1)

    public init(chat: Int, reasoner: Int, oracle: Int) {
        self.chat = max(1, chat)
        self.reasoner = max(1, reasoner)
        self.oracle = max(1, oracle)
    }

    public func limit(for kind: ModelKind) -> Int {
        switch kind {
        case .chat: return chat
        case .reasoner: return reasoner
        case .oracle: return oracle
        }
    }
}

public struct ConcurrencyStats: Sendable {
    public let inFlight: [ModelKind: Int]
    public let limits: [ModelKind: Int]
    public let waiting: [ModelKind: Int]
}

public actor ConcurrencyController {
    private var limits: [ModelKind: Int]
    private var inFlight: [ModelKind: Int]
    private var waiting: [ModelKind: Int]

    public init(limits: ConcurrencyLimits = .default) {
        self.limits = [:]
        self.inFlight = [:]
        self.waiting = [:]

        for kind in ModelKind.allCases {
            self.limits[kind] = limits.limit(for: kind)
            self.inFlight[kind] = 0
            self.waiting[kind] = 0
        }
    }

    public func recordRequest(_ kind: ModelKind) {
        inFlight[kind, default: 0] += 1
    }

    public func stats() -> ConcurrencyStats {
        ConcurrencyStats(inFlight: inFlight, limits: limits, waiting: waiting)
    }
}

public struct RequestPhase: RawRepresentable, Sendable, Codable, CaseIterable, Hashable {
    public typealias AllCases = [RequestPhase]
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let queued = RequestPhase(rawValue: "queued")
    public static let processing = RequestPhase(rawValue: "processing")
    public static let completed = RequestPhase(rawValue: "completed")
    public static let failed = RequestPhase(rawValue: "failed")

    public static var allCases: [RequestPhase] {
        [.queued, .processing, .completed, .failed]
    }
}

public struct SessionComponent: Component, Sendable, Codable {
    public let sessionId: String
    public let userId: String
    public var createdAt: Date
    public init(sessionId: String, userId: String, createdAt: Date = Date()) {
        self.sessionId = sessionId
        self.userId = userId
        self.createdAt = createdAt
    }
}

public struct RequestComponent: Component, Sendable, Codable {
    public let requestId: String
    public let modelKind: ModelKind
    public let sessionId: String
    public var phase: RequestPhase
    public var estimatedTokens: Int
    public init(
        requestId: String,
        modelKind: ModelKind,
        sessionId: String,
        phase: RequestPhase = .queued,
        estimatedTokens: Int = 0
    ) {
        self.requestId = requestId
        self.modelKind = modelKind
        self.sessionId = sessionId
        self.phase = phase
        self.estimatedTokens = estimatedTokens
    }
}

public struct ConcurrencyStateComponent: Component, Sendable, Codable {
    public let modelKind: String
    public var limit: Int
    public var inFlight: Int
    public var waiting: Int
    public var lastUpdated: Date

    public init(
        modelKind: String,
        limit: Int,
        inFlight: Int = 0,
        waiting: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.modelKind = modelKind
        self.limit = limit
        self.inFlight = inFlight
        self.waiting = waiting
        self.lastUpdated = lastUpdated
    }

    public var pressure: String {
        if waiting > limit {
            return "critical"
        } else if inFlight >= limit && waiting > 0 {
            return "high"
        } else if Double(inFlight) / Double(max(1, limit)) > 0.7 {
            return "medium"
        } else {
            return "low"
        }
    }
}

public struct SlotManagementSystem: System {
    public let name = "SlotManagementSystem"
    private let controller: ConcurrencyController

    public init(controller: ConcurrencyController) {
        self.controller = controller
    }

    public func update(world: World) async {
        let stats = await controller.stats()

        for kind in ModelKind.allCases {
            let limit = stats.limits[kind] ?? 0
            let inFlight = stats.inFlight[kind] ?? 0
            let waiting = stats.waiting[kind] ?? 0

            let existing = await world.query(ConcurrencyStateComponent.self)
            if let stateEntry = existing.first(where: { $0.1.modelKind == kind.rawValue }) {
                let entity = stateEntry.0
                var state = stateEntry.1
                state.limit = limit
                state.inFlight = inFlight
                state.waiting = waiting
                state.lastUpdated = Date()
                await world.addComponent(entity, state)
            } else {
                let entity = await world.createEntity()
                let state = ConcurrencyStateComponent(
                    modelKind: kind.rawValue,
                    limit: limit,
                    inFlight: inFlight,
                    waiting: waiting,
                    lastUpdated: Date()
                )
                await world.addComponent(entity, state)
                await world.addComponent(
                    entity,
                    NameComponent(
                        name: "concurrency.\(kind.rawValue)",
                        displayName: "\(kind.rawValue.capitalized) Pool"
                    ))
            }
        }
    }
}

// MARK: - Reporting Types

struct SurfaceReport: Encodable {
    let timestamp: String
    let ticksRun: Int
    let registeredSystems: [String]
    let sessionCount: Int
    let requestCount: Int
    let requestPhaseCounts: [String: Int]
    let concurrencyStates: [ConcurrencyStateSummary]
    let controllerStats: [ControllerStatsSummary]
}

struct ConcurrencyStateSummary: Encodable {
    let modelKind: String
    let limit: Int
    let inFlight: Int
    let waiting: Int
    let pressure: String
}

struct ControllerStatsSummary: Encodable {
    let modelKind: String
    let limit: Int
    let inFlight: Int
    let waiting: Int
}

// MARK: - Harness Command

@main
struct HarmoniaSurface: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "harmonia-surface",
        abstract: "Smoke harness that proves the slot/session/request surface."
    )

    @Option(name: [.short, .long], help: "Number of update ticks to execute.")
    var ticks: Int = 1

    @Option(name: [.long], help: "Surface scenario to run (e.g., ml-worker-backends).")
    var scenario: String?

    @Option(
        name: [.long],
        help:
            "Output path for scenario report (defaults to .anigma/receipts/ml-worker-backends.json)."
    )
    var output: String?

    func run() async throws {
        if let scenario, scenario == "ml-worker-backends" {
            let report = await MLWorkerBackendsScenario().run()
            let path = URL(fileURLWithPath: output ?? ".anigma/receipts/ml-worker-backends.json")
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try data.write(to: path)
            print(
                "Surface scenario \(scenario) wrote report to \(path.path) with \(report.results.count) checks."
            )
            return
        }

        let world = World()
        let controller = ConcurrencyController(limits: .default)
        await world.registerSystem(SlotManagementSystem(controller: controller))

        let session = SessionComponent(sessionId: "sigma-session", userId: "sigma-user")
        let sessionEntity = await world.createEntity()
        await world.addComponent(sessionEntity, session)

        let request = RequestComponent(
            requestId: UUID().uuidString,
            modelKind: .chat,
            sessionId: session.sessionId,
            phase: .completed,
            estimatedTokens: 32
        )
        let requestEntity = await world.createEntity()
        await world.addComponent(requestEntity, request)

        await controller.recordRequest(.chat)

        let totalTicks = max(1, ticks)
        for _ in 0..<totalTicks {
            await world.update()
        }

        let registeredSystems = await world.registeredSystemNames()
        let sessionEntities = await world.query(SessionComponent.self)
        let requestEntities = await world.query(RequestComponent.self)
        let requestPhaseCounts = Dictionary(
            grouping: requestEntities.map { $0.1.phase.rawValue }
        )            { $0 }.mapValues { $0.count }

        let concurrencyComponents = await world.query(ConcurrencyStateComponent.self)
        let controllerStats = await controller.stats()

        let concurrencySummary = concurrencyComponents.map {
            ConcurrencyStateSummary(
                modelKind: $0.1.modelKind,
                limit: $0.1.limit,
                inFlight: $0.1.inFlight,
                waiting: $0.1.waiting,
                pressure: $0.1.pressure
            )
        }

        let controllerSummary = ModelKind.allCases.map { kind in
            ControllerStatsSummary(
                modelKind: kind.rawValue,
                limit: controllerStats.limits[kind] ?? 0,
                inFlight: controllerStats.inFlight[kind] ?? 0,
                waiting: controllerStats.waiting[kind] ?? 0
            )
        }

        let report = SurfaceReport(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            ticksRun: totalTicks,
            registeredSystems: registeredSystems,
            sessionCount: sessionEntities.count,
            requestCount: requestEntities.count,
            requestPhaseCounts: requestPhaseCounts,
            concurrencyStates: concurrencySummary,
            controllerStats: controllerSummary
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        guard let output = String(data: data, encoding: .utf8) else {
            throw HarnessError.encodingFailed
        }

        print(output)
    }
}

enum HarnessError: Error, LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "Unable to format harness report."
    }
}
