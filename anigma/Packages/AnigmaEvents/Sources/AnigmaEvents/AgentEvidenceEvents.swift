import Foundation
import AnigmaPrimitives

public struct AgentEvidenceArtifactReference: Sendable, Codable, Hashable {
    public let artifactID: String
    public let role: String
    public let contentHash: String?
    public let referenceURI: String?
    public let metadata: [String: String]

    public init(
        artifactID: String,
        role: String,
        contentHash: String? = nil,
        referenceURI: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.artifactID = artifactID
        self.role = role
        self.contentHash = contentHash
        self.referenceURI = referenceURI
        self.metadata = metadata
    }
}

public struct AgentEvidenceEvent: AnigmaEvent, Codable {
    public static let eventType = "agent.evidence.recorded"

    public let evidenceID: String
    public let timestamp: Date
    public let source: String
    public let category: String
    public let action: String
    public let outcome: String
    public let traceID: String
    public let spanID: String?
    public let parentSpanID: String?
    public let runID: String?
    public let sessionID: String?
    public let jobID: String?
    public let toolID: String?
    public let requestID: String?
    public let receiptID: String?
    public let payloadArtifactReferences: [AgentEvidenceArtifactReference]
    public let metadata: [String: String]?

    public init(
        evidenceID: String = UUID().uuidString,
        timestamp: Date = Date(),
        source: String,
        category: String,
        action: String,
        outcome: String,
        traceID: String,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        runID: String? = nil,
        sessionID: String? = nil,
        jobID: String? = nil,
        toolID: String? = nil,
        requestID: String? = nil,
        receiptID: String? = nil,
        payloadArtifactReferences: [AgentEvidenceArtifactReference] = [],
        metadata: [String: String]? = nil
    ) {
        self.evidenceID = evidenceID
        self.timestamp = timestamp
        self.source = source
        self.category = category
        self.action = action
        self.outcome = outcome
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.runID = runID
        self.sessionID = sessionID
        self.jobID = jobID
        self.toolID = toolID
        self.requestID = requestID
        self.receiptID = receiptID
        self.payloadArtifactReferences = payloadArtifactReferences
        self.metadata = metadata
    }

    public var description: String {
        var parts: [String] = [
            "AgentEvidenceEvent(id: \"\(evidenceID)\")",
            "source: \"\(source)\"",
            "action: \"\(action)\"",
            "outcome: \"\(outcome)\"",
            "trace: \"\(traceID)\""
        ]

        if let runID {
            parts.append("run: \"\(runID)\"")
        }
        if let toolID {
            parts.append("tool: \"\(toolID)\"")
        }
        if let jobID {
            parts.append("job: \"\(jobID)\"")
        }

        return parts.joined(separator: ", ")
    }
}

public extension AgentEvidenceEvent {
    static func toolExecution(
        source: String,
        action: String = "tool.execution",
        outcome: String,
        traceID: String,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        runID: String? = nil,
        sessionID: String? = nil,
        jobID: String? = nil,
        toolID: String,
        requestID: String? = nil,
        receiptID: String? = nil,
        payloadArtifactReferences: [AgentEvidenceArtifactReference] = [],
        metadata: [String: String] = [:]
    ) -> AgentEvidenceEvent {
        AgentEvidenceEvent(
            source: source,
            category: "agent.tool",
            action: action,
            outcome: outcome,
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            runID: runID,
            sessionID: sessionID,
            jobID: jobID,
            toolID: toolID,
            requestID: requestID,
            receiptID: receiptID,
            payloadArtifactReferences: payloadArtifactReferences,
            metadata: metadata
        )
    }

    static func jobLifecycle(
        source: String,
        action: String,
        outcome: String,
        traceID: String,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        runID: String? = nil,
        sessionID: String? = nil,
        jobID: String,
        toolID: String? = nil,
        requestID: String? = nil,
        receiptID: String? = nil,
        payloadArtifactReferences: [AgentEvidenceArtifactReference] = [],
        metadata: [String: String] = [:]
    ) -> AgentEvidenceEvent {
        AgentEvidenceEvent(
            source: source,
            category: "agent.job",
            action: action,
            outcome: outcome,
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            runID: runID,
            sessionID: sessionID,
            jobID: jobID,
            toolID: toolID,
            requestID: requestID,
            receiptID: receiptID,
            payloadArtifactReferences: payloadArtifactReferences,
            metadata: metadata
        )
    }

    static func artifactWrite(
        source: String,
        action: String = "artifact.write",
        outcome: String,
        traceID: String,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        runID: String? = nil,
        sessionID: String? = nil,
        jobID: String? = nil,
        toolID: String? = nil,
        requestID: String? = nil,
        receiptID: String? = nil,
        payloadArtifactReferences: [AgentEvidenceArtifactReference],
        metadata: [String: String] = [:]
    ) -> AgentEvidenceEvent {
        AgentEvidenceEvent(
            source: source,
            category: "agent.artifact",
            action: action,
            outcome: outcome,
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            runID: runID,
            sessionID: sessionID,
            jobID: jobID,
            toolID: toolID,
            requestID: requestID,
            receiptID: receiptID,
            payloadArtifactReferences: payloadArtifactReferences,
            metadata: metadata
        )
    }
}
