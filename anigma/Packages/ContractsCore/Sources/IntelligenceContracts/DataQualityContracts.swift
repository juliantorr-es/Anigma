import Foundation

// MARK: - Data Quality Contracts

public enum DataProductKind: String, Codable, Sendable, CaseIterable {
    case memory
    case evalRecord
    case summary
    case embedding
    case sourceChunk
    case generatedDocument
    case handoff
    case queryResponse
}

public struct DataProductLineage: Codable, Sendable, Equatable {
    public let sourceArtifactID: String
    public let sourceArtifactHash: String?
    public let transformName: String
    public let transformVersion: String?
    public let modelVersion: String?
    public let toolVersion: String?
    public let derivedRecordID: String
    public let createdAt: Date

    public init(
        sourceArtifactID: String,
        sourceArtifactHash: String? = nil,
        transformName: String,
        transformVersion: String? = nil,
        modelVersion: String? = nil,
        toolVersion: String? = nil,
        derivedRecordID: String,
        createdAt: Date = Date()
    ) {
        self.sourceArtifactID = sourceArtifactID
        self.sourceArtifactHash = sourceArtifactHash
        self.transformName = transformName
        self.transformVersion = transformVersion
        self.modelVersion = modelVersion
        self.toolVersion = toolVersion
        self.derivedRecordID = derivedRecordID
        self.createdAt = createdAt
    }

    public var hasVersionAnchor: Bool {
        modelVersion != nil || toolVersion != nil || transformVersion != nil
    }
}

public protocol DataQualityInspectable: Sendable {
    var dataProductKind: DataProductKind { get }
    var dataProductIdentifier: String { get }
    var dataProductCreatedAt: Date { get }
    var dataProductUpdatedAt: Date? { get }
    var dataProductLineage: DataProductLineage? { get }
    var dataProductPayloadReferences: [String] { get }
    var dataProductSummaryFingerprint: String? { get }
    var dataProductEmbeddingModel: String? { get }
    var dataProductEmbeddingGeneratedAt: Date? { get }
    var dataProductSourceFidelity: Double? { get }
    var dataProductHandoffState: String? { get }
}

public struct DataQualityIssue: Codable, Sendable, Equatable {
    public enum Severity: String, Codable, Sendable {
        case warning
        case error
        case critical

        public var isBlocking: Bool {
            self != .warning
        }
    }

    public let code: String
    public let severity: Severity
    public let message: String
    public let evidence: [String]

    public init(
        code: String,
        severity: Severity,
        message: String,
        evidence: [String] = []
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.evidence = evidence
    }
}

public struct DataQualityRecordReport: Codable, Sendable, Equatable {
    public let kind: DataProductKind
    public let identifier: String
    public let promotable: Bool
    public let issues: [DataQualityIssue]
    public let lineage: DataProductLineage?

    public init(
        kind: DataProductKind,
        identifier: String,
        promotable: Bool,
        issues: [DataQualityIssue],
        lineage: DataProductLineage?
    ) {
        self.kind = kind
        self.identifier = identifier
        self.promotable = promotable
        self.issues = issues
        self.lineage = lineage
    }
}

public struct DataQualityReport: Codable, Sendable, Equatable {
    public let evaluatedAt: Date
    public let totalRecords: Int
    public let promotableRecords: Int
    public let blockedRecords: Int
    public let recordReports: [DataQualityRecordReport]
    public let issues: [DataQualityIssue]

    public init(
        evaluatedAt: Date = Date(),
        totalRecords: Int,
        promotableRecords: Int,
        blockedRecords: Int,
        recordReports: [DataQualityRecordReport],
        issues: [DataQualityIssue]
    ) {
        self.evaluatedAt = evaluatedAt
        self.totalRecords = totalRecords
        self.promotableRecords = promotableRecords
        self.blockedRecords = blockedRecords
        self.recordReports = recordReports
        self.issues = issues
    }

    public var isTrusted: Bool {
        blockedRecords == 0 && !issues.contains(where: { $0.severity.isBlocking })
    }
}

public struct DataQualityGate: Sendable {
    public struct Thresholds: Sendable, Codable, Equatable {
        public let staleRecordAgeDays: Int
        public let staleEmbeddingAgeDays: Int
        public let minimumSourceExtractionFidelity: Double

        public init(
            staleRecordAgeDays: Int = 30,
            staleEmbeddingAgeDays: Int = 30,
            minimumSourceExtractionFidelity: Double = 0.85
        ) {
            self.staleRecordAgeDays = staleRecordAgeDays
            self.staleEmbeddingAgeDays = staleEmbeddingAgeDays
            self.minimumSourceExtractionFidelity = minimumSourceExtractionFidelity
        }

        public static var `default`: Thresholds {
            Thresholds()
        }
    }

    private let thresholds: Thresholds
    private let currentDate: @Sendable () -> Date

    public init(
        thresholds: Thresholds = .default,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.thresholds = thresholds
        self.currentDate = currentDate
    }

    public func evaluate(_ records: [any DataQualityInspectable]) -> DataQualityReport {
        let now = currentDate()
        var recordIssues = Array(repeating: [DataQualityIssue](), count: records.count)
        var globalIssues: [DataQualityIssue] = []
        var duplicateGroups: [String: [Int]] = [:]
        var summaryGroups: [String: [Int]] = [:]
        var duplicateIdentifiers: [String: [Int]] = [:]

        for (index, record) in records.enumerated() {
            recordIssues[index].append(contentsOf: validate(record, now: now))

            let duplicateKey = makeDuplicateKey(for: record)
            duplicateGroups[duplicateKey, default: []].append(index)

            duplicateIdentifiers[record.dataProductIdentifier, default: []].append(index)

            if let summaryFingerprint = normalized(record.dataProductSummaryFingerprint) {
                let lineageKey = normalized(record.dataProductLineage?.sourceArtifactHash)
                    ?? normalized(record.dataProductLineage?.sourceArtifactID)
                    ?? "\(record.dataProductKind.rawValue):\(record.dataProductIdentifier)"
                summaryGroups["\(lineageKey)|\(record.dataProductKind.rawValue)|\(summaryFingerprint)", default: []].append(index)
            }
        }

        for (_, indexes) in duplicateIdentifiers where indexes.count > 1 {
            let evidence = indexes.map { records[$0].dataProductIdentifier }
            appendIssue(
                to: &recordIssues,
                indexes: indexes,
                code: "duplicate-identifier",
                severity: .error,
                message: "Duplicate record identifier detected",
                evidence: evidence
            )
        }

        for (key, indexes) in duplicateGroups where indexes.count > 1 {
            let evidence = indexes.map { records[$0].dataProductIdentifier + "@" + key }
            appendIssue(
                to: &recordIssues,
                indexes: indexes,
                code: "duplicate-record",
                severity: .error,
                message: "Duplicate data product detected for key \(key)",
                evidence: evidence
            )
        }

        var groupedByLineage: [String: [Int]] = [:]
        for (key, indexes) in summaryGroups {
            let lineageKey = key
                .split(separator: "|")
                .prefix(2)
                .map(String.init)
                .joined(separator: "|")
            groupedByLineage[lineageKey, default: []].append(contentsOf: indexes)
        }

        for (_, indexes) in groupedByLineage where indexes.count > 1 {
            let fingerprints = Set(indexes.compactMap { normalized(records[$0].dataProductSummaryFingerprint) })
            if fingerprints.count > 1 {
                let evidence = indexes.map { records[$0].dataProductIdentifier }
                appendIssue(
                    to: &recordIssues,
                    indexes: indexes,
                    code: "conflicting-summary",
                    severity: .error,
                    message: "Conflicting summaries share the same lineage source",
                    evidence: evidence
                )
            }
        }

        let recordReports = records.enumerated().map { index, record in
            let issues = recordIssues[index]
            let promotable = !issues.contains(where: { $0.severity.isBlocking })
            return DataQualityRecordReport(
                kind: record.dataProductKind,
                identifier: record.dataProductIdentifier,
                promotable: promotable,
                issues: issues,
                lineage: record.dataProductLineage
            )
        }

        globalIssues = recordReports.flatMap(\.issues).filter { $0.severity.isBlocking }

        let promotableRecords = recordReports.filter(\.promotable).count
        let blockedRecords = recordReports.count - promotableRecords

        return DataQualityReport(
            evaluatedAt: now,
            totalRecords: records.count,
            promotableRecords: promotableRecords,
            blockedRecords: blockedRecords,
            recordReports: recordReports,
            issues: globalIssues
        )
    }

    private func validate(_ record: any DataQualityInspectable, now: Date) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []

        issues.append(contentsOf: validateLineage(record, now: now))
        issues.append(contentsOf: validateFreshness(record, now: now))
        issues.append(contentsOf: validatePayloadReferences(record))
        issues.append(contentsOf: validateSummary(record))
        issues.append(contentsOf: validateEmbedding(record, now: now))
        issues.append(contentsOf: validateHandoff(record))
        issues.append(contentsOf: validateExtraction(record))

        return issues
    }

    private func validateLineage(_ record: any DataQualityInspectable, now: Date) -> [DataQualityIssue] {
        guard let lineage = record.dataProductLineage else {
            return [
                DataQualityIssue(
                    code: "missing-provenance",
                    severity: .critical,
                    message: "Missing lineage for \(record.dataProductKind.rawValue)",
                    evidence: [record.dataProductIdentifier]
                )
            ]
        }

        var issues: [DataQualityIssue] = []

        if normalized(lineage.sourceArtifactID) == nil {
            issues.append(
                DataQualityIssue(
                    code: "missing-source-artifact",
                    severity: .critical,
                    message: "Lineage is missing a source artifact identifier",
                    evidence: [record.dataProductIdentifier]
                )
            )
        }

        if normalized(lineage.sourceArtifactHash) == nil {
            issues.append(
                DataQualityIssue(
                    code: "missing-source-hash",
                    severity: .error,
                    message: "Lineage is missing a source artifact hash",
                    evidence: [record.dataProductIdentifier, lineage.sourceArtifactID]
                )
            )
        }

        if normalized(lineage.transformName) == nil {
            issues.append(
                DataQualityIssue(
                    code: "missing-transform",
                    severity: .critical,
                    message: "Lineage is missing a transform name",
                    evidence: [record.dataProductIdentifier]
                )
            )
        }

        if normalized(lineage.derivedRecordID) == nil {
            issues.append(
                DataQualityIssue(
                    code: "missing-derived-record",
                    severity: .critical,
                    message: "Lineage is missing the derived record identifier",
                    evidence: [record.dataProductIdentifier]
                )
            )
        }

        if !lineage.hasVersionAnchor {
            issues.append(
                DataQualityIssue(
                    code: "missing-version-anchor",
                    severity: .error,
                    message: "Lineage must include a model, tool, or transform version",
                    evidence: [record.dataProductIdentifier, lineage.transformName]
                )
            )
        }

        if lineage.createdAt > now {
            issues.append(
                DataQualityIssue(
                    code: "future-lineage-timestamp",
                    severity: .error,
                    message: "Lineage timestamp cannot be in the future",
                    evidence: [record.dataProductIdentifier, lineage.createdAt.ISO8601Format()]
                )
            )
        }

        return issues
    }

    private func validateFreshness(_ record: any DataQualityInspectable, now: Date) -> [DataQualityIssue] {
        var issues: [DataQualityIssue] = []

        if record.dataProductCreatedAt > now {
            issues.append(
                DataQualityIssue(
                    code: "future-record-timestamp",
                    severity: .error,
                    message: "Record timestamp cannot be in the future",
                    evidence: [record.dataProductIdentifier, record.dataProductCreatedAt.ISO8601Format()]
                )
            )
        }

        let ageDays = max(0, Int(now.timeIntervalSince(record.dataProductCreatedAt) / 86_400))
        if ageDays > thresholds.staleRecordAgeDays {
            issues.append(
                DataQualityIssue(
                    code: "stale-record",
                    severity: .error,
                    message: "Record is older than the freshness window",
                    evidence: [record.dataProductIdentifier, "ageDays=\(ageDays)"]
                )
            )
        }

        if let updatedAt = record.dataProductUpdatedAt, updatedAt > now {
            issues.append(
                DataQualityIssue(
                    code: "future-update-timestamp",
                    severity: .error,
                    message: "Update timestamp cannot be in the future",
                    evidence: [record.dataProductIdentifier, updatedAt.ISO8601Format()]
                )
            )
        }

        return issues
    }

    private func validatePayloadReferences(_ record: any DataQualityInspectable) -> [DataQualityIssue] {
        let refs = record.dataProductPayloadReferences
        let trimmedRefs = refs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var issues: [DataQualityIssue] = []

        let malformedRefs = trimmedRefs.filter { $0.isEmpty || $0.rangeOfCharacter(from: .newlines.union(.controlCharacters)) != nil }
        if !malformedRefs.isEmpty {
            issues.append(
                DataQualityIssue(
                    code: "malformed-payload-reference",
                    severity: .error,
                    message: "Payload references must be non-empty and whitespace-free",
                    evidence: malformedRefs
                )
            )
        }

        if Set(trimmedRefs).count != trimmedRefs.count {
            issues.append(
                DataQualityIssue(
                    code: "duplicate-payload-reference",
                    severity: .warning,
                    message: "Payload references should be unique",
                    evidence: trimmedRefs
                )
            )
        }

        let requiresPayloadReferences: Set<DataProductKind> = [
            .summary, .sourceChunk, .generatedDocument, .handoff, .evalRecord
        ]

        if requiresPayloadReferences.contains(record.dataProductKind) && trimmedRefs.allSatisfy({ $0.isEmpty }) {
            issues.append(
                DataQualityIssue(
                    code: "missing-payload-reference",
                    severity: .error,
                    message: "Trusted \(record.dataProductKind.rawValue) records require at least one payload reference",
                    evidence: [record.dataProductIdentifier]
                )
            )
        }

        return issues
    }

    private func validateSummary(_ record: any DataQualityInspectable) -> [DataQualityIssue] {
        guard let summary = normalized(record.dataProductSummaryFingerprint) else {
            return []
        }

        if summary.count < 8 {
            return [
                DataQualityIssue(
                    code: "low-fidelity-summary",
                    severity: .warning,
                    message: "Summary fingerprint is too short to be a strong duplicate key",
                    evidence: [record.dataProductIdentifier, summary]
                )
            ]
        }

        return []
    }

    private func validateEmbedding(_ record: any DataQualityInspectable, now: Date) -> [DataQualityIssue] {
        guard record.dataProductEmbeddingModel != nil else {
            return []
        }

        let referenceDate = record.dataProductEmbeddingGeneratedAt ?? record.dataProductUpdatedAt ?? record.dataProductCreatedAt
        let embeddingAgeDays = max(0, Int(now.timeIntervalSince(referenceDate) / 86_400))
        guard embeddingAgeDays > thresholds.staleEmbeddingAgeDays else {
            return []
        }

        return [
            DataQualityIssue(
                code: "stale-embedding",
                severity: .error,
                message: "Embedding is older than the freshness window",
                evidence: [record.dataProductIdentifier, "ageDays=\(embeddingAgeDays)", record.dataProductEmbeddingModel ?? ""]
            )
        ]
    }

    private func validateHandoff(_ record: any DataQualityInspectable) -> [DataQualityIssue] {
        guard record.dataProductKind == .handoff else {
            return []
        }

        let state = normalized(record.dataProductHandoffState)?.lowercased()
        let acceptedStates: Set<String> = ["accepted", "closed", "complete", "completed", "promoted"]
        guard let state, acceptedStates.contains(state) else {
            return [
                DataQualityIssue(
                    code: "incomplete-handoff",
                    severity: .critical,
                    message: "Handoff records must be explicitly completed before promotion",
                    evidence: [record.dataProductIdentifier, state ?? "missing"]
                )
            ]
        }

        return []
    }

    private func validateExtraction(_ record: any DataQualityInspectable) -> [DataQualityIssue] {
        guard record.dataProductKind == .sourceChunk || record.dataProductKind == .generatedDocument else {
            return []
        }

        guard let fidelity = record.dataProductSourceFidelity else {
            return [
                DataQualityIssue(
                    code: "missing-extraction-fidelity",
                    severity: .error,
                    message: "Source extraction fidelity is required for trusted source chunks and generated documents",
                    evidence: [record.dataProductIdentifier]
                )
            ]
        }

        guard fidelity >= thresholds.minimumSourceExtractionFidelity else {
            return [
                DataQualityIssue(
                    code: "low-fidelity-source-extraction",
                    severity: .error,
                    message: "Source extraction fidelity is below the trust threshold",
                    evidence: [record.dataProductIdentifier, String(format: "%.3f", fidelity)]
                )
            ]
        }

        return []
    }

    private func appendIssue(
        to recordIssues: inout [[DataQualityIssue]],
        indexes: [Int],
        code: String,
        severity: DataQualityIssue.Severity,
        message: String,
        evidence: [String]
    ) {
        let issue = DataQualityIssue(code: code, severity: severity, message: message, evidence: evidence)
        for index in indexes {
            recordIssues[index].append(issue)
        }
    }

    private func makeDuplicateKey(for record: any DataQualityInspectable) -> String {
        let lineageKey = normalized(record.dataProductLineage?.sourceArtifactHash)
            ?? normalized(record.dataProductLineage?.sourceArtifactID)
            ?? "no-lineage"
        let summaryKey = normalized(record.dataProductSummaryFingerprint) ?? "no-summary"
        let payloadKey = record.dataProductPayloadReferences
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()
            .joined(separator: "|")

        return [
            record.dataProductKind.rawValue,
            lineageKey,
            summaryKey,
            payloadKey
        ].joined(separator: "::")
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
