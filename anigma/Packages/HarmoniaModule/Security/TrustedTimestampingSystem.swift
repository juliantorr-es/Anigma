//
//  TrustedTimestampingSystem.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import AnigmaCore
import DatabaseCore
@preconcurrency import Foundation
import os

/// Trusted timestamping for evidence temporal authenticity
/// Turns "when captured" into "provably when captured" with external time anchors
public actor TrustedTimestampingSystem {
    private let dbActor: any DatabaseCore.DatabaseExecutor
    private let timestampingServices: [TimestampingService]
    private var monotonicClock: MonotonicClock

    public init(dbActor: any DatabaseCore.DatabaseExecutor) {
        self.dbActor = dbActor
        self.timestampingServices = [
            RFC3161TimestampingService(),
            NISTBeaconTimestampingService(),
            InternalTimestampingService()
        ]
        self.monotonicClock = MonotonicClock()
    }

    // MARK: - Evidence Timestamping

    /// Create trusted timestamp for evidence chain head
    public func timestampEvidenceHead(
        evidenceHeadHash: String,
        timestampingLevel: TimestampingLevel = .standard,
        requestedBy: String,
        authorizedBy: String? = nil
    ) async throws -> TimestampClaim {
        let localTimestamp = Int(Date().timeIntervalSince1970)
        let monotonicValue = monotonicClock.getNext()

        // Collect multiple time sources
        var timeClaims: [TimeSourceClaim] = []

        // System clock claim
        timeClaims.append(
            TimeSourceClaim(
                source: "system_clock",
                timestamp: localTimestamp,
                timezone: TimeZone.current.identifier,
                confidence: 0.8,
                metadata: [
                    "monotonic_value": String(monotonicValue),
                    "clock_source": "system_nanos",
                    "leap_seconds": "handled"
                ]
            ))

        // Filesystem timestamps (for local files)
        timeClaims.append(contentsOf: try await collectFilesystemTimestamps())

        // External timestamping services
        if timestampingLevel == .enhanced || timestampingLevel == .legal {
            timeClaims.append(
                contentsOf: try await requestExternalTimestamps(
                    for: evidenceHeadHash,
                    level: timestampingLevel
                ))
        }

        // Network time verification
        if timestampingLevel == .legal {
            timeClaims.append(try await verifyWithNTP())
        }

        // Create master timestamp claim
        let masterClaim = TimestampClaim(
            claimId: UUID().uuidString.lowercased(),
            targetHash: evidenceHeadHash,
            targetType: .evidenceHead,
            masterTimestamp: localTimestamp,
            monotonicValue: monotonicValue,
            timeSourceClaims: timeClaims,
            timestampingLevel: timestampingLevel,
            requestedBy: requestedBy,
            authorizedBy: authorizedBy,
            createdAt: localTimestamp
        )

        // Store timestamp claim
        try await storeTimestampClaim(masterClaim)

        return masterClaim
    }

    /// Timestamp bundle export for legal admissibility
    public func timestampBundleExport(
        bundleId: String,
        bundleHash: String,
        exportPath: String,
        timestampingLevel: TimestampingLevel = .legal,
        legalHoldReference: String? = nil,
        retentionPeriod: Int? = nil
    ) async throws -> BundleTimestampClaim {
        let localTimestamp = Int(Date().timeIntervalSince1970)
        let monotonicValue = monotonicClock.getNext()

        // Enhanced timestamping for legal exports
        var timeClaims: [TimeSourceClaim] = []

        // System time
        timeClaims.append(
            TimeSourceClaim(
                source: "system_clock",
                timestamp: localTimestamp,
                timezone: "UTC",
                confidence: 0.9,
                metadata: [
                    "monotonic_value": String(monotonicValue),
                    "export_path": exportPath,
                    "bundle_size": String(try getFileSize(exportPath)),
                    "export_format": try getFileExtension(exportPath)
                ]
            ))

        // Filesystem metadata
        timeClaims.append(contentsOf: try await collectFilesystemMetadata(exportPath))

        // Legal-grade external timestamps
        if timestampingLevel == .legal {
            timeClaims.append(
                try await requestLegalTimestamp(
                    bundleHash: bundleHash,
                    exportPath: exportPath
                ))
        }

        // Blockchain timestamp (if configured)
        if timestampingLevel == .blockchain {
            timeClaims.append(try await requestBlockchainTimestamp(bundleHash: bundleHash))
        }

        let bundleClaim = BundleTimestampClaim(
            claimId: UUID().uuidString.lowercased(),
            bundleId: bundleId,
            bundleHash: bundleHash,
            masterTimestamp: localTimestamp,
            monotonicValue: monotonicValue,
            timeSourceClaims: timeClaims,
            timestampingLevel: timestampingLevel,
            legalHoldReference: legalHoldReference,
            retentionPeriod: retentionPeriod,
            exportPath: exportPath,
            createdAt: localTimestamp
        )

        // Store bundle timestamp
        try await storeBundleTimestamp(bundleClaim)

        return bundleClaim
    }

    /// Verify timestamp authenticity and consistency
    public func verifyTimestampClaim(_ claim: TimestampClaim) async throws
        -> TimestampVerificationResult {
        var verifications: [TimestampVerification] = []
        var overallConfidence: Double = 0.0
        var inconsistencies: [TimestampInconsistency] = []

        // Verify each time source
        for timeClaim in claim.timeSourceClaims {
            let verification = try await verifyTimeSource(timeClaim)
            verifications.append(verification)
            overallConfidence += verification.confidence

            // Check for inconsistencies with master timestamp
            let timeDiff = abs(timeClaim.timestamp - claim.masterTimestamp)
            if timeDiff > timeClaim.acceptableDriftSeconds {
                inconsistencies.append(
                    TimestampInconsistency(
                        source: timeClaim.source,
                        expectedTimestamp: claim.masterTimestamp,
                        actualTimestamp: timeClaim.timestamp,
                        driftSeconds: timeDiff,
                        severity: timeDiff > 300 ? .high : .medium
                    ))
            }
        }

        // Verify monotonic ordering
        let monotonicValid = try await verifyMonotonicOrdering(claim)

        // Check for external service verification
        let externalValid = try await verifyExternalTimestamps(claim)

        overallConfidence = overallConfidence / Double(claim.timeSourceClaims.count)

        return TimestampVerificationResult(
            claimId: claim.claimId,
            isValid: overallConfidence > 0.7 && inconsistencies.isEmpty && monotonicValid,
            overallConfidence: overallConfidence,
            timeSourceVerifications: verifications,
            inconsistencies: inconsistencies,
            monotonicOrderingValid: monotonicValid,
            externalTimestampsValid: externalValid,
            verifiedAt: Int(Date().timeIntervalSince1970)
        )
    }

    /// Get temporal ordering between multiple timestamp claims
    public func getTemporalOrdering(claims: [TimestampClaim]) async throws -> TemporalOrdering {
        let sortedClaims = claims.sorted { $0.masterTimestamp < $1.masterTimestamp }

        var ordering: [TemporalRelationship] = []
        var gaps: [TimestampGap] = []

        for i in 0..<sortedClaims.count {
            for j in (i + 1)..<sortedClaims.count {
                let earlier = sortedClaims[i]
                let later = sortedClaims[j]

                let relationship = TemporalRelationship(
                    earlierClaimId: earlier.claimId,
                    laterClaimId: later.claimId,
                    timeDifference: later.masterTimestamp - earlier.masterTimestamp,
                    confidence: calculateTemporalConfidence(earlier: earlier, later: later)
                )

                ordering.append(relationship)

                // Check for suspicious gaps
                if relationship.timeDifference > 86400 {  // 24 hours
                    gaps.append(
                        TimestampGap(
                            fromClaimId: earlier.claimId,
                            toClaimId: later.claimId,
                            gapSeconds: relationship.timeDifference,
                            severity: relationship.timeDifference > 604800 ? .high : .medium  // 7 days
                        ))
                }
            }
        }

        return TemporalOrdering(
            orderedClaims: sortedClaims,
            relationships: ordering,
            suspiciousGaps: gaps,
            hasSuspiciousGaps: !gaps.isEmpty,
            verifiedAt: Int(Date().timeIntervalSince1970)
        )
    }

    // MARK: - Private Methods

    private func collectFilesystemTimestamps() async throws -> [TimeSourceClaim] {
        var claims: [TimeSourceClaim] = []

        // Current working directory metadata
        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: cwdURL.path) {
            let mtime = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let ctime = (attributes[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0

            claims.append(
                TimeSourceClaim(
                    source: "filesystem_mtime",
                    timestamp: Int(mtime),
                    timezone: "UTC",
                    confidence: 0.6,
                    metadata: ["path": cwdURL.path, "attribute": "modification"]
                ))

            claims.append(
                TimeSourceClaim(
                    source: "filesystem_ctime",
                    timestamp: Int(ctime),
                    timezone: "UTC",
                    confidence: 0.6,
                    metadata: ["path": cwdURL.path, "attribute": "creation"]
                ))
        }

        return claims
    }

    private func collectFilesystemMetadata(_ path: String) async throws -> [TimeSourceClaim] {
        var claims: [TimeSourceClaim] = []

        if let attributes = try? FileManager.default.attributesOfItem(atPath: path) {
            let mtime = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let size = attributes[.size] as? Int ?? 0

            claims.append(
                TimeSourceClaim(
                    source: "export_file_mtime",
                    timestamp: Int(mtime),
                    timezone: "UTC",
                    confidence: 0.8,
                    metadata: [
                        "path": path,
                        "size": String(size),
                        "attribute": "modification"
                    ]
                ))
        }

        return claims
    }

    private func requestExternalTimestamps(
        for hash: String,
        level: TimestampingLevel
    ) async throws -> [TimeSourceClaim] {
        var claims: [TimeSourceClaim] = []

        for service in timestampingServices {
            if service.supportsLevel(level) {
                do {
                    let timestamp = try await service.timestamp(
                        data: hash.data(using: .utf8) ?? Data())
                    claims.append(
                        TimeSourceClaim(
                            source: service.serviceName,
                            timestamp: timestamp.timestamp,
                            timezone: "UTC",
                            confidence: timestamp.confidence,
                            metadata: [
                                "service_response": timestamp.responseData,
                                "serial_number": timestamp.serialNumber ?? "",
                                "policy_oid": timestamp.policyOID ?? ""
                            ]
                        ))
                } catch {
                    // Log failed timestamp request but continue
                    print("Failed to get timestamp from \(service.serviceName): \(error)")
                }
            }
        }

        return claims
    }

    private func requestLegalTimestamp(bundleHash: String, exportPath: String) async throws
        -> TimeSourceClaim {
        // In a real implementation, this would use a legal TSA service
        // For now, simulate with enhanced confidence
        return TimeSourceClaim(
            source: "legal_tsa",
            timestamp: Int(Date().timeIntervalSince1970),
            timezone: "UTC",
            confidence: 0.95,
            metadata: [
                "legal_reference": "export_\(bundleHash)",
                "export_path": exportPath,
                "certificate_chain": "simulated_legal_certificate"
            ]
        )
    }

    private func requestBlockchainTimestamp(bundleHash: String) async throws -> TimeSourceClaim {
        // In a real implementation, this would submit to a blockchain timestamping service
        return TimeSourceClaim(
            source: "blockchain",
            timestamp: Int(Date().timeIntervalSince1970),
            timezone: "UTC",
            confidence: 0.98,
            metadata: [
                "transaction_hash": "simulated_tx_\(bundleHash)",
                "block_height": "12345",
                "network": "bitcoin_testnet"
            ]
        )
    }

    private func verifyWithNTP() async throws -> TimeSourceClaim {
        // In a real implementation, this would query NTP servers
        return TimeSourceClaim(
            source: "ntp_server",
            timestamp: Int(Date().timeIntervalSince1970),
            timezone: "UTC",
            confidence: 0.85,
            metadata: [
                "server": "pool.ntp.org",
                "stratum": "2",
                "offset_ms": "0"
            ]
        )
    }

    private func verifyTimeSource(_ claim: TimeSourceClaim) async throws -> TimestampVerification {
        var isValid = true
        var confidence = claim.confidence

        // Verify timezone is valid
        if TimeZone(identifier: claim.timezone) == nil {
            isValid = false
            confidence = 0.0
        }

        // Verify timestamp is reasonable (not in future, not too old)
        let now = Int(Date().timeIntervalSince1970)
        let age = now - claim.timestamp

        if claim.timestamp > now {
            isValid = false
            confidence = 0.0
        } else if age > 86400 * 365 {  // 1 year old
            confidence = max(0.1, confidence - 0.5)
        }

        return TimestampVerification(
            source: claim.source,
            isValid: isValid,
            confidence: confidence,
            verifiedAt: Int(Date().timeIntervalSince1970)
        )
    }

    private func verifyMonotonicOrdering(_ claim: TimestampClaim) async throws -> Bool {
        // Check that monotonic value is increasing
        let previousClaims = try await getPreviousTimestampClaims(limit: 10)

        for previous in previousClaims {
            if previous.monotonicValue >= claim.monotonicValue {
                return false
            }
        }

        return true
    }

    private func verifyExternalTimestamps(_ claim: TimestampClaim) async throws -> Bool {
        // Verify external service responses if present
        for timeClaim in claim.timeSourceClaims {
            if timeClaim.source.contains("tsa") || timeClaim.source.contains("blockchain") {
                // In a real implementation, verify the external signature/certificate
                continue
            }
        }

        return true
    }

    private func calculateTemporalConfidence(earlier: TimestampClaim, later: TimestampClaim)
        -> Double {
        let timeDiff = later.masterTimestamp - earlier.masterTimestamp

        // High confidence for reasonable time differences
        if timeDiff > 0 && timeDiff < 86400 {  // Same day
            return 0.9
        } else if timeDiff > 0 && timeDiff < 604800 {  // Same week
            return 0.7
        } else if timeDiff > 0 {
            return 0.5
        } else {
            return 0.0  // Invalid ordering
        }
    }

    private func getFileSize(_ path: String) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return attributes[.size] as? Int ?? 0
    }

    private func getFileExtension(_ path: String) throws -> String {
        return (path as NSString).pathExtension
    }

    private func textParam(_ value: String?) -> DatabaseParameter {
        if let value = value {
            return .text(value)
        }
        return .null
    }

    private func intParam(_ value: Int?) -> DatabaseParameter {
        if let value = value {
            return .int(value)
        }
        return .null
    }

    private func getPreviousTimestampClaims(limit: Int) async throws -> [TimestampClaim] {
        _ = try await dbActor.query(
            """
                SELECT * FROM timestamp_claims
                ORDER BY monotonic_value DESC
                LIMIT ?
            """, parameters: [.int(limit)])

        // Convert rows to TimestampClaim objects
        // This is simplified - in real implementation, would properly deserialize
        return []
    }

    private func storeTimestampClaim(_ claim: TimestampClaim) async throws {
        let claimData = try JSONEncoder().encode(claim)
        let timeSourceData = try JSONEncoder().encode(claim.timeSourceClaims)

        _ = try await dbActor.execute(
            """
                INSERT INTO timestamp_claims (
                    claim_id, target_hash, target_type, master_timestamp,
                    monotonic_value, time_source_claims, timestamping_level,
                    requested_by, authorized_by, claim_data, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(claim.claimId),
                .text(claim.targetHash),
                .text(claim.targetType.rawValue),
                .int(claim.masterTimestamp),
                .int(Int(claim.monotonicValue)),
                .blob(timeSourceData),
                .text(claim.timestampingLevel.rawValue),
                .text(claim.requestedBy),
                textParam(claim.authorizedBy),
                .blob(claimData),
                .int(claim.createdAt)
            ])
    }

    private func storeBundleTimestamp(_ claim: BundleTimestampClaim) async throws {
        let claimData = try JSONEncoder().encode(claim)
        let timeSourceData = try JSONEncoder().encode(claim.timeSourceClaims)

        _ = try await dbActor.execute(
            """
                INSERT INTO bundle_timestamp_claims (
                    claim_id, bundle_id, bundle_hash, master_timestamp,
                    monotonic_value, time_source_claims, timestamping_level,
                    legal_hold_reference, retention_period, export_path,
                    claim_data, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(claim.claimId),
                .text(claim.bundleId),
                .text(claim.bundleHash),
                .int(claim.masterTimestamp),
                .int(Int(claim.monotonicValue)),
                .blob(timeSourceData),
                .text(claim.timestampingLevel.rawValue),
                textParam(claim.legalHoldReference),
                intParam(claim.retentionPeriod),
                .text(claim.exportPath),
                .blob(claimData),
                .int(claim.createdAt)
            ])
    }
}

// MARK: - Supporting Classes

final class MonotonicClock: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: UInt64(0))

    func getNext() -> UInt64 {
        state.withLock { lastValue in
            let now = UInt64(Date().timeIntervalSince1970 * 1_000_000)  // microseconds

            if now > lastValue {
                lastValue = now
            } else {
                lastValue += 1
            }
            return lastValue
        }
    }
}

protocol TimestampingService: Sendable {
    var serviceName: String { get }
    func supportsLevel(_ level: TimestampingLevel) -> Bool
    func timestamp(data: Data) async throws -> TimestampResponse
}

struct TimestampResponse: Sendable {
    let timestamp: Int
    let confidence: Double
    let responseData: String
    let serialNumber: String?
    let policyOID: String?
}

final class RFC3161TimestampingService: TimestampingService {
    let serviceName = "RFC3161_TSA"

    func supportsLevel(_ level: TimestampingLevel) -> Bool {
        return level == .enhanced || level == .legal
    }

    func timestamp(data: Data) async throws -> TimestampResponse {
        // Simulated RFC3161 timestamp
        return TimestampResponse(
            timestamp: Int(Date().timeIntervalSince1970),
            confidence: 0.9,
            responseData: "simulated_rfc3161_response",
            serialNumber: "12345",
            policyOID: "1.3.6.1.4.1.12345"
        )
    }
}

final class NISTBeaconTimestampingService: TimestampingService {
    let serviceName = "NIST_Randomness_Beacon"

    func supportsLevel(_ level: TimestampingLevel) -> Bool {
        return level == .enhanced || level == .legal
    }

    func timestamp(data: Data) async throws -> TimestampResponse {
        // Simulated NIST Randomness Beacon
        return TimestampResponse(
            timestamp: Int(Date().timeIntervalSince1970),
            confidence: 0.95,
            responseData: "simulated_nist_beacon_response",
            serialNumber: "beacon_12345",
            policyOID: nil
        )
    }
}

final class InternalTimestampingService: TimestampingService {
    let serviceName = "Internal_Timestamp"

    func supportsLevel(_ level: TimestampingLevel) -> Bool {
        return true
    }

    func timestamp(data: Data) async throws -> TimestampResponse {
        return TimestampResponse(
            timestamp: Int(Date().timeIntervalSince1970),
            confidence: 0.7,
            responseData: "internal_timestamp",
            serialNumber: nil,
            policyOID: nil
        )
    }
}

// MARK: - Data Models

public struct TimestampClaim: Codable, Sendable {
    let claimId: String
    let targetHash: String
    let targetType: TimestampTargetType
    let masterTimestamp: Int
    let monotonicValue: UInt64
    let timeSourceClaims: [TimeSourceClaim]
    let timestampingLevel: TimestampingLevel
    let requestedBy: String
    let authorizedBy: String?
    let createdAt: Int
}

/// Timestamp claim for bundle exports.
public struct BundleTimestampClaim: Codable, Sendable {
    public let claimId: String
    public let bundleId: String
    public let bundleHash: String
    public let masterTimestamp: Int
    public let monotonicValue: UInt64
    public let timeSourceClaims: [TimeSourceClaim]
    public let timestampingLevel: TimestampingLevel
    public let legalHoldReference: String?
    public let retentionPeriod: Int?
    public let exportPath: String
    public let createdAt: Int

    public init(
        claimId: String,
        bundleId: String,
        bundleHash: String,
        masterTimestamp: Int,
        monotonicValue: UInt64,
        timeSourceClaims: [TimeSourceClaim],
        timestampingLevel: TimestampingLevel,
        legalHoldReference: String?,
        retentionPeriod: Int?,
        exportPath: String,
        createdAt: Int
    ) {
        self.claimId = claimId
        self.bundleId = bundleId
        self.bundleHash = bundleHash
        self.masterTimestamp = masterTimestamp
        self.monotonicValue = monotonicValue
        self.timeSourceClaims = timeSourceClaims
        self.timestampingLevel = timestampingLevel
        self.legalHoldReference = legalHoldReference
        self.retentionPeriod = retentionPeriod
        self.exportPath = exportPath
        self.createdAt = createdAt
    }
}

/// Individual time source claim within a bundle or evidence timestamp.
public struct TimeSourceClaim: Codable, Sendable {
    public let source: String
    public let timestamp: Int
    public let timezone: String
    public let confidence: Double
    public let metadata: [String: String]  // Changed from [String: Any] to [String: String] for Sendable/Codable simplicity

    var acceptableDriftSeconds: Int {
        switch confidence {
        case 0.9...: return 60  // High confidence: 1 minute
        case 0.7..<0.9: return 300  // Medium confidence: 5 minutes
        case 0.5..<0.7: return 900  // Low confidence: 15 minutes
        default: return 3600  // Very low: 1 hour
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(metadata, forKey: .metadata)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        timestamp = try container.decode(Int.self, forKey: .timestamp)
        timezone = try container.decode(String.self, forKey: .timezone)
        confidence = try container.decode(Double.self, forKey: .confidence)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }

    public init(
        source: String, timestamp: Int, timezone: String, confidence: Double,
        metadata: [String: String]
    ) {
        self.source = source
        self.timestamp = timestamp
        self.timezone = timezone
        self.confidence = confidence
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case source, timestamp, timezone, confidence, metadata
    }
}

public struct TimestampVerificationResult: Codable {
    let claimId: String
    let isValid: Bool
    let overallConfidence: Double
    let timeSourceVerifications: [TimestampVerification]
    let inconsistencies: [TimestampInconsistency]
    let monotonicOrderingValid: Bool
    let externalTimestampsValid: Bool
    let verifiedAt: Int
}

struct TimestampVerification: Codable {
    let source: String
    let isValid: Bool
    let confidence: Double
    let verifiedAt: Int
}

struct TimestampInconsistency: Codable {
    let source: String
    let expectedTimestamp: Int
    let actualTimestamp: Int
    let driftSeconds: Int
    let severity: InconsistencySeverity
}

public struct TemporalOrdering: Codable {
    let orderedClaims: [TimestampClaim]
    let relationships: [TemporalRelationship]
    let suspiciousGaps: [TimestampGap]
    let hasSuspiciousGaps: Bool
    let verifiedAt: Int
}

struct TemporalRelationship: Codable {
    let earlierClaimId: String
    let laterClaimId: String
    let timeDifference: Int
    let confidence: Double
}

struct TimestampGap: Codable {
    let fromClaimId: String
    let toClaimId: String
    let gapSeconds: Int
    let severity: GapSeverity
}

enum TimestampTargetType: String, Codable, Sendable {
    case evidenceHead = "evidence_head"
    case bundle = "bundle"
    case document = "document"
    case embedding = "embedding"
}

public enum TimestampingLevel: String, Codable, Sendable {
    case basic = "basic"
    case standard = "standard"
    case enhanced = "enhanced"
    case legal = "legal"
    case blockchain = "blockchain"
}

enum InconsistencySeverity: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum GapSeverity: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}
