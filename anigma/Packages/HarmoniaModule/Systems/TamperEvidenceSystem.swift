//
//  TamperEvidenceSystem.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import AnigmaCore
import DatabaseCore
@preconcurrency import Foundation
@preconcurrency import CryptoKit
import ContractsCore

/// Tamper-evident evidence chain and bundle generation system
/// Makes entire custody chain tamper-detectable and exportable as admissible evidence
public actor TamperEvidenceSystem: TamperEvidenceSystemProtocol {
    private let dbActor: any DatabaseCore.DatabaseExecutor
    private let signingKey: SymmetricKey

    public init(dbActor: any DatabaseCore.DatabaseExecutor) async throws {
        self.dbActor = dbActor
        self.signingKey = SymmetricKey(size: .bits256)

        // Ensure tamper-evidence schema exists
        try await createTamperEvidenceSchema()
    }

    // MARK: - Evidence Chain Operations

    /// Append an immutable event to evidence chain
    public func appendEvent(
        eventType: String,
        payload: [String: Sendable],
        actor: String,
        actorIP: String? = nil,
        sessionId: String? = nil
    ) async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let timezone = TimeZone.current.identifier

        // Serialize payload to JSON and hash it
        let payloadJSON = try JSONSerialization.data(withJSONObject: payload)
        let payloadHash = sha256Hex(payloadJSON)
        let payloadString = String(data: payloadJSON, encoding: .utf8) ?? "{}"

        // Get previous hash for chaining
        let previousHash = try await getHeadHash()

        // Create event record with hash chaining
        let eventId = UUID().uuidString.lowercased()

        // Calculate event hash (including previous hash for chaining)
        let eventData: [String: Sendable] = [
            "eventId": eventId,
            "eventType": eventType,
            "timestamp": timestamp,
            "timezone": timezone,
            "payloadHash": payloadHash,
            "payload": payloadString,
            "actor": actor,
            "actorIP": actorIP ?? "",
            "sessionId": sessionId ?? "",
            "previousHash": previousHash,
            "bundleIds": [] as [String]
        ]

        let eventJSON = try JSONSerialization.data(withJSONObject: eventData)
        let eventHash = sha256Hex(eventJSON)

        // Store in database
        try await dbActor.execute("""
            INSERT INTO tamper_events (
                event_id, event_type, timestamp, timezone, payload_hash, payload,
                actor, actor_ip, session_id, previous_hash, event_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                DatabaseCore.dbp(eventId),
                DatabaseCore.dbp(eventType),
                DatabaseCore.dbp(timestamp),
                DatabaseCore.dbp(timezone),
                DatabaseCore.dbp(payloadHash),
                DatabaseCore.dbp(payloadString),
                DatabaseCore.dbp(actor),
                DatabaseCore.dbp(actorIP),
                DatabaseCore.dbp(sessionId),
                DatabaseCore.dbp(previousHash),
                DatabaseCore.dbp(eventHash)
            ])

        return eventId
    }

    // MARK: - Evidence Bundle Generation

    /// Create an evidence bundle for export and archival
    public func createBundle(
        bundleType: String,
        description: String,
        purpose: String,
        eventIds: [String]? = nil,
        artifactPaths: [String]? = nil,
        timeRangeHours: Int = 24
    ) async throws -> String {
        let bundleId = UUID().uuidString.lowercased()
        let createdAt = Int(Date().timeIntervalSince1970)

        // Calculate time range
        let startTime = createdAt - (timeRangeHours * 3600)

        // Get events to include
        let events: [[String: Sendable]]
        if let eventIds = eventIds, !eventIds.isEmpty {
            events = try await getEventsByIds(eventIds)
        } else {
            events = try await getEventsByTimeRange(startTime, endTime: createdAt)
        }

        // Create bundle manifest
        let manifest: [String: Sendable] = [
            "bundleId": bundleId,
            "bundleType": bundleType,
            "description": description,
            "purpose": purpose,
            "createdAt": createdAt,
            "timeRangeHours": timeRangeHours,
            "eventCount": events.count,
            "artifactPaths": artifactPaths ?? [] as [String],
            "manifestHash": "" // Will be calculated below
        ]

        // Calculate manifest hash
        let manifestJSON = try JSONSerialization.data(withJSONObject: manifest)
        let manifestHash = sha256Hex(manifestJSON)

        // Store bundle in database
        try await dbActor.execute("""
            INSERT INTO evidence_bundles (
                bundle_id, bundle_type, description, purpose, created_at,
                time_range_hours, event_count, manifest_hash, manifest_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                DatabaseCore.dbp(bundleId),
                DatabaseCore.dbp(bundleType),
                DatabaseCore.dbp(description),
                DatabaseCore.dbp(purpose),
                DatabaseCore.dbp(createdAt),
                DatabaseCore.dbp(timeRangeHours),
                DatabaseCore.dbp(events.count),
                DatabaseCore.dbp(manifestHash),
                DatabaseCore.dbp(String(data: manifestJSON, encoding: .utf8) ?? "{}")
            ])

        // Link events to bundle
        for event in events {
            guard let eventId = event["event_id"] as? String else {
                fatalError("Failed to cast to String")
            }
            try await dbActor.execute("""
                INSERT INTO bundle_events (bundle_id, event_id) VALUES (?, ?)
                """, parameters: [DatabaseCore.dbp(bundleId), DatabaseCore.dbp(eventId)])
        }

        return bundleId
    }

    /// Export evidence bundle as ZIP file or directory
    public func exportBundle(
        bundleId: String,
        format: BundleExportFormat = .zip,
        outputPath: String? = nil
    ) async throws -> String {
        // Get bundle details
        guard let bundle = try await getBundle(bundleId) else {
            throw EvidenceError.bundleNotFound(bundleId)
        }

        // Get bundle events
        let events = try await getBundleEvents(bundleId)

        // Create export directory
        let exportDir = outputPath ?? "/tmp/anigma-evidence-\(bundleId)"
        try FileManager.default.createDirectory(atPath: exportDir, withIntermediateDirectories: true)

        // Write manifest
        let manifestPath = "\(exportDir)/manifest.json"
        guard let manifestData = (bundle["manifest_json"] as? String) else {
            fatalError("Failed to cast to String")
        }
        try manifestData.write(to: URL(fileURLWithPath: manifestPath))

        // Write events
        let eventsDir = "\(exportDir)/events"
        try FileManager.default.createDirectory(atPath: eventsDir, withIntermediateDirectories: true)

        for event in events {
            guard let eventId = event["event_id"] as? String else {
                fatalError("Failed to cast to String")
            }
            let eventPath = "\(eventsDir)/\(eventId).json"
            let eventJSON = try JSONSerialization.data(withJSONObject: event, options: .prettyPrinted)
            try eventJSON.write(to: URL(fileURLWithPath: eventPath))
        }

        // Create chain integrity report
        let integrityReport = try await generateChainIntegrityReport()
        let reportPath = "\(exportDir)/chain-integrity.json"
        let reportData = try JSONSerialization.data(withJSONObject: [
            "totalEvents": integrityReport.totalEvents,
            "violations": integrityReport.violations.map { [
                "eventId": $0.eventId,
                "description": $0.description
            ]},
            "isIntact": integrityReport.isIntact,
            "headHash": integrityReport.headHash,
            "generatedAt": Int(Date().timeIntervalSince1970)
        ], options: .prettyPrinted)
        try reportData.write(to: URL(fileURLWithPath: reportPath))

        // Create README
        let readmeContent = generateReadme(bundle: bundle, eventCount: events.count)
        let readmePath = "\(exportDir)/README.md"
        try readmeContent.write(to: URL(fileURLWithPath: readmePath), atomically: true, encoding: .utf8)

        // Create ZIP if requested
        if format == .zip {
            let zipPath = "\(exportDir).zip"
            try await createZip(sourcePath: exportDir, zipPath: zipPath)

            // Clean up directory if zip was created successfully
            try FileManager.default.removeItem(atPath: exportDir)
            return zipPath
        }

        return exportDir
    }

    /// Verify evidence chain integrity
    public func verifyChain() async throws -> ChainIntegrityReport {
        let events = try await getAllEvents()
        var violations: [ChainViolation] = []
        var previousHash: String = ""

        for event in events {
            guard let eventId = event["event_id"] as? String else {
                fatalError("Failed to cast to String")
            }
            guard let storedHash = event["event_hash"] as? String else {
                fatalError("Failed to cast to String")
            }
            guard let expectedPreviousHash = event["previous_hash"] as? String else {
                fatalError("Failed to cast to String")
            }
            guard let eventType = event["event_type"] as? String else {
                fatalError("Failed to cast to String")
            }

            // Check hash chain integrity
            if previousHash != expectedPreviousHash {
                violations.append(ChainViolation(
                    eventId: eventId,
                    description: "Hash chain broken: expected previous hash '\(expectedPreviousHash)', got '\(previousHash)'"
                ))
            }

            // Recalculate and verify event hash
            let eventData: [String: Sendable] = [
                "eventId": eventId,
                "eventType": eventType,
                "timestamp": event["timestamp"] as! Int,
                "timezone": event["timezone"] as! String,
                "payloadHash": event["payload_hash"] as! String,
                "payload": event["payload"] as! String,
                "actor": event["actor"] as! String,
                "actorIP": event["actor_ip"] as! String,
                "sessionId": event["session_id"] as! String,
                "previousHash": expectedPreviousHash,
                "bundleIds": [] as [String]
            ]

            let eventJSON = try JSONSerialization.data(withJSONObject: eventData)
            let calculatedHash = sha256Hex(eventJSON)

            if calculatedHash != storedHash {
                violations.append(ChainViolation(
                    eventId: eventId,
                    description: "Event hash mismatch: stored '\(storedHash)', calculated '\(calculatedHash)'"
                ))
            }

            previousHash = storedHash
        }

        let headHash = try await getHeadHash()

        return ChainIntegrityReport(
            totalEvents: events.count,
            violations: violations,
            isIntact: violations.isEmpty,
            headHash: headHash
        )
    }

    // MARK: - Private Helper Methods

    private func createTamperEvidenceSchema() async throws {
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS tamper_events (
                event_id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                timezone TEXT NOT NULL,
                payload_hash TEXT NOT NULL,
                payload TEXT NOT NULL,
                actor TEXT NOT NULL,
                actor_ip TEXT,
                session_id TEXT,
                previous_hash TEXT NOT NULL,
                event_hash TEXT NOT NULL,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_tamper_events_timestamp ON tamper_events(timestamp)
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_tamper_events_actor ON tamper_events(actor)
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_tamper_events_type ON tamper_events(event_type)
            """)

        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS evidence_bundles (
                bundle_id TEXT PRIMARY KEY,
                bundle_type TEXT NOT NULL,
                description TEXT NOT NULL,
                purpose TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                time_range_hours INTEGER NOT NULL,
                event_count INTEGER NOT NULL,
                manifest_hash TEXT NOT NULL,
                manifest_json TEXT NOT NULL
            )
            """)

        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS bundle_events (
                bundle_id TEXT NOT NULL,
                event_id TEXT NOT NULL,
                PRIMARY KEY (bundle_id, event_id),
                FOREIGN KEY (bundle_id) REFERENCES evidence_bundles(bundle_id),
                FOREIGN KEY (event_id) REFERENCES tamper_events(event_id)
            )
            """)

        try await dbActor.execute("""
            CREATE INDEX IF NOT EXISTS idx_bundle_events_bundle ON bundle_events(bundle_id)
            """)
    }

    private func getHeadHash() async throws -> String {
        let result = try await dbActor.query("""
            SELECT event_hash FROM tamper_events
            ORDER BY timestamp DESC, event_id DESC
            LIMIT 1
            """)

        if let row = result.first {
            return row.string(for: "event_hash") ?? ""
        }

        // Genesis hash for empty chain
        return sha256Hex("genesis".data(using: .utf8) ?? Data())
    }

    private func getEventsByIds(_ eventIds: [String]) async throws -> [[String: Sendable]] {
        let sqlClause = sqlIn(eventIds)
        let result = try await dbActor.query("""
            SELECT * FROM tamper_events WHERE event_id IN \(sqlClause.clause)
            ORDER BY timestamp, event_id
            """, parameters: sqlClause.params)

        return convertDatabaseRows(result)
    }

    private func getEventsByTimeRange(_ startTime: Int, endTime: Int) async throws -> [[String: Sendable]] {
        let result = try await dbActor.query("""
            SELECT * FROM tamper_events
            WHERE timestamp >= ? AND timestamp <= ?
            ORDER BY timestamp, event_id
            """, parameters: [DatabaseCore.dbp(startTime), DatabaseCore.dbp(endTime)])

        return convertDatabaseRows(result)
    }

    private func getAllEvents() async throws -> [[String: Sendable]] {
        let result = try await dbActor.query("""
            SELECT * FROM tamper_events
            ORDER BY timestamp, event_id
            """)

        return convertDatabaseRows(result)
    }

    private func getBundle(_ bundleId: String) async throws -> [String: Sendable]? {
        let result = try await dbActor.query("""
            SELECT * FROM evidence_bundles WHERE bundle_id = ?
            """, parameters: [DatabaseCore.dbp(bundleId)])

        guard let row = result.first else { return nil }

        let converted = convertDatabaseRows([row])
        return converted.first
    }

    private func getBundleEvents(_ bundleId: String) async throws -> [[String: Sendable]] {
        let result = try await dbActor.query("""
            SELECT e.* FROM tamper_events e
            JOIN bundle_events be ON e.event_id = be.event_id
            WHERE be.bundle_id = ?
            ORDER BY e.timestamp, e.event_id
            """, parameters: [DatabaseCore.dbp(bundleId)])

        return convertDatabaseRows(result)
    }

    private func generateChainIntegrityReport() async throws -> ChainIntegrityReport {
        return try await verifyChain()
    }

    private func createZip(sourcePath: String, zipPath: String) async throws {
        // Use system zip command for reliability
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "."]
        process.currentDirectoryURL = URL(fileURLWithPath: sourcePath)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw EvidenceError.exportFailed("ZIP creation failed with exit code \(process.terminationStatus)")
        }
    }

    private func generateReadme(bundle: [String: Sendable], eventCount: Int) -> String {
        return """
        # Anigma Evidence Bundle

        ## Bundle Information
        - **Bundle ID**: \(bundle["bundle_id"] as! String)
        - **Type**: \(bundle["bundle_type"] as! String)
        - **Description**: \(bundle["description"] as! String)
        - **Purpose**: \(bundle["purpose"] as! String)
        - **Created**: \(Date(timeIntervalSince1970: TimeInterval(bundle["created_at"] as! Int)))
        - **Events Included**: \(eventCount)
        - **Time Range**: \(bundle["time_range_hours"] as! Int) hours

        ## Contents

        - `manifest.json` - Bundle manifest with metadata
        - `events/` - Individual tamper-evident event records
        - `chain-integrity.json` - Chain integrity verification report
        - `README.md` - This file

        ## Verification

        Each event in this bundle is cryptographically linked to the previous event,
        forming an immutable chain. Any modification to any event will break the
        hash chain and be detected during verification.

        The chain-integrity.json file contains the results of automatic integrity
        verification performed at export time.

        ## Legal Admissibility

        This evidence bundle provides:
        - Cryptographic proof of integrity
        - Complete audit trail with timestamps
        - Actor attribution and session context
        - Reproducible verification process
        - Chain of custody documentation

        Generated by Anigma Harmonia Tamper-Evidence System.
        """
    }

    private func convertDatabaseRows(_ rows: [DatabaseRow]) -> [[String: Sendable]] {
        return rows.map { row in
            var dict: [String: Sendable] = [:]
            // Get all column names by trying common ones and using row subscript
            let columns = ["event_id", "event_type", "timestamp", "timezone", "payload_hash", "payload",
                          "actor", "actor_ip", "session_id", "previous_hash", "event_hash", "created_at",
                          "bundle_id", "bundle_type", "description", "purpose", "created_at",
                          "time_range_hours", "event_count", "manifest_hash", "manifest_json"]

            for column in columns {
                if let stringValue = row.string(for: column) {
                    dict[column] = stringValue
                } else if let intValue = row.int(for: column) {
                    dict[column] = intValue
                } else if let doubleValue = row.double(for: column) {
                    dict[column] = doubleValue
                }
            }
            return dict
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supporting Types

public enum BundleExportFormat: String, CaseIterable {
    case zip = "zip"
    case tar = "tar"
    case directory = "directory"
}

// MARK: - Error Types

enum EvidenceError: Error, LocalizedError {
    case bundleNotFound(String)
    case chainCorrupted
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundleNotFound(let id):
            return "Bundle not found: \(id)"
        case .chainCorrupted:
            return "Evidence chain is corrupted"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
