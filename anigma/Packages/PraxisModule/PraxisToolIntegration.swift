//
//  PraxisToolIntegration.swift
//  PraxisModule
//
//  [Brief description of file purpose]
//

import Foundation
import ContractsCore
import PraxisCore

/// Helper that registers Praxis tools with the shared tool registry.
public struct PraxisToolIntegration {
    public static func registerTools(with registry: SimpleToolRegistry, environment: PraxisModuleEnvironment) async {
        await registry.register(name: "praxis-diagnose", handler: SimpleToolAdapter.adapt(name: "praxis-diagnose") { request in
            let sessionID = request.arguments["sessionId"]
            let diagnosis = environment.diagnose(sessionID: sessionID)
            let envelope = PraxisDiagnosisEnvelope(praxisDiagnosis: diagnosis, command: "praxis-diagnose")
            guard let serialized = envelope.serialize() else {
                return .failure("Failed to encode diagnosis envelope")
            }
            return .success(serialized)
        })

        await registry.register(name: "praxis-boundary-ticket", handler: SimpleToolAdapter.adapt(name: "praxis-boundary-ticket") { request in
            guard let sessionID = request.arguments["sessionId"],
                  let reason = request.arguments["reason"],
                  let ruleIDs = request.arguments["ruleIds"] else {
                return .failure("Missing required arguments: sessionId, reason, ruleIds")
            }

            let patchHash = request.arguments["patchHash"]
            let gateName = request.arguments["gateName"]
            let violations = ruleIDs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let receipts = environment.sessionIndex.session(withID: sessionID)?
                .patchChains
                .first { $0.patchHash == patchHash }?
                .records
                .compactMap { $0.receiptID } ?? []
            let session = environment.sessionIndex.session(withID: sessionID)
            let specificChain = session?.patchChains.first { $0.patchHash == patchHash }
            let fallbackChain = session?.patchChains.first
            let targetChain = specificChain ?? fallbackChain
            let acceptanceRefs = targetChain?.acceptanceRefs ?? []
            let phaseId = targetChain?.phaseId

            let event = BlockageEvent(
                sessionID: sessionID,
                patchHash: patchHash,
                violatedRuleIDs: violations,
                gateName: gateName,
                receiptIDs: receipts,
                reason: reason,
                phaseId: phaseId,
                acceptanceRefs: acceptanceRefs,
                stopState: .blocked
            )

            do {
                let ticket = try environment.createBoundaryTicket(for: event)
                let envelope = BoundaryTicketEnvelope(ticket: ticket)
                guard let serialized = envelope.serialize() else {
                    return .failure("Failed to encode boundary ticket")
                }
                return .success(serialized)
            } catch {
                return .failure("Failed to create ticket: \(error)")
            }
        })
    }
}

private struct PraxisDiagnosisEnvelope: Encodable {
    let status = "ok"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let command: String
    let payload: PraxisDiagnosis

    init(praxisDiagnosis: PraxisDiagnosis, command: String) {
        self.command = command
        self.payload = praxisDiagnosis
    }

    func serialize() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct BoundaryTicketEnvelope: Encodable {
    let status = "ok"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let command = "praxis-boundary-ticket"
    let payload: BoundaryTicket

    init(ticket: BoundaryTicket) {
        self.payload = ticket
    }

    func serialize() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
