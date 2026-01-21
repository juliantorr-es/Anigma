//
//  HarmoniaSystems.swift
//  HarmoniaModule
//
//  Minimal orchestration systems running on the canonical Harmonia components.
//  Focus: concurrency, metrics, health, and cleanup to make Themis receipts tangible.
//

import AnigmaCore
import ContractsCore
import Foundation
import AnigmaPrimitives
import TelemetryCore

private struct HarmoniaTelemetryContext {
    let telemetry: TelemetryClient?

    init(telemetry: TelemetryClient? = nil) {
        self.telemetry = telemetry
    }

    func record(
        eventType: AuditEventType, metrics: [String: Double], dimensions: [String: String] = [:]
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
    let builder: DataFlowBuilder?

    func addNode(
        id: String, type: DataFlowNode.NodeType, name: String, metadata: [String: String] = [:]
    ) async {
        guard let builder else { return }
        await builder.addNode(DataFlowNode(id: id, type: type, name: name, metadata: metadata))
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
        transparencyBuilder: DataFlowBuilder? = nil
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
                type: .telemetry,
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
        transparencyBuilder: DataFlowBuilder? = nil
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
                updated.totalTokensInput += data.tokens
                updated.lastUpdated = now
                await world.addComponent(entity, updated)
            } else {
                let entity = await world.createEntity()
                let metrics = MetricsComponent(
                    modelKind: kind.rawValue,
                    completedCount: data.completed,
                    failedCount: data.failed,
                    totalLatencyMs: data.latency,
                    totalTokensInput: data.tokens,
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
                type: .telemetry,
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
        transparencyBuilder: DataFlowBuilder? = nil
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
            let health = HealthComponent(
                subsystem: "concurrency.\(kind.rawValue)",
                status: status,
                message: message,
                lastCheck: Date(),
                consecutiveFailures: status == .healthy ? 0 : 1
            )

            await world.addComponent(entity, health)

            await transparency.addNode(
                id: "harmonia.health.\(kind.rawValue)",
                type: .telemetry,
                name: "Health \(kind.displayName)",
                metadata: [
                    "status": health.status.rawValue,
                    "message": health.message ?? ""
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

// MARK: - Throughput Sampling

/// Periodically snapshots metrics into throughput samples.
public struct ThroughputSamplingSystem: System {
    public var name: String { "Harmonia.ThroughputSampling" }

    private let maxSamplesPerKind: Int

    public init(maxSamplesPerKind: Int = 120) {
        self.maxSamplesPerKind = maxSamplesPerKind
    }

    public func update(world: World) async {
        let metrics = await world.query(MetricsComponent.self)
        let now = Date()

        for (_, metric) in metrics {
            let sample = ThroughputSampleComponent(
                modelKind: metric.modelKind,
                timestamp: now,
                requestsCompleted: metric.completedCount,
                tokensProcessed: metric.totalTokensInput + metric.totalTokensOutput,
                avgLatencyMs: metric.avgLatencyMs
            )

            let entity = await world.createEntity()
            await world.addComponent(entity, sample)
            await world.addComponent(entity, TimestampComponent())
            await world.addComponent(entity, TagComponent("sample", "throughput", metric.modelKind))
        }

        // Trim old samples to keep memory bounded.
        let samples = await world.query(ThroughputSampleComponent.self, TimestampComponent.self)
        var samplesByKind:
            [ModelKind: [(EntityId, ThroughputSampleComponent, TimestampComponent)]] = [:]
        for (entity, sample, ts) in samples {
            guard let kind = ModelKind(rawValue: sample.modelKind) else { continue }
            samplesByKind[kind, default: []].append((entity, sample, ts))
        }

        for (_, entries) in samplesByKind {
            if entries.count <= maxSamplesPerKind { continue }
            let sorted = entries.sorted { $0.2.createdAt > $1.2.createdAt }
            for (entity, _, _) in sorted.dropFirst(maxSamplesPerKind) {
                await world.destroyEntity(entity)
            }
        }
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
        let sessions = await world.query(SessionComponent.self)

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

                let kind = ModelKind(rawValue: slot.modelKind) ?? .reasoner
                let health = HealthComponent(
                    subsystem: "slot.\(kind.rawValue)",
                    status: .degraded,
                    message: "Slot timed out after \(Int(timeout))s",
                    lastCheck: now,
                    consecutiveFailures: 1
                )
                await world.addComponent(entity, health)
            }
        }
    }
}

extension ModelKind {
    fileprivate var displayName: String {
        rawValue.capitalized
    }
}

extension RequestPhase {
    fileprivate var isActive: Bool {
        switch self {
        case .acquiringSlot, .processing, .synthesizing:
            return true
        default:
            return false
        }
    }

    fileprivate var isTerminal: Bool {
        self == .completed || self == .failed
    }
}
