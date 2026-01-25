//
//  ReuseGate.swift
//  HarmoniaModule
//
//  Gatekeeper for code reuse policy.
//  Evaluates creation operations against canonical abstractions.
//  Prevents duplication of core architectural components.
//

@preconcurrency import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Reuse Gate Policy

/// Enforcement strictness for reuse gate.
public enum ReuseGatePolicy: String, Sendable, Codable {
    /// Permissive: Log duplication warnings but allow creation.
    case permissive

    /// Strict: Require justification for duplication; block obvious duplication.
    case strict

    /// CI: Strict enforcement for CI pipelines; fail on duplication.
    case ci
}

// MARK: - Reuse Gate Result

/// Result of a reuse gate evaluation.
public struct ReuseGateResult: Sendable, Codable {
    /// Whether creation is allowed.
    public let allowed: Bool

    /// Required justification level.
    public enum JustificationLevel: String, Sendable, Codable {
        /// No justification needed.
        case none

        /// Brief justification required (1-2 sentences).
        case brief

        /// Detailed justification required (paragraph with concrete alternatives).
        case detailed

        /// Architectural review required (block until human review).
        case review
    }

    /// Required justification level.
    public let requiredJustification: JustificationLevel

    /// Suggested alternatives (canonical abstractions to reuse).
    public let alternatives: [CanonicalAbstraction]

    /// Explanation for the decision.
    public let explanation: String

    /// Whether to add duplication warning to code.
    public let addDuplicationWarning: Bool

    /// Warning message for duplication warning.
    public let duplicationWarningMessage: String?

    public init(
        allowed: Bool,
        requiredJustification: JustificationLevel,
        alternatives: [CanonicalAbstraction] = [],
        explanation: String,
        addDuplicationWarning: Bool = false,
        duplicationWarningMessage: String? = nil
    ) {
        self.allowed = allowed
        self.requiredJustification = requiredJustification
        self.alternatives = alternatives
        self.explanation = explanation
        self.addDuplicationWarning = addDuplicationWarning
        self.duplicationWarningMessage = duplicationWarningMessage
    }

    /// Allows creation without justification.
    public static let allow = ReuseGateResult(
        allowed: true,
        requiredJustification: .none,
        explanation: "Creation allowed"
    )

    /// Blocks creation.
    public static func block(alternatives: [CanonicalAbstraction], explanation: String) -> ReuseGateResult {
        ReuseGateResult(
            allowed: false,
            requiredJustification: .none,
            alternatives: alternatives,
            explanation: explanation,
            addDuplicationWarning: false
        )
    }

    /// Requires justification for creation.
    public static func requireJustification(
        level: JustificationLevel,
        alternatives: [CanonicalAbstraction],
        explanation: String,
        addDuplicationWarning: Bool = false
    ) -> ReuseGateResult {
        ReuseGateResult(
            allowed: true,
            requiredJustification: level,
            alternatives: alternatives,
            explanation: explanation,
            addDuplicationWarning: addDuplicationWarning,
            duplicationWarningMessage: "DUPLICATION: This overlaps with \(alternatives.map { $0.name }.joined(separator: ", ")). Consider extending existing abstractions instead."
        )
    }
}

// MARK: - Creation Context

/// Context for a creation operation.
public struct CreationContext: Sendable, Codable {
    /// Tool name (e.g., "write_file", "edit_file").
    public let toolName: String

    /// File path being created/modified.
    public let filePath: String

    /// File content being written.
    public let content: String?

    /// Agent mode (plan, build, ci).
    public let agentMode: String

    /// Session ID for logging.
    public let sessionId: String

    /// Tool call ID for linking to observations.
    public let toolCallId: String

    /// Additional metadata.
    public let metadata: [String: String]

    public init(
        toolName: String,
        filePath: String,
        content: String? = nil,
        agentMode: String,
        sessionId: String,
        toolCallId: String,
        metadata: [String: String] = [:]
    ) {
        self.toolName = toolName
        self.filePath = filePath
        self.content = content
        self.agentMode = agentMode
        self.sessionId = sessionId
        self.toolCallId = toolCallId
        self.metadata = metadata
    }
}

// MARK: - Reuse Gate Protocol

/// Protocol for code reuse gatekeeping.
public protocol ReuseGate: Sendable {
    /// Policy for this gate.
    var policy: ReuseGatePolicy { get }

    /// Evaluates a creation operation.
    /// - Parameter context: Creation context.
    /// - Returns: Reuse gate result.
    func evaluate(context: CreationContext) async -> ReuseGateResult

    /// Logs a reuse decision (for audit trail).
    func logDecision(context: CreationContext, result: ReuseGateResult) async
}

/// Sink for persisting reuse gate decisions.
public protocol ReuseGateDecisionSink: Sendable {
    func record(decision: ReuseGateDecision) async
}

/// Reuse gate decision payload for auditing.
public struct ReuseGateDecision: Sendable, Codable {
    public let timestamp: Date
    public let context: CreationContext
    public let result: ReuseGateResult

    public init(
        timestamp: Date = Date(),
        context: CreationContext,
        result: ReuseGateResult
    ) {
        self.timestamp = timestamp
        self.context = context
        self.result = result
    }
}

// MARK: - No-Op Reuse Gate

/// No-op implementation that logs to console.
public actor NoOpReuseGate: ReuseGate {
    public let policy: ReuseGatePolicy
    private let decisionSink: ReuseGateDecisionSink?

    /// Statistics for current session.
    public struct Statistics: Sendable, Codable {
        public var totalEvaluations: Int = 0
        public var allowedCreations: Int = 0
        public var blockedCreations: Int = 0
        public var warningsAdded: Int = 0
        public var justificationsRequired: Int = 0
    }

    /// Current statistics.
    public private(set) var statistics = Statistics()

    public init(policy: ReuseGatePolicy = .permissive, decisionSink: ReuseGateDecisionSink? = nil) {
        self.policy = policy
        self.decisionSink = decisionSink
    }

    public func evaluate(context: CreationContext) async -> ReuseGateResult {
        statistics.totalEvaluations += 1

        // Basic detection: check if file is Swift and contains class/struct/enum/protocol
        guard isSwiftFile(context.filePath) else {
            statistics.allowedCreations += 1
            return .allow
        }

        guard let content = context.content else {
            statistics.allowedCreations += 1
            return .allow
        }

        // Check for canonical abstraction patterns
        let detectedAbstractions = detectCanonicalAbstractions(in: content)

        if !detectedAbstractions.isEmpty {
            // Found potential duplication
            let alternatives = findAlternatives(for: detectedAbstractions)

            switch policy {
            case .permissive:
                statistics.warningsAdded += 1
                return .requireJustification(
                    level: .brief,
                    alternatives: alternatives,
                    explanation: "Potential duplication of canonical abstractions detected.",
                    addDuplicationWarning: true
                )

            case .strict:
                statistics.justificationsRequired += 1
                return .requireJustification(
                    level: .detailed,
                    alternatives: alternatives,
                    explanation: "Potential duplication of canonical abstractions detected. Detailed justification required.",
                    addDuplicationWarning: true
                )

            case .ci:
                statistics.blockedCreations += 1
                return .block(
                    alternatives: alternatives,
                    explanation: "CI policy blocks duplication of canonical abstractions."
                )
            }
        }

        statistics.allowedCreations += 1
        return .allow
    }

    public func logDecision(context: CreationContext, result: ReuseGateResult) async {
        print("[ReuseGate] \(context.toolName) @ \(context.filePath)")
        print("  Result: \(result.allowed ? "ALLOWED" : "BLOCKED")")
        if !result.alternatives.isEmpty {
            print("  Alternatives: \(result.alternatives.map { $0.name }.joined(separator: ", "))")
        }
        if result.requiredJustification != .none {
            print("  Justification required: \(result.requiredJustification)")
        }
        print("  Explanation: \(result.explanation)")

        if let decisionSink {
            await decisionSink.record(decision: ReuseGateDecision(context: context, result: result))
        }
    }

    // MARK: - Detection Helpers

    private func isSwiftFile(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return url.pathExtension.lowercased() == "swift"
    }

    private func detectCanonicalAbstractions(in content: String) -> [String] {
        let syntax = Parser.parse(source: content)
        let visitor = DeclarationNameVisitor()
        visitor.walk(syntax)
        return visitor.names
    }

    private func findAlternatives(for detectedNames: [String]) -> [CanonicalAbstraction] {
        var alternatives: [CanonicalAbstraction] = []

        for name in detectedNames {
            if let abstraction = ArchitectureManifest.abstraction(named: name) {
                alternatives.append(abstraction)
            } else {
                // Search by concept
                let matches = ArchitectureManifest.findMatches(for: name)
                alternatives.append(contentsOf: matches)
            }
        }

        // Remove duplicates
        var seenIDs = Set<UUID>()
        return alternatives.filter { seenIDs.insert($0.id).inserted }
    }
}

private final class DeclarationNameVisitor: SyntaxVisitor {
    private(set) var names: [String] = []

    override init(viewMode: SyntaxTreeViewMode = .fixedUp) {
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        names.append(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        names.append(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        names.append(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        names.append(node.name.text)
        return .visitChildren
    }
}

// MARK: - Default Reuse Gate

extension ReuseGatePolicy {
    /// Default reuse gate for agent mode.
    public func defaultReuseGate() -> any ReuseGate {
        switch self {
        case .permissive, .strict, .ci:
            return NoOpReuseGate(policy: self)
        }
    }
}
