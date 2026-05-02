import Foundation

public struct AuditEvent: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let tenantId: String
    public let actorId: String
    public let action: String
    public let resource: String
    public let connectorId: String?
    public let status: String
    public let metadata: [String: String]

    public init(tenantId: String, actorId: String, action: String, resource: String, connectorId: String?, status: String, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.timestamp = Date()
        self.tenantId = tenantId
        self.actorId = actorId
        self.action = action
        self.resource = resource
        self.connectorId = connectorId
        self.status = status
        self.metadata = metadata
    }
}

public actor AuditLogger {
    public static let shared = AuditLogger()
    private var logStore: [AuditEvent] = []

    private init() {}

    public func log(_ event: AuditEvent) {
        logStore.append(event)
        // In a real system, this would flush to disk or a remote collector
        print("AUDIT: [\(event.timestamp)] Tenant:\(event.tenantId) Actor:\(event.actorId) Action:\(event.action) Status:\(event.status)")
    }

    public func exportLogs(forTenant tenantId: String, from: Date, to: Date) -> [AuditEvent] {
        logStore.filter {
            $0.tenantId == tenantId && $0.timestamp >= from && $0.timestamp <= to
        }
    }

    public func exportLogsAsCSV(forTenant tenantId: String) -> String {
        let logs = exportLogs(forTenant: tenantId, from: Date.distantPast, to: Date.distantFuture)
        var csv = "Timestamp,ID,Actor,Action,Resource,Connector,Status,Metadata\n"
        let formatter = ISO8601DateFormatter()

        for log in logs {
            let metaString = log.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            let line = "\(formatter.string(from: log.timestamp)),\(log.id),\(log.actorId),\(log.action),\(log.resource),\(log.connectorId ?? ""),\(log.status),\"\(metaString)\"\n"
            csv.append(line)
        }
        return csv
    }
}
