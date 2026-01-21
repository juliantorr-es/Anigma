//
//  ContractAnalytics.swift
//  AnigmaAppMac
//
//  Analytics pipeline for contract health monitoring and violation tracking.
//

import Foundation

/// Contract violation severity levels
public enum ViolationSeverity: String, Codable, Sendable {
    case critical   // Blocks merge
    case warning    // Technical debt
    case info       // Informational
}

/// A single contract violation instance
public struct ContractViolation: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let contractName: String
    public let severity: ViolationSeverity
    public let filePath: String
    public let lineNumber: Int?
    public let violationType: String
    public let message: String
    public let suggestedFix: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        contractName: String,
        severity: ViolationSeverity,
        filePath: String,
        lineNumber: Int? = nil,
        violationType: String,
        message: String,
        suggestedFix: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.contractName = contractName
        self.severity = severity
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.violationType = violationType
        self.message = message
        self.suggestedFix = suggestedFix
    }
}

/// Contract health metrics snapshot
public struct ContractHealthSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let contractName: String
    public let totalViolations: Int
    public let criticalViolations: Int
    public let warningViolations: Int
    public let infoViolations: Int
    public let coverage: Double // 0.0 to 1.0
    public let trend: HealthTrend

    public enum HealthTrend: String, Codable, Sendable {
        case improving
        case stable
        case degrading
    }
}

/// Analytics pipeline for contract monitoring
public actor ContractAnalytics {

    private var violations: [ContractViolation] = []
    private var snapshots: [ContractHealthSnapshot] = []
    private let storageURL: URL

    public init(storageURL: URL) {
        self.storageURL = storageURL
        loadFromDisk()
    }

    // MARK: - Violation Tracking

    public func recordViolation(_ violation: ContractViolation) {
        violations.append(violation)
        saveToDisk()

        // Emit event for real-time monitoring
        NotificationCenter.default.post(
            name: .contractViolationDetected,
            object: violation
        )
    }

    public func recordViolations(_ newViolations: [ContractViolation]) {
        violations.append(contentsOf: newViolations)
        saveToDisk()
    }

    public func clearViolations(for contractName: String) {
        violations.removeAll { $0.contractName == contractName }
        saveToDisk()
    }

    // MARK: - Health Snapshots

    public func captureSnapshot(for contractName: String, coverage: Double) {
        let contractViolations = violations.filter { $0.contractName == contractName }

        let critical = contractViolations.filter { $0.severity == .critical }.count
        let warning = contractViolations.filter { $0.severity == .warning }.count
        let info = contractViolations.filter { $0.severity == .info }.count

        // Calculate trend
        let trend = calculateTrend(for: contractName)

        let snapshot = ContractHealthSnapshot(
            timestamp: Date(),
            contractName: contractName,
            totalViolations: contractViolations.count,
            criticalViolations: critical,
            warningViolations: warning,
            infoViolations: info,
            coverage: coverage,
            trend: trend
        )

        snapshots.append(snapshot)
        saveToDisk()
    }

    // MARK: - Analytics Queries

    public func getViolations(
        for contractName: String? = nil,
        severity: ViolationSeverity? = nil,
        since: Date? = nil
    ) -> [ContractViolation] {
        var filtered = violations

        if let contractName = contractName {
            filtered = filtered.filter { $0.contractName == contractName }
        }

        if let severity = severity {
            filtered = filtered.filter { $0.severity == severity }
        }

        if let since = since {
            filtered = filtered.filter { $0.timestamp >= since }
        }

        return filtered.sorted { $0.timestamp > $1.timestamp }
    }

    public func getLatestSnapshot(for contractName: String) -> ContractHealthSnapshot? {
        return snapshots
            .filter { $0.contractName == contractName }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    public func getAllSnapshots(for contractName: String) -> [ContractHealthSnapshot] {
        return snapshots
            .filter { $0.contractName == contractName }
            .sorted { $0.timestamp > $1.timestamp }
    }

    public func getViolationsByFile() -> [String: [ContractViolation]] {
        return Dictionary(grouping: violations) { $0.filePath }
    }

    public func getViolationsByType() -> [String: [ContractViolation]] {
        return Dictionary(grouping: violations) { $0.violationType }
    }

    public func getTopOffenders(limit: Int = 10) -> [(file: String, count: Int)] {
        let grouped = getViolationsByFile()
        return grouped
            .map { (file: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Trend Analysis

    private func calculateTrend(for contractName: String) -> ContractHealthSnapshot.HealthTrend {
        let recentSnapshots = snapshots
            .filter { $0.contractName == contractName }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)

        guard recentSnapshots.count >= 2 else {
            return .stable
        }

        let recent = Array(recentSnapshots)
        let latest = recent[0].totalViolations
        let previous = recent[1].totalViolations

        if latest < previous {
            return .improving
        } else if latest > previous {
            return .degrading
        } else {
            return .stable
        }
    }

    // MARK: - Reporting

    public func generateReport() -> ContractAnalyticsReport {
        let contracts = Set(violations.map { $0.contractName })

        var contractReports: [String: ContractReport] = [:]

        for contract in contracts {
            let contractViolations = violations.filter { $0.contractName == contract }
            let snapshot = getLatestSnapshot(for: contract)

            contractReports[contract] = ContractReport(
                name: contract,
                totalViolations: contractViolations.count,
                criticalViolations: contractViolations.filter { $0.severity == .critical }.count,
                warningViolations: contractViolations.filter { $0.severity == .warning }.count,
                coverage: snapshot?.coverage ?? 0.0,
                trend: snapshot?.trend ?? .stable
            )
        }

        return ContractAnalyticsReport(
            timestamp: Date(),
            totalViolations: violations.count,
            criticalViolations: violations.filter { $0.severity == .critical }.count,
            contractReports: contractReports,
            topOffenders: getTopOffenders()
        )
    }

    // MARK: - Persistence

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let violationsData = try encoder.encode(violations)
            let snapshotsData = try encoder.encode(snapshots)

            try FileManager.default.createDirectory(
                at: storageURL,
                withIntermediateDirectories: true
            )

            try violationsData.write(to: storageURL.appendingPathComponent("violations.json"))
            try snapshotsData.write(to: storageURL.appendingPathComponent("snapshots.json"))
        } catch {
            print("⚠️ Failed to save contract analytics: \(error)")
        }
    }

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let violationsURL = storageURL.appendingPathComponent("violations.json")
            let snapshotsURL = storageURL.appendingPathComponent("snapshots.json")

            if FileManager.default.fileExists(atPath: violationsURL.path) {
                let violationsData = try Data(contentsOf: violationsURL)
                violations = try decoder.decode([ContractViolation].self, from: violationsData)
            }

            if FileManager.default.fileExists(atPath: snapshotsURL.path) {
                let snapshotsData = try Data(contentsOf: snapshotsURL)
                snapshots = try decoder.decode([ContractHealthSnapshot].self, from: snapshotsData)
            }
        } catch {
            print("⚠️ Failed to load contract analytics: \(error)")
        }
    }
}

// MARK: - Report Types

public struct ContractReport: Codable, Sendable {
    public let name: String
    public let totalViolations: Int
    public let criticalViolations: Int
    public let warningViolations: Int
    public let coverage: Double
    public let trend: ContractHealthSnapshot.HealthTrend
}

public struct ContractAnalyticsReport: Codable, Sendable {
    public let timestamp: Date
    public let totalViolations: Int
    public let criticalViolations: Int
    public let contractReports: [String: ContractReport]
    public let topOffenders: [(file: String, count: Int)]

    enum CodingKeys: String, CodingKey {
        case timestamp, totalViolations, criticalViolations, contractReports, topOffenders
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(totalViolations, forKey: .totalViolations)
        try container.encode(criticalViolations, forKey: .criticalViolations)
        try container.encode(contractReports, forKey: .contractReports)

        let offendersDict = Dictionary(uniqueKeysWithValues: topOffenders.map { ($0.file, $0.count) })
        try container.encode(offendersDict, forKey: .topOffenders)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        totalViolations = try container.decode(Int.self, forKey: .totalViolations)
        criticalViolations = try container.decode(Int.self, forKey: .criticalViolations)
        contractReports = try container.decode([String: ContractReport].self, forKey: .contractReports)

        let offendersDict = try container.decode([String: Int].self, forKey: .topOffenders)
        topOffenders = offendersDict.map { (file: $0.key, count: $0.value) }
    }

    public init(
        timestamp: Date,
        totalViolations: Int,
        criticalViolations: Int,
        contractReports: [String: ContractReport],
        topOffenders: [(file: String, count: Int)]
    ) {
        self.timestamp = timestamp
        self.totalViolations = totalViolations
        self.criticalViolations = criticalViolations
        self.contractReports = contractReports
        self.topOffenders = topOffenders
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let contractViolationDetected = Notification.Name("contractViolationDetected")
}
