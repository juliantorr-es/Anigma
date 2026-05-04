//
//  GovernanceExtensions.swift
//  AnigmaFoundation
//
//  Extension methods for GoverningController to support CLI governance operations.
//

import Foundation
import GovernanceCore
import AnigmaPrimitives
import ContractsCore

public extension GoverningController {

    /// Check if write is allowed for a principal through all governance gates.
    /// - Parameter principal: The principal requesting write access
    /// - Throws: GovernanceError if write is not allowed
    func checkWriteAllowed(for principal: AccessPrincipal) async throws {
        let proposal = WriteProposal(
            principal: principal.id,
            module: principal.module,
            operation: "database_mutation",
            componentType: "database"
        )

        let decision = await canWrite(proposal)

        if !decision.allowed {
            let projectId = principal.attributes["project_id"]
            let modeSource = await modeSource(for: projectId)
            
            let failedChecks = decision.failedChecks.map { 
                GovernanceViolation.FailedCheck(checkId: $0.checkId, message: $0.message) 
            }
            
            let violation = GovernanceViolation(
                principal: principal.id,
                projectId: projectId,
                operation: "database_mutation",
                module: principal.module,
                evaluatedModeSource: modeSource.rawValue,
                failedChecks: failedChecks
            )
            
            let auditLog = await self.auditLog
            try? await auditLog.recordEvent(
                id: UUID(),
                type: AuditEventType.policyViolation,
                principal: principal.id,
                module: "Governance",
                description: "Write blocked: \(violation.summaryMessage)",
                metadata: violation.auditMetadata
            )
            
            throw GovernanceError.writeBlocked(violation: violation)
        }
    }

    /// Check if the kill switch is active and writes are blocked.
    /// - Throws: GovernanceError if kill switch is active
    func checkKillSwitch() async throws {
        let status = await killSwitchStatus()
        
        if status.isActive {
            throw GovernanceError.killSwitchActive(reason: status.activationReason ?? "Global Halt")
        }
    }

    /// Check policy compliance for a specific operation.
    /// - Parameters:
    ///   - operation: The SQL operation to check
    ///   - principal: The principal performing the operation
    /// - Throws: GovernanceError if policy compliance fails
    func checkPolicyCompliance(operation: String, principal: AccessPrincipal) async throws {
        // Extract resource from SQL for policy evaluation
        let resource = extractResourceFromSQL(operation)
        
        let request = AccessRequest(
            principal: principal,
            componentType: "database",
            sensitivity: .internal, // Default sensitivity for database operations
            accessType: .write,
            entityId: resource
        )
        
        try await accessController.checkAccess(request)
    }

    /// Extract resource identifier from SQL for policy evaluation.
    /// - Parameter sql: The SQL statement to analyze
    /// - Returns: EntityId representing the resource being accessed
    private func extractResourceFromSQL(_ sql: String) -> EntityId? {
        let lowercased = sql.lowercased()
        
        // Simple pattern matching to extract table names
        if lowercased.contains("where") || lowercased.contains("into") || lowercased.contains("from") {
            let patterns = ["where\\s+(\\w+)", "into\\s+(\\w+)", "from\\s+(\\w+)", "update\\s+(\\w+)", "delete\\s+from\\s+(\\w+)"]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: sql, range: NSRange(sql.startIndex..., in: sql)),
                   match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    if let substringRange = Range(range, in: sql) {
                        let tableName = String(sql[substringRange])
                        return EntityId(uuidString: "table:" + tableName)
                    }
                }
            }
        }
        
        return nil
    }
}

// MARK: - Governance Violation Types

/// Extension type for governance violation handling in AnigmaFoundation.
/// NOTE: Renamed from GovernanceViolation to avoid collision with GovernanceCore.GovernanceViolation
public struct AnigmaGovernanceViolation: Sendable {
    public let principal: String
    public let projectId: String?
    public let operation: String
    public let module: String
    public let evaluatedModeSource: String
    public let failedChecks: [FailedCheck]
    
    public var summaryMessage: String {
        "Governance violation by \(principal) in \(module): \(operation)"
    }
    
    public var auditMetadata: [String: String] {
        var metadata: [String: String] = [
            "principal": principal,
            "operation": operation,
            "module": module,
            "modeSource": evaluatedModeSource
        ]
        
        if let projectId = projectId {
            metadata["projectId"] = projectId
        }
        
        for (index, check) in failedChecks.enumerated() {
            metadata["failedCheck_\(index)"] = "\(check.checkId): \(check.message)"
        }
        
        return metadata
    }
    
    public struct FailedCheck: Sendable {
        public let checkId: String
        public let message: String
    }
}

// Keep typealias for backward compatibility if needed
public typealias GovernanceViolation = AnigmaGovernanceViolation
