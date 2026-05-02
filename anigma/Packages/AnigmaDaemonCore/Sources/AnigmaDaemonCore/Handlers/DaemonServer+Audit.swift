//
//  DaemonServer+Audit.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import ExecutionCore
import TelemetryCore
import AnigmaPrimitives

extension DaemonServer {
    // MARK: - CoreReceipt Verification

    func handleGetReceipt(
        ctx: DaemonRequestContext,
        receiptHash: String
    ) async -> (receipt: ReceiptWire?, error: ErrorStatus?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
             return (nil, ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "audit.read")
        } catch {
            return (
                nil,
                ErrorStatus(
                    code: "AUTH_DENIED",
                    message: error.localizedDescription,
                    detailJson: nil
                )
            )
        }

        guard isValidReceiptHash(receiptHash) else {
            return (
                nil,
                ErrorStatus(
                    code: "INVALID_RECEIPT_HASH",
                    message: "Invalid receipt hash: \(receiptHash)",
                    detailJson: nil
                )
            )
        }

        guard let receipt = try? await receiptEngine.retrieveReceipt(receiptID: receiptHash) else {
            return (
                nil,
                ErrorStatus(
                    code: "RECEIPT_NOT_FOUND",
                    message: "CoreReceipt not found: \(receiptHash)",
                    detailJson: nil
                )
            )
        }
        return (receipt, nil)
    }

    func handleVerifyChain(
        ctx: DaemonRequestContext,
        headReceiptHash: String
    ) async -> (ok: Bool, message: String, error: ErrorStatus?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return (false, "Rate limit exceeded", ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "audit.read")
        } catch {
            return (
                false,
                "Audit access denied",
                ErrorStatus(
                    code: "AUTH_DENIED",
                    message: error.localizedDescription,
                    detailJson: nil
                )
            )
        }

        guard isValidReceiptHash(headReceiptHash) else {
            return (
                false,
                "Invalid receipt hash",
                ErrorStatus(
                    code: "INVALID_RECEIPT_HASH",
                    message: "Invalid receipt hash: \(headReceiptHash)",
                    detailJson: nil
                )
            )
        }

        var chain: [ReceiptWire] = []
        var currentHash: String? = headReceiptHash
        let maxDepth = 1000
        var depth = 0

        while let hash = currentHash, depth < maxDepth {
            guard let receipt = try? await receiptEngine.retrieveReceipt(receiptID: hash) else {
                return (
                    false,
                    "Chain broken: missing receipt \(hash)",
                    ErrorStatus(
                        code: "RECEIPT_NOT_FOUND",
                        message: "CoreReceipt not found: \(hash)",
                        detailJson: nil
                    )
                )
            }

            chain.append(receipt)
            currentHash = receipt.previousReceiptHash
            depth += 1
        }

        if depth >= maxDepth {
            return (
                false,
                "Chain too long or cycle detected",
                ErrorStatus(code: "CHAIN_TOO_LONG", message: "Chain too long", detailJson: nil)
            )
        }

        do {
            let valid = try await receiptEngine.verifyChain(receipts: chain)
            if valid {
                return (true, "Chain verified", nil)
            }
            return (false, "Verification failed", ErrorStatus(code: "CHAIN_VERIFICATION_FAILED", message: "Verification failed", detailJson: nil))
        } catch {
            return (false, "Verification error: \(error.localizedDescription)", ErrorStatus(code: "CHAIN_VERIFICATION_FAILED", message: error.localizedDescription, detailJson: nil))
        }
    }

    func handleTelemetryEvent(
        ctx: DaemonRequestContext,
        event: AnigmaTelemetryEvent
    ) async -> (accepted: Bool, error: String?, receiptHash: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return (false, "Rate limit exceeded", nil)
        }

        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "telemetry.write")
        } catch {
            let receiptHash = await recordTelemetryReceipt(
                ctx: ctx,
                event: event,
                decision: .denied,
                reasonCode: "AUTH_DENIED",
                error: error.localizedDescription
            )
            return (false, error.localizedDescription, receiptHash)
        }

        do {
            let decoded = try decodeTelemetryPayload(event.payloadJson)
            var values = decoded.values
            values["stream_type"] = .hashedToken(TelemetryHash(input: event.type))
            values["streamed_at_ms"] = .integer64(Int64(event.atUnixMs))
            values["client_id"] = .hashedToken(TelemetryHash(input: ctx.clientId))

            let result = await telemetry.emit(
                category: decoded.category,
                name: decoded.name,
                privacyClassification: decoded.privacyClassification,
                values: values
            )
            switch result {
            case .success:
                let receiptHash = await recordTelemetryReceipt(
                    ctx: ctx,
                    event: event,
                    decision: .allowed,
                    reasonCode: "TELEMETRY_ACCEPTED",
                    error: nil
                )
                return (true, nil, receiptHash)
            case .failure(let error):
                return (false, error.localizedDescription, nil)
            }
        } catch {
            return (false, error.localizedDescription, nil)
        }
    }

    func handleTelemetryStreamSummary(
        ctx: DaemonRequestContext,
        accepted: Int,
        rejected: Int,
        lastReceiptHash: String?
    ) async {
        guard configuration.governance.auditAllOperations else { return }
        do {
            _ = try await receiptEngine.recordActionExecution(
                actionName: "telemetry.stream",
                authority: "anigmad",
                decision: rejected == 0 ? .allowed : .error,
                reasonCode: rejected == 0 ? "TELEMETRY_ACCEPTED" : "TELEMETRY_REJECTED",
                inputs: ["client_id": ctx.clientId],
                outputs: [
                    "accepted": accepted,
                    "rejected": rejected,
                    "last_receipt_hash": lastReceiptHash ?? "none"
                ]
            )
        } catch {
            Self.logger.error("CoreReceipt warning: failed to record telemetry stream receipt: \(error.localizedDescription, privacy: .public)")
        }
    }

    func isValidReceiptHash(_ hash: String) -> Bool {
        return hash.count == 64 && hash.allSatisfy { $0.isHexDigit }
    }

    func decodeTelemetryPayload(_ payloadJson: String) throws -> TelemetryEvent {
        let data = Data(payloadJson.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TelemetryEvent.self, from: data)
    }

    func recordTelemetryReceipt(ctx: DaemonRequestContext, event: AnigmaTelemetryEvent, decision: ReceiptDecision, reasonCode: String, error: String?) async -> String? {
        let receipt = try? await receiptEngine.recordActionExecution(
            actionName: "telemetry.event",
            authority: "anigmad",
            decision: decision,
            reasonCode: reasonCode,
            inputs: ["client_id": ctx.clientId, "event_type": event.type],
            outputs: ["error": error ?? "none"]
        )
        return receipt?.receiptID
    }
}
