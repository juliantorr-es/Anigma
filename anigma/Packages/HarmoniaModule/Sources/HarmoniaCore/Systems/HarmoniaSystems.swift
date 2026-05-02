//
//  HarmoniaSystems.swift
//  HarmoniaModule
//
//  Minimal orchestration systems running on the canonical Harmonia components.
//  Focus: concurrency, metrics, health, and cleanup to make Themis receipts tangible.
//

@preconcurrency import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import TelemetryCore

private struct HarmoniaTelemetryContext {
    let telemetry: TelemetryClient?

    init(telemetry: TelemetryClient? = nil) {
        self.telemetry = telemetry
    }

    func record(
        eventType: ContractsCore.AuditEventType, metrics: [String: Double], dimensions: [String: String] = [:]
    ) async {
        guard let telemetry else { return }

        var values: [String: TelemetryValue] = [
            "event_type": .hashedToken(TelemetryHash(input: eventType.rawValue))
        ]

        for (key, value) in metrics {
            values[key] = .double(value)
        }

        _ = await telemetry.emit(
            category: .workflow,
            name: "harmonia_system_event",
            privacyClassification: .internal,
            values: values
        )
    }
}

private struct HarmoniaTransparencyContext {
    init(builder _: Any? = nil) {}

    func addNode(
        id: String, type: String, name: String, metadata: [String: String] = [:]
    ) async {
    }
}

// MARK: - Concurrency Sync

/// Derives aggregate concurrency state from active requests.
public struct ConcurrencySyncSystem: System {
    public var name: String { "Harmonia.ConcurrencySync" }

    private let defaultLimit: Int
    private let telemetry: HarmoniaTelemetryContext
    private let transparency: HarmoniaTransparencyContext

    public init(
        defaultLimit: Int = 4,
        telemetryClient: TelemetryClient? = nil,
        transparencyBuilder: Any? = nil
    ) {
        self.defaultLimit = defaultLimit
        self.telemetry = HarmoniaTelemetryContext(telemetry: telemetryClient)
        self.transparency = HarmoniaTransparencyContext(builder: transparencyBuilder)
    }

    public func update(world: World) async {
        let requests = await world.query(RequestComponent.self)

        var perKind: [ModelKind: (inFlight: Int, waiting: Int)] = [:]
        for (_, request) in requests {
            guard let kind = ModelKind(rawValue: request.modelKind) else { continue }
            var entry = perKind[kind] ?? (0, 0)
            if request.phase == .queued {
                entry.waiting += 1
            }
            if request.phase.isActive {
                entry.inFlight += 1
            }
            perKind[kind] = entry
        }

        let existingStates = await world.query(ConcurrencyStateComponent.self)
        let now = Date()

        for (kind, counts) in perKind {
            let current = existingStates.first { $0.1.modelKind == kind.rawValue }
            let limit = current?.1.limit ?? defaultLimit
            let state = ConcurrencyStateComponent(
                modelKind: kind.rawValue,
                limit: limit,
                inFlight: counts.inFlight,
                waiting: counts.waiting,
                lastUpdated: now
            )

            if let (entity, _) = current {
                await world.addComponent(entity, state)
            } else {
                let entity = await world.createEntity()
                await world.addComponent(entity, state)
                await world.addComponent(
                    entity,
                    NameComponent(
                        name: "concurrency.\(kind.rawValue)",
                        displayName: "\(kind.displayName) Pool"
                    ))
                await world.addComponent(entity, TagComponent("concurrency", "pool"))
            }

            await transparency.addNode(
                id: "harmonia.concurrency.\(kind.rawValue)",
                type: "telemetry",
                name: "Concurrency \(kind.displayName)",
                metadata: [
                    "limit": "\(state.limit)",
                    "in_flight": "\(state.inFlight)",
                    "waiting": "\(state.waiting)"
                ]
            )
        }

        await telemetry.record(
            eventType: .custom,
            metrics: ["kinds": Double(perKind.count)],
            dimensions: ["kinds": perKind.keys.map(\.rawValue).joined(separator: ",")]
        )
    }
}

// MARK: - Metrics Aggregation

/// Aggregates request outcomes into MetricsComponent per model kind.
public struct MetricsAggregationSystem: System {
    public var name: String { "Harmonia.MetricsAggregation" }

    private let telemetry: HarmoniaTelemetryContext
    private let transparency: HarmoniaTransparencyContext

    public init(
        telemetryClient: TelemetryClient? = nil,
        transparencyBuilder: Any? = nil
    ) {
        self.telemetry = HarmoniaTelemetryContext(telemetry: telemetryClient)
        self.transparency = HarmoniaTransparencyContext(builder: transparencyBuilder)
    }

    public func update(world: World) async {
        let requests = await world.query(RequestComponent.self)
        let existingMetrics = await world.query(MetricsComponent.self)
        let now = Date()

        var aggregates: [ModelKind: (completed: Int, failed: Int, latency: Int64, tokens: Int)] =
            [:]

        for (_, request) in requests {
            guard let kind = ModelKind(rawValue: request.modelKind) else { continue }
            var entry = aggregates[kind] ?? (0, 0, 0, 0)
            switch request.phase {
            case .completed:
                entry.completed += 1
                entry.latency += Int64(request.elapsed * 1000)
            case .failed:
                entry.failed += 1
            default:
                break
            }
            entry.tokens += request.estimatedTokens
            aggregates[kind] = entry
        }

        for (kind, data) in aggregates {
            let current = existingMetrics.first { $0.1.modelKind == kind.rawValue }

            if let (entity, metrics) = current {
                var updated = metrics
                updated.completedCount += data.completed
                updated.failedCount += data.failed
                updated.totalLatencyMs += data.latency
                updated.tokensProcessed += data.tokens
                updated.lastUpdated = now
                await world.addComponent(entity, updated)
            } else {
                let entity = await world.createEntity()
                let metrics = MetricsComponent(
                    modelKind: kind.rawValue,
                    completedCount: data.completed,
                    failedCount: data.failed,
                    totalLatencyMs: data.latency,
                    tokensProcessed: data.tokens,
                    lastUpdated: now
                )
                await world.addComponent(entity, metrics)
                await world.addComponent(
                    entity,
                    NameComponent(
                        name: "metrics.\(kind.rawValue)",
                        displayName: "\(kind.displayName) Metrics"
                    ))
                await world.addComponent(entity, TagComponent("metrics"))
            }

            await transparency.addNode(
                id: "harmonia.metrics.\(kind.rawValue)",
                type: "telemetry",
                name: "Metrics \(kind.displayName)",
                metadata: [
                    "completed": "\(data.completed)",
                    "failed": "\(data.failed)"
                ]
            )
        }

        let totalCompleted = aggregates.values.reduce(0) { $0 + $1.completed }
        let totalFailed = aggregates.values.reduce(0) { $0 + $1.failed }
        await telemetry.record(
            eventType: .custom,
            metrics: [
                "completed": Double(totalCompleted),
                "failed": Double(totalFailed)
            ]
        )
    }
}

// MARK: - Health

/// Flags concurrency pools that are under pressure.
public struct HealthCheckSystem: System {
    public var name: String { "Harmonia.HealthCheck" }

    private let telemetry: HarmoniaTelemetryContext
    private let transparency: HarmoniaTransparencyContext

    public init(
        telemetryClient: TelemetryClient? = nil,
        transparencyBuilder: Any? = nil
    ) {
        self.telemetry = HarmoniaTelemetryContext(telemetry: telemetryClient)
        self.transparency = HarmoniaTransparencyContext(builder: transparencyBuilder)
    }

    public func update(world: World) async {
        let states = await world.query(ConcurrencyStateComponent.self)

        for (entity, state) in states {
            let status: HealthStatus
            let message: String?

            switch state.pressure {
            case .critical:
                status = .unhealthy
                message = "Pool under critical pressure: waiting \(state.waiting)"
            case .high:
                status = .degraded
                message = "Pool under high pressure: waiting \(state.waiting)"
            case .medium:
                status = .healthy
                message = "Utilization \(Int(state.utilization * 100))%"
            case .low:
                status = .healthy
                message = nil
            }

            let kind = ModelKind(rawValue: state.modelKind) ?? .reasoner

            await transparency.addNode(
                id: "harmonia.health.\(kind.rawValue)",
                type: "telemetry",
                name: "Health \(kind.displayName)",
                metadata: [
                    "status": status.rawValue,
                    "message": message ?? ""
                ]
            )
        }

        let pressureCounts = Dictionary(grouping: states.map { $0.1.pressure }) { $0 }
            .reduce(into: [String: Double]()) { partial, entry in
                partial[entry.key.rawValue] = Double(entry.value.count)
            }
        await telemetry.record(
            eventType: .custom,
            metrics: pressureCounts
        )
    }
}

// MARK: - Cleanup

/// Removes completed/failed requests after a grace period.
public struct RequestCleanupSystem: System {
    public var name: String { "Harmonia.RequestCleanup" }

    private let maxAge: TimeInterval

    public init(maxAge: TimeInterval = 120) {
        self.maxAge = maxAge
    }

    public func update(world: World) async {
        let requests = await world.query(RequestComponent.self)

        for (entity, request) in requests {
            guard request.phase.isTerminal else { continue }
            if request.elapsed > maxAge {
                await world.destroyEntity(entity)
            }
        }
    }
}

/// Removes idle sessions.
public struct SessionCleanupSystem: System {
    public var name: String { "Harmonia.SessionCleanup" }

    private let maxIdleTime: TimeInterval

    public init(maxIdleTime: TimeInterval = 3_600) {
        self.maxIdleTime = maxIdleTime
    }

    public func update(world: World) async {
        let sessions = await world.query(ContractsCore.SessionComponent.self)

        for (entity, session) in sessions {
            if session.idleTime > maxIdleTime {
                await world.destroyEntity(entity)
            }
        }
    }
}

// MARK: - Slot Timeout

/// Marks slots that have been occupied too long.
public struct SlotTimeoutSystem: System {
    public var name: String { "Harmonia.SlotTimeout" }

    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 300) {
        self.timeout = timeout
    }

    public func update(world: World) async {
        let slots = await world.query(SlotComponent.self)
        let now = Date()

        for (entity, slot) in slots {
            guard slot.status == .occupied, let acquiredAt = slot.acquiredAt else { continue }

            if now.timeIntervalSince(acquiredAt) > timeout {
                var updated = slot
                updated.status = .releasing
                await world.addComponent(entity, updated)

                _ = ModelKind(rawValue: slot.modelKind) ?? .reasoner
            }
        }
    }
}

extension ModelKind {
    fileprivate var displayName: String {
        rawValue.capitalized
    }
}

extension RequestComponent.RequestPhase {
    fileprivate var isActive: Bool {
        switch self {
        case .active:
            return true
        default:
            return false
        }
    }

    fileprivate var isTerminal: Bool {
        self == .completed || self == .failed
    }
}
