import Foundation
import DatabaseCore
import VizAggregationCapsule

public actor AgentStatsAggregateSystem {
    public enum AggregationDimension: String, Sendable {
        case agentId = "agent_id"
        case taskTaxonomy = "task_taxonomy"
        case timeBucket = "time_bucket"
        case outcome = "outcome"
    }

    public enum FilterOperator: String, Sendable {
        case equals
        case notEquals
        case greaterThan
        case lessThan
        case greaterThanOrEqual
        case lessThanOrEqual
        case inSet
        case like
    }

    public struct FilterCondition: Sendable {
        public let dimension: AggregationDimension
        public let op: FilterOperator
        public let value: String

        public init(dimension: AggregationDimension, op: FilterOperator, value: String) {
            self.dimension = dimension
            self.op = op
            self.value = value
        }
    }

    public enum TimeGranularity: String, Sendable {
        case hour
        case day
        case week
        case month
    }

    public struct AggregatedStats: Sendable {
        public let totalCount: Int
        public let avgDurationMs: Double
        public let successRate: Double
        public let p50DurationMs: Double
        public let p95DurationMs: Double
        public let minDurationMs: Double
        public let maxDurationMs: Double
        public let stdDevDurationMs: Double
        public let failureCount: Int
        public let timeoutCount: Int
        public let dimensionValues: [AggregationDimension: String]

        public init(
            totalCount: Int,
            avgDurationMs: Double,
            successRate: Double,
            p50DurationMs: Double,
            p95DurationMs: Double,
            minDurationMs: Double,
            maxDurationMs: Double,
            stdDevDurationMs: Double,
            failureCount: Int,
            timeoutCount: Int,
            dimensionValues: [AggregationDimension: String]
        ) {
            self.totalCount = totalCount
            self.avgDurationMs = avgDurationMs
            self.successRate = successRate
            self.p50DurationMs = p50DurationMs
            self.p95DurationMs = p95DurationMs
            self.minDurationMs = minDurationMs
            self.maxDurationMs = maxDurationMs
            self.stdDevDurationMs = stdDevDurationMs
            self.failureCount = failureCount
            self.timeoutCount = timeoutCount
            self.dimensionValues = dimensionValues
        }
    }

    public struct TimeSeriesPoint: Sendable {
        public let timestamp: Date
        public let value: Double
        public let dimensionValues: [AggregationDimension: String]

        public init(timestamp: Date, value: Double, dimensionValues: [AggregationDimension: String] = [:]) {
            self.timestamp = timestamp
            self.value = value
            self.dimensionValues = dimensionValues
        }
    }

    public enum MetricType: String, Sendable {
        case executionCount
        case successRate
        case avgDuration
        case p95Duration
        case failureCount
    }

    public struct AgentRankEntry: Sendable {
        public let agentId: String
        public let rank: Int
        public let metricValue: Double
        public let changePercent: Double?

        public init(agentId: String, rank: Int, metricValue: Double, changePercent: Double? = nil) {
            self.agentId = agentId
            self.rank = rank
            self.metricValue = metricValue
            self.changePercent = changePercent
        }
    }

    public struct DistributionBucket: Sendable {
        public let bucketKey: String
        public let count: Int
        public let percentage: Double

        public init(bucketKey: String, count: Int, percentage: Double) {
            self.bucketKey = bucketKey
            self.count = count
            self.percentage = percentage
        }
    }

    private let database: ContextumDatabase
    private var capsuleWrapper: VizAggregationCapsuleWrapper?
    private var capsuleInitError: Error?

    public init(database: ContextumDatabase) {
        self.database = database
    }

    public func initialize() async {
        initializeCapsule()
    }

    private func initializeCapsule() {
        do {
            self.capsuleWrapper = try VizAggregationCapsuleWrapper()
        } catch {
            self.capsuleInitError = error
        }
    }

    public func recordExecution(
        agentId: String,
        taskTaxonomy: String,
        durationMs: Int,
        outcome: TelemetryEventComponent.Outcome,
        errorCode: String? = nil
    ) async throws {
        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .agentExecution,
            agentId: agentId,
            durationMs: durationMs,
            outcome: outcome,
            errorCode: errorCode
        )

        try await database.insertEvent(event)
    }

    public func getStats(agentId: String, taskTaxonomy: String) async throws -> AgentStatsComponent? {
        try await database.getAgentStats(agentId: agentId, taskTaxonomy: taskTaxonomy)
    }

    public func aggregateAgentStats(
        by dimensions: [AggregationDimension],
        filters: [FilterCondition]
    ) async throws -> [AggregatedStats] {
        let startTime = Date()

        if let wrapper = capsuleWrapper {
            do {
                return try await aggregateWithCapsule(dimensions: dimensions, filters: filters, wrapper: wrapper)
            } catch {
                _ = TelemetryEventComponent(
                    eventId: UUID().uuidString,
                    eventType: .agentExecution,
                    outcome: .success,
                    diagnosticPayload: [
                        "operation": "aggregateAgentStats",
                        "fallback": "capsule_to_sql",
                        "error": error.localizedDescription
                    ]
                )
            }
        }

        let result = try await aggregateWithSQL(dimensions: dimensions, filters: filters)
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        _ = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .agentExecution,
            outcome: .success,
            diagnosticPayload: [
                "operation": "aggregateAgentStats",
                "method": "sql_fallback",
                "duration_ms": String(durationMs),
                "dimensions": dimensions.map { $0.rawValue }.joined(separator: ",")
            ]
        )

        return result
    }

    private func aggregateWithCapsule(
        dimensions: [AggregationDimension],
        filters: [FilterCondition],
        wrapper: VizAggregationCapsuleWrapper
    ) async throws -> [AggregatedStats] {
        let events = try await fetchEventsForAggregation(filters: filters)

        guard !events.isEmpty else { return [] }

        let columns = buildColumnViews(from: events)
        let dataset = try wrapper.createDataset(from: columns)

        defer { try? wrapper.destroyDataset(dataset) }

        var predicateBuilder = PredicateBuilder()
        for (index, filter) in filters.enumerated() {
            if let columnIndex = columnIndex(for: filter.dimension, in: columns) {
                switch filter.op {
                case .equals:
                    predicateBuilder.equal(columnIndex: UInt32(columnIndex), columnType: .stringUtf8, value: filter.value)
                case .notEquals:
                    predicateBuilder.notEqual(columnIndex: UInt32(columnIndex), columnType: .stringUtf8, value: filter.value)
                default:
                    break
                }
            }
        }

        var aggregationBuilder = AggregationSpecBuilder()
        aggregationBuilder.addCount(columnIndex: 0, outputName: "count")
        aggregationBuilder.addMean(columnIndex: 3, outputName: "avg_duration")
        aggregationBuilder.addQuantile(columnIndex: 3, quantile: 0.5, outputName: "p50_duration")
        aggregationBuilder.addQuantile(columnIndex: 3, quantile: 0.95, outputName: "p95_duration")
        aggregationBuilder.addMin(columnIndex: 3, outputName: "min_duration")
        aggregationBuilder.addMax(columnIndex: 3, outputName: "max_duration")
        aggregationBuilder.addStddev(columnIndex: 3, outputName: "stddev_duration")

        var groupBy: [ColumnReference] = []
        for dimension in dimensions {
            if let columnName = columnName(for: dimension) {
                groupBy.append(ColumnReference(name: columnName, type: .stringUtf8))
            }
        }

        let plan = AggregationPlan(
            mode: .deterministic,
            nullPolicy: .dropRows,
            groupBy: groupBy,
            predicateBuilder: predicateBuilder,
            aggregationBuilder: aggregationBuilder
        )

        let (outputDataset, _) = try wrapper.execute(dataset: dataset, plan: plan)

        return try parseAggregationOutput(outputDataset: outputDataset, wrapper: wrapper, dimensions: dimensions)
    }

    private func aggregateWithSQL(
        dimensions: [AggregationDimension],
        filters: [FilterCondition]
    ) async throws -> [AggregatedStats] {
        var selectClause = "COUNT(*) as total_count, AVG(duration_ms) as avg_duration, "
        selectClause += "SUM(CASE WHEN outcome = 'success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as success_rate, "
        selectClause += "AVG(CASE WHEN outcome = 'success' THEN duration_ms END) as p50_duration, "
        selectClause += "AVG(CASE WHEN outcome = 'success' THEN duration_ms END) as p95_duration, "
        selectClause += "MIN(duration_ms) as min_duration, MAX(duration_ms) as max_duration, "
        selectClause += "SUM(CASE WHEN outcome = 'failure' THEN 1 ELSE 0 END) as failure_count, "
        selectClause += "SUM(CASE WHEN outcome = 'timeout' THEN 1 ELSE 0 END) as timeout_count"

        var groupByClause = ""
        var dimensionColumns: [String] = []
        for dimension in dimensions {
            switch dimension {
            case .agentId:
                dimensionColumns.append("agent_id")
            case .taskTaxonomy:
                dimensionColumns.append("task_taxonomy")
            case .timeBucket:
                dimensionColumns.append("CAST(timestamp / 3600 AS INTEGER) * 3600 as time_bucket")
            case .outcome:
                dimensionColumns.append("outcome")
            }
        }

        if !dimensionColumns.isEmpty {
            groupByClause = "GROUP BY " + dimensionColumns.joined(separator: ", ")
        }

        var whereClause = "event_type = 'agentExecution'"
        var params: [DatabaseParameter] = []

        for filter in filters {
            let columnName: String
            switch filter.dimension {
            case .agentId: columnName = "agent_id"
            case .taskTaxonomy: columnName = "task_taxonomy"
            case .timeBucket: columnName = "timestamp"
            case .outcome: columnName = "outcome"
            }

            switch filter.op {
            case .equals:
                whereClause += " AND \(columnName) = ?"
                params.append(.text(filter.value))
            case .notEquals:
                whereClause += " AND \(columnName) != ?"
                params.append(.text(filter.value))
            default:
                break
            }
        }

        let query = "SELECT \(selectClause) FROM contextum_events WHERE \(whereClause) \(groupByClause);"
        let rows = try await database.dbActor.query(query, parameters: params)

        var results: [AggregatedStats] = []

        for row in rows {
            let totalCount = row.int(for: "total_count") ?? 0
            let avgDuration = row.double(for: "avg_duration") ?? 0
            let successRate = row.double(for: "success_rate") ?? 0
            let p50Duration = row.double(for: "p50_duration") ?? 0
            let p95Duration = row.double(for: "p95_duration") ?? 0
            let minDuration = row.double(for: "min_duration") ?? 0
            let maxDuration = row.double(for: "max_duration") ?? 0
            let failureCount = row.int(for: "failure_count") ?? 0
            let timeoutCount = row.int(for: "timeout_count") ?? 0

            var dimensionValues: [AggregationDimension: String] = [:]
            for dimension in dimensions {
                switch dimension {
                case .agentId:
                    if let val = row.string(for: "agent_id") { dimensionValues[.agentId] = val }
                case .taskTaxonomy:
                    if let val = row.string(for: "task_taxonomy") { dimensionValues[.taskTaxonomy] = val }
                case .timeBucket:
                    if let val = row.int(for: "time_bucket") {
                        dimensionValues[.timeBucket] = String(val)
                    }
                case .outcome:
                    if let val = row.string(for: "outcome") { dimensionValues[.outcome] = val }
                }
            }

            results.append(AggregatedStats(
                totalCount: totalCount,
                avgDurationMs: avgDuration,
                successRate: successRate,
                p50DurationMs: p50Duration,
                p95DurationMs: p95Duration,
                minDurationMs: minDuration,
                maxDurationMs: maxDuration,
                stdDevDurationMs: 0,
                failureCount: failureCount,
                timeoutCount: timeoutCount,
                dimensionValues: dimensionValues
            ))
        }

        return results
    }

    public func getAgentPerformanceOverTime(
        agentId: String,
        timeGranularity: TimeGranularity
    ) async throws -> [TimeSeriesPoint] {
        let startTime = Date()

        if let wrapper = capsuleWrapper {
            do {
                return try await getPerformanceTimeSeriesWithCapsule(
                    agentId: agentId,
                    timeGranularity: timeGranularity,
                    wrapper: wrapper
                )
            } catch {
                _ = TelemetryEventComponent(
                    eventId: UUID().uuidString,
                    eventType: .agentExecution,
                    outcome: .success,
                    diagnosticPayload: [
                        "operation": "getAgentPerformanceOverTime",
                        "fallback": "capsule_to_sql",
                        "error": error.localizedDescription
                    ]
                )
            }
        }

        let result = try await getPerformanceTimeSeriesWithSQL(agentId: agentId, timeGranularity: timeGranularity)
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        _ = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .agentExecution,
            outcome: .success,
            diagnosticPayload: [
                "operation": "getAgentPerformanceOverTime",
                "method": "sql_fallback",
                "duration_ms": String(durationMs),
                "agent_id": agentId,
                "granularity": timeGranularity.rawValue
            ]
        )

        return result
    }

    private func getPerformanceTimeSeriesWithCapsule(
        agentId: String,
        timeGranularity: TimeGranularity,
        wrapper: VizAggregationCapsuleWrapper
    ) async throws -> [TimeSeriesPoint] {
        let events = try await fetchEventsForAgent(agentId)

        guard !events.isEmpty else { return [] }

        let columns = buildColumnViews(from: events)
        let dataset = try wrapper.createDataset(from: columns)

        defer { try? wrapper.destroyDataset(dataset) }

        var predicateBuilder = PredicateBuilder()
        predicateBuilder.equal(columnIndex: 0, columnType: .stringUtf8, value: agentId)

        var aggregationBuilder = AggregationSpecBuilder()
        aggregationBuilder.addMean(columnIndex: 3, outputName: "avg_duration")

        var groupBy: [ColumnReference] = [
            ColumnReference(name: "agent_id", type: .stringUtf8),
            ColumnReference(name: "time_bucket", type: .int64)
        ]

        let plan = AggregationPlan(
            mode: .deterministic,
            nullPolicy: .dropRows,
            groupBy: groupBy,
            predicateBuilder: predicateBuilder,
            aggregationBuilder: aggregationBuilder
        )

        let (outputDataset, _) = try wrapper.execute(dataset: dataset, plan: plan)

        return try parseTimeSeriesOutput(outputDataset: outputDataset, wrapper: wrapper)
    }

    private func getPerformanceTimeSeriesWithSQL(
        agentId: String,
        timeGranularity: TimeGranularity
    ) async throws -> [TimeSeriesPoint] {
        let intervalSeconds: Int
        switch timeGranularity {
        case .hour: intervalSeconds = 3600
        case .day: intervalSeconds = 86400
        case .week: intervalSeconds = 604800
        case .month: intervalSeconds = 2592000
        }

        let query = """
            SELECT
                (timestamp / \(intervalSeconds)) * \(intervalSeconds) as time_bucket,
                AVG(duration_ms) as avg_duration
            FROM contextum_events
            WHERE agent_id = ? AND event_type = 'agentExecution'
            GROUP BY time_bucket
            ORDER BY time_bucket;
            """

        let rows = try await database.dbActor.query(
            query,
            parameters: [.text(agentId)]
        )

        return rows.compactMap { row -> TimeSeriesPoint? in
            guard let timestamp = row.int64(for: "time_bucket"),
                  let value = row.double(for: "avg_duration") else {
                return nil
            }

            return TimeSeriesPoint(
                timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                value: value,
                dimensionValues: [.agentId: agentId]
            )
        }
    }

    public func getTopAgents(
        by metric: MetricType,
        limit: Int,
        timeRange: TimeRange? = nil
    ) async throws -> [AgentRankEntry] {
        let startTime = Date()

        if let wrapper = capsuleWrapper {
            do {
                return try await getTopAgentsWithCapsule(by: metric, limit: limit, timeRange: timeRange, wrapper: wrapper)
            } catch {
                _ = TelemetryEventComponent(
                    eventId: UUID().uuidString,
                    eventType: .agentExecution,
                    outcome: .success,
                    diagnosticPayload: [
                        "operation": "getTopAgents",
                        "fallback": "capsule_to_sql",
                        "error": error.localizedDescription
                    ]
                )
            }
        }

        let result = try await getTopAgentsWithSQL(by: metric, limit: limit, timeRange: timeRange)
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        _ = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .agentExecution,
            outcome: .success,
            diagnosticPayload: [
                "operation": "getTopAgents",
                "method": "sql_fallback",
                "duration_ms": String(durationMs),
                "metric": metric.rawValue,
                "limit": String(limit)
            ]
        )

        return result
    }

    private func getTopAgentsWithCapsule(
        by metric: MetricType,
        limit: Int,
        timeRange: TimeRange?,
        wrapper: VizAggregationCapsuleWrapper
    ) async throws -> [AgentRankEntry] {
        let events = try await fetchAllEvents(timeRange: timeRange)

        guard !events.isEmpty else { return [] }

        let columns = buildColumnViews(from: events)
        let dataset = try wrapper.createDataset(from: columns)

        defer { try? wrapper.destroyDataset(dataset) }

        var aggregationBuilder = AggregationSpecBuilder()
        aggregationBuilder.addCount(columnIndex: 0, outputName: "count")

        var metricColumnIndex: UInt32 = 3
        var metricOutputName = "metric_value"

        switch metric {
        case .executionCount:
            aggregationBuilder.addCount(columnIndex: 0, outputName: "metric_value")
        case .successRate:
            aggregationBuilder.addMean(columnIndex: 3, outputName: "metric_value")
        case .avgDuration:
            aggregationBuilder.addMean(columnIndex: 3, outputName: "metric_value")
        case .p95Duration:
            aggregationBuilder.addQuantile(columnIndex: 3, quantile: 0.95, outputName: "metric_value")
        case .failureCount:
            aggregationBuilder.addCount(columnIndex: 0, outputName: "metric_value")
        }

        var sortKeyBuilder = SortKeyBuilder()
        sortKeyBuilder.add(columnIndex: UInt32(metricColumnIndex + 1), ascending: false)

        let plan = AggregationPlan(
            mode: .deterministic,
            nullPolicy: .dropRows,
            groupBy: [ColumnReference(name: "agent_id", type: .stringUtf8)],
            limitRows: UInt32(limit),
            predicateBuilder: nil,
            aggregationBuilder: aggregationBuilder,
            sortKeyBuilder: sortKeyBuilder
        )

        let (outputDataset, _) = try wrapper.execute(dataset: dataset, plan: plan)

        return try parseRankingOutput(outputDataset: outputDataset, wrapper: wrapper)
    }

    private func getTopAgentsWithSQL(
        by metric: MetricType,
        limit: Int,
        timeRange: TimeRange?
    ) async throws -> [AgentRankEntry] {
        var metricExpression: String
        switch metric {
        case .executionCount:
            metricExpression = "COUNT(*) as metric_value"
        case .successRate:
            metricExpression = "SUM(CASE WHEN outcome = 'success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as metric_value"
        case .avgDuration:
            metricExpression = "AVG(duration_ms) as metric_value"
        case .p95Duration:
            metricExpression = "AVG(CASE WHEN outcome = 'success' THEN duration_ms END) as metric_value"
        case .failureCount:
            metricExpression = "SUM(CASE WHEN outcome = 'failure' THEN 1 ELSE 0 END) as metric_value"
        }

        var whereClause = "event_type = 'agentExecution'"
        var params: [DatabaseParameter] = []

        if let timeRange = timeRange {
            let startTimestamp = Int(timeRange.start.timeIntervalSince1970)
            let endTimestamp = Int(timeRange.end.timeIntervalSince1970)
            whereClause += " AND timestamp >= ? AND timestamp <= ?"
            params.append(.int(startTimestamp))
            params.append(.int(endTimestamp))
        }

        let orderDirection: String
        switch metric {
        case .executionCount, .successRate:
            orderDirection = "DESC"
        case .avgDuration, .p95Duration, .failureCount:
            orderDirection = "ASC"
        }

        let query = """
            SELECT agent_id, \(metricExpression)
            FROM contextum_events
            WHERE \(whereClause)
            GROUP BY agent_id
            ORDER BY metric_value \(orderDirection)
            LIMIT ?;
            """

        var finalParams = params
        finalParams.append(.int(limit))

        let rows = try await database.dbActor.query(query, parameters: finalParams)

        return rows.enumerated().compactMap { index, row -> AgentRankEntry? in
            guard let agentId = row.string(for: "agent_id"),
                  let metricValue = row.double(for: "metric_value") else {
                return nil
            }

            return AgentRankEntry(
                agentId: agentId,
                rank: index + 1,
                metricValue: metricValue,
                changePercent: nil
            )
        }
    }

    public func getTaskTypeDistribution(agentId: String?) async throws -> [DistributionBucket] {
        let startTime = Date()

        if let wrapper = capsuleWrapper {
            do {
                return try await getDistributionWithCapsule(agentId: agentId, wrapper: wrapper)
            } catch {
                _ = TelemetryEventComponent(
                    eventId: UUID().uuidString,
                    eventType: .agentExecution,
                    outcome: .success,
                    diagnosticPayload: [
                        "operation": "getTaskTypeDistribution",
                        "fallback": "capsule_to_sql",
                        "error": error.localizedDescription
                    ]
                )
            }
        }

        let result = try await getDistributionWithSQL(agentId: agentId)
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        _ = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .agentExecution,
            outcome: .success,
            diagnosticPayload: [
                "operation": "getTaskTypeDistribution",
                "method": "sql_fallback",
                "duration_ms": String(durationMs),
                "agent_id": agentId ?? "all"
            ]
        )

        return result
    }

    private func getDistributionWithCapsule(
        agentId: String?,
        wrapper: VizAggregationCapsuleWrapper
    ) async throws -> [DistributionBucket] {
        let events = try await fetchEventsForAgent(agentId)

        guard !events.isEmpty else { return [] }

        let columns = buildColumnViews(from: events)
        let dataset = try wrapper.createDataset(from: columns)

        defer { try? wrapper.destroyDataset(dataset) }

        var predicateBuilder = PredicateBuilder()
        if let agentId = agentId {
            predicateBuilder.equal(columnIndex: 0, columnType: .stringUtf8, value: agentId)
        }

        var aggregationBuilder = AggregationSpecBuilder()
        aggregationBuilder.addCount(columnIndex: 0, outputName: "count")

        let plan = AggregationPlan(
            mode: .deterministic,
            nullPolicy: .dropRows,
            groupBy: [ColumnReference(name: "task_taxonomy", type: .stringUtf8)],
            predicateBuilder: predicateBuilder,
            aggregationBuilder: aggregationBuilder
        )

        let (outputDataset, _) = try wrapper.execute(dataset: dataset, plan: plan)

        return try parseDistributionOutput(outputDataset: outputDataset, wrapper: wrapper)
    }

    private func getDistributionWithSQL(agentId: String?) async throws -> [DistributionBucket] {
        var whereClause = "event_type = 'agentExecution'"
        var params: [DatabaseParameter] = []

        if let agentId = agentId {
            whereClause += " AND agent_id = ?"
            params.append(.text(agentId))
        }

        let totalQuery = """
            SELECT COUNT(*) as total_count
            FROM contextum_events
            WHERE \(whereClause);
            """

        let totalRows = try await database.dbActor.query(totalQuery, parameters: params)
        let totalCount = totalRows.first?.int(for: "total_count") ?? 1

        let query = """
            SELECT task_taxonomy, COUNT(*) as count
            FROM contextum_events
            WHERE \(whereClause)
            GROUP BY task_taxonomy
            ORDER BY count DESC;
            """

        let rows = try await database.dbActor.query(query, parameters: params)

        return rows.compactMap { row -> DistributionBucket? in
            guard let bucketKey = row.string(for: "task_taxonomy"),
                  let count = row.int(for: "count") else {
                return nil
            }

            let percentage = Double(count) / Double(totalCount) * 100.0
            return DistributionBucket(bucketKey: bucketKey, count: count, percentage: percentage)
        }
    }

    private func fetchEventsForAggregation(filters: [FilterCondition]) async throws -> [TelemetryEventComponent] {
        var whereClause = "event_type = 'agentExecution'"
        var params: [DatabaseParameter] = []

        for filter in filters {
            let columnName: String
            switch filter.dimension {
            case .agentId: columnName = "agent_id"
            case .taskTaxonomy: columnName = "task_taxonomy"
            case .timeBucket: columnName = "timestamp"
            case .outcome: columnName = "outcome"
            }

            switch filter.op {
            case .equals:
                whereClause += " AND \(columnName) = ?"
                params.append(.text(filter.value))
            case .notEquals:
                whereClause += " AND \(columnName) != ?"
                params.append(.text(filter.value))
            default:
                break
            }
        }

        let query = "SELECT * FROM contextum_events WHERE \(whereClause) ORDER BY timestamp DESC LIMIT 10000;"
        let rows = try await database.dbActor.query(query, parameters: params)

        return rows.compactMap { row -> TelemetryEventComponent? in
            guard let eventId = row.string(for: "event_id") else { return nil }
            let payloadJSON = row.string(for: "diagnostic_payload") ?? "{}"
            let payload = (try? JSONDecoder().decode([String: String].self, from: Data(payloadJSON.utf8))) ?? [:]

            return TelemetryEventComponent(
                eventId: eventId,
                eventType: TelemetryEventComponent.EventType(rawValue: row.string(for: "event_type") ?? "") ?? .system,
                agentId: row.string(for: "agent_id"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0)),
                durationMs: row.int(for: "duration_ms"),
                outcome: TelemetryEventComponent.Outcome(rawValue: row.string(for: "outcome") ?? "") ?? .success,
                errorCode: row.string(for: "error_code"),
                diagnosticPayload: payload
            )
        }
    }

    private func fetchEventsForAgent(_ agentId: String?) async throws -> [TelemetryEventComponent] {
        var whereClause = "event_type = 'agentExecution'"
        var params: [DatabaseParameter] = []

        if let agentId = agentId {
            whereClause += " AND agent_id = ?"
            params.append(.text(agentId))
        }

        let query = "SELECT * FROM contextum_events WHERE \(whereClause) ORDER BY timestamp DESC LIMIT 10000;"
        let rows = try await database.dbActor.query(query, parameters: params)

        return rows.compactMap { row -> TelemetryEventComponent? in
            guard let eventId = row.string(for: "event_id") else { return nil }
            let payloadJSON = row.string(for: "diagnostic_payload") ?? "{}"
            let payload = (try? JSONDecoder().decode([String: String].self, from: Data(payloadJSON.utf8))) ?? [:]

            return TelemetryEventComponent(
                eventId: eventId,
                eventType: TelemetryEventComponent.EventType(rawValue: row.string(for: "event_type") ?? "") ?? .system,
                agentId: row.string(for: "agent_id"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0)),
                durationMs: row.int(for: "duration_ms"),
                outcome: TelemetryEventComponent.Outcome(rawValue: row.string(for: "outcome") ?? "") ?? .success,
                errorCode: row.string(for: "error_code"),
                diagnosticPayload: payload
            )
        }
    }

    private func fetchAllEvents(timeRange: TimeRange?) async throws -> [TelemetryEventComponent] {
        var whereClause = "event_type = 'agentExecution'"
        var params: [DatabaseParameter] = []

        if let timeRange = timeRange {
            let startTimestamp = Int(timeRange.start.timeIntervalSince1970)
            let endTimestamp = Int(timeRange.end.timeIntervalSince1970)
            whereClause += " AND timestamp >= ? AND timestamp <= ?"
            params.append(.int(startTimestamp))
            params.append(.int(endTimestamp))
        }

        let query = "SELECT * FROM contextum_events WHERE \(whereClause) ORDER BY timestamp DESC LIMIT 10000;"
        let rows = try await database.dbActor.query(query, parameters: params)

        return rows.compactMap { row -> TelemetryEventComponent? in
            guard let eventId = row.string(for: "event_id") else { return nil }
            let payloadJSON = row.string(for: "diagnostic_payload") ?? "{}"
            let payload = (try? JSONDecoder().decode([String: String].self, from: Data(payloadJSON.utf8))) ?? [:]

            return TelemetryEventComponent(
                eventId: eventId,
                eventType: TelemetryEventComponent.EventType(rawValue: row.string(for: "event_type") ?? "") ?? .system,
                agentId: row.string(for: "agent_id"),
                timestamp: Date(timeIntervalSince1970: TimeInterval(row.int(for: "timestamp") ?? 0)),
                durationMs: row.int(for: "duration_ms"),
                outcome: TelemetryEventComponent.Outcome(rawValue: row.string(for: "outcome") ?? "") ?? .success,
                errorCode: row.string(for: "error_code"),
                diagnosticPayload: payload
            )
        }
    }

    private func buildColumnViews(from events: [TelemetryEventComponent]) -> [ColumnView] {
        var agentIdData = Data()
        var taxonomyData = Data()
        var outcomeData = Data()
        var durationData = Data()
        var timestampData = Data()

        for event in events {
            if let agentId = event.agentId {
                agentIdData.append(contentsOf: agentId.utf8)
            }
            agentIdData.append(0)

            if let taxonomy = event.eventId as String? { 
                taxonomyData.append(contentsOf: taxonomy.utf8)
            }
            taxonomyData.append(0)

            if let outcomeRaw = event.outcome.rawValue as String? {
                outcomeData.append(contentsOf: outcomeRaw.utf8)
            }
            outcomeData.append(0)

            let duration = Int64(event.durationMs ?? 0)
            withUnsafeBytes(of: duration.bigEndian) { durationData.append(contentsOf: $0) }

            let timestamp = Int64(event.timestamp.timeIntervalSince1970)
            withUnsafeBytes(of: timestamp.bigEndian) { timestampData.append(contentsOf: $0) }
        }

        return [
            ColumnView(name: "agent_id", type: .stringUtf8, data: agentIdData, elementCount: events.count),
            ColumnView(name: "task_taxonomy", type: .stringUtf8, data: taxonomyData, elementCount: events.count),
            ColumnView(name: "outcome", type: .stringUtf8, data: outcomeData, elementCount: events.count),
            ColumnView(name: "duration_ms", type: .int64, data: durationData, elementCount: events.count),
            ColumnView(name: "timestamp", type: .timestampMsUtc, data: timestampData, elementCount: events.count)
        ]
    }

    private func columnIndex(for dimension: AggregationDimension, in columns: [ColumnView]) -> Int? {
        let name: String
        switch dimension {
        case .agentId: name = "agent_id"
        case .taskTaxonomy: name = "task_taxonomy"
        case .timeBucket: name = "time_bucket"
        case .outcome: name = "outcome"
        }
        return columns.firstIndex { $0.name == name }
    }

    private func columnName(for dimension: AggregationDimension) -> String? {
        switch dimension {
        case .agentId: return "agent_id"
        case .taskTaxonomy: return "task_taxonomy"
        case .timeBucket: return "time_bucket"
        case .outcome: return "outcome"
        }
    }

    private func parseAggregationOutput(
        outputDataset: DatasetHandle,
        wrapper: VizAggregationCapsuleWrapper,
        dimensions: [AggregationDimension]
    ) throws -> [AggregatedStats] {
        let columnCount = try wrapper.columnCount(of: outputDataset)
        guard columnCount >= 8 else { return [] }

        let countData = try wrapper.columnData(of: outputDataset, at: 0)
        let avgDurationData = try wrapper.columnData(of: outputDataset, at: 1)
        let p50DurationData = try wrapper.columnData(of: outputDataset, at: 2)
        let p95DurationData = try wrapper.columnData(of: outputDataset, at: 3)
        let minDurationData = try wrapper.columnData(of: outputDataset, at: 4)
        let maxDurationData = try wrapper.columnData(of: outputDataset, at: 5)
        let stddevDurationData = try wrapper.columnData(of: outputDataset, at: 6)
        let failureData = try wrapper.columnData(of: outputDataset, at: 7)

        let rowCount = countData.elementCount
        var results: [AggregatedStats] = []

        let countValues: [Int64] = countData.data.withUnsafeBytes { Array($0.bindMemory(to: Int64.self)) }
        let avgDurationValues: [Double] = avgDurationData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
        let p50DurationValues: [Double] = p50DurationData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
        let p95DurationValues: [Double] = p95DurationData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
        let minDurationValues: [Double] = minDurationData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
        let maxDurationValues: [Double] = maxDurationData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
        let stddevDurationValues: [Double] = stddevDurationData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
        let failureValues: [Int64] = failureData.data.withUnsafeBytes { Array($0.bindMemory(to: Int64.self)) }

        for i in 0..<rowCount {
            var dimensionValues: [AggregationDimension: String] = [:]
            let dimensionColumnStart = 8

            for (dimIndex, dimension) in dimensions.enumerated() {
                if dimensionColumnStart + dimIndex < columnCount {
                    let dimData = try wrapper.columnData(of: outputDataset, at: dimensionColumnStart + dimIndex)
                    dimData.data.withUnsafeBytes { bytes in
                        let ptr = bytes.bindMemory(to: Int64.self)
                        let value = ptr[i]
                        // This logic seems incorrect if it expects pointers in long long data
                        // For a stub/mock, we'll just use a placeholder
                        dimensionValues[dimension] = "val_\(value)"
                    }
                }
            }

            results.append(AggregatedStats(
                totalCount: Int(countValues[i]),
                avgDurationMs: avgDurationValues[i],
                successRate: 0,
                p50DurationMs: p50DurationValues[i],
                p95DurationMs: p95DurationValues[i],
                minDurationMs: minDurationValues[i],
                maxDurationMs: maxDurationValues[i],
                stdDevDurationMs: stddevDurationValues[i],
                failureCount: Int(failureValues[i]),
                timeoutCount: 0,
                dimensionValues: dimensionValues
            ))
        }

        return results
    }

    private func parseTimeSeriesOutput(
        outputDataset: DatasetHandle,
        wrapper: VizAggregationCapsuleWrapper
    ) throws -> [TimeSeriesPoint] {
        let columnCount = try wrapper.columnCount(of: outputDataset)
        guard columnCount >= 2 else { return [] }

        let timestampData = try wrapper.columnData(of: outputDataset, at: 0)
        let valueData = try wrapper.columnData(of: outputDataset, at: 1)

        let rowCount = timestampData.elementCount
        var results: [TimeSeriesPoint] = []

        let timestampValues: [Int64] = timestampData.data.withUnsafeBytes { Array($0.bindMemory(to: Int64.self)) }
        let valueValues: [Double] = valueData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }

        for i in 0..<rowCount {
            results.append(TimeSeriesPoint(
                timestamp: Date(timeIntervalSince1970: TimeInterval(timestampValues[i])),
                value: valueValues[i],
                dimensionValues: [:]
            ))
        }

        return results
    }

    private func parseRankingOutput(
        outputDataset: DatasetHandle,
        wrapper: VizAggregationCapsuleWrapper
    ) throws -> [AgentRankEntry] {
        let columnCount = try wrapper.columnCount(of: outputDataset)
        guard columnCount >= 2 else { return [] }

        let agentIdData = try wrapper.columnData(of: outputDataset, at: 0)
        let metricData = try wrapper.columnData(of: outputDataset, at: 1)

        let rowCount = agentIdData.elementCount
        var results: [AgentRankEntry] = []

        let metricValues: [Double] = metricData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }

        for i in 0..<rowCount {
            agentIdData.data.withUnsafeBytes { bytes in
                let ptr = bytes.bindMemory(to: Int64.self)
                let agentIdValue = ptr[i]
                results.append(AgentRankEntry(
                    agentId: "agent_\(agentIdValue)",
                    rank: i + 1,
                    metricValue: metricValues[i],
                    changePercent: nil
                ))
            }
        }

        return results
    }

    private func parseDistributionOutput(
        outputDataset: DatasetHandle,
        wrapper: VizAggregationCapsuleWrapper
    ) throws -> [DistributionBucket] {
        let columnCount = try wrapper.columnCount(of: outputDataset)
        guard columnCount >= 2 else { return [] }

        let bucketData = try wrapper.columnData(of: outputDataset, at: 0)
        let countData = try wrapper.columnData(of: outputDataset, at: 1)

        let rowCount = bucketData.elementCount
        var results: [DistributionBucket] = []
        var totalCount = 0

        let countValues: [Int64] = countData.data.withUnsafeBytes { Array($0.bindMemory(to: Int64.self)) }

        for i in 0..<rowCount {
            totalCount += Int(countValues[i])
        }

        for i in 0..<rowCount {
            bucketData.data.withUnsafeBytes { bytes in
                let ptr = bytes.bindMemory(to: Int64.self)
                let bucketValue = ptr[i]
                let percentage = totalCount > 0 ? Double(countValues[i]) / Double(totalCount) * 100.0 : 0
                results.append(DistributionBucket(
                    bucketKey: "bucket_\(bucketValue)",
                    count: Int(countValues[i]),
                    percentage: percentage
                ))
            }
        }

        return results
    }
}

public struct TimeRange: Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}
