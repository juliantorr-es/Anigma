//
//  MakerReceipt.swift
//  AnigmaCore
//
//  CoreReceipt and ledger types for MakerEngine enhancement runs.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import Foundation
import CryptoKit
import ContractsCore

/// Deterministic core fields for a Maker enhancement receipt.
public struct MakerReceiptCore: Sendable, Codable {
    public let deterministicStepId: String
    public let stepId: String
    public let sessionId: String
    public let workflowId: String
    public let inputHash: String
    public let outputHash: String
    /// Adapter identifiers mapped to stable adapter versions.
    public let adapterIdentifiers: [String: String]
    public let policyDecision: String?
    public let quarantineDecision: String?
    public let resourceLimitExceeded: Bool
    public let limits: MakerResourceLimits
    public let enhancementEnabled: Bool
    public let enhancementCodeVersion: String

    public init(
        deterministicStepId: String,
        stepId: String,
        sessionId: String,
        workflowId: String,
        inputHash: String,
        outputHash: String,
        adapterIdentifiers: [String: String],
        policyDecision: String?,
        quarantineDecision: String?,
        resourceLimitExceeded: Bool,
        limits: MakerResourceLimits,
        enhancementEnabled: Bool,
        enhancementCodeVersion: String
    ) {
        self.deterministicStepId = deterministicStepId
        self.stepId = stepId
        self.sessionId = sessionId
        self.workflowId = workflowId
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.adapterIdentifiers = adapterIdentifiers
        self.policyDecision = policyDecision
        self.quarantineDecision = quarantineDecision
        self.resourceLimitExceeded = resourceLimitExceeded
        self.limits = limits
        self.enhancementEnabled = enhancementEnabled
        self.enhancementCodeVersion = enhancementCodeVersion
    }
}

/// Observational envelope that is intentionally non-deterministic.
public struct MakerReceiptObservational: Sendable, Codable {
    public let durationMs: Double
    public let memoryUsedBytes: Int
    /// Optional notes for determinism tracking (for example, "not_seedable" markers).
    public let determinismNotes: [String]?
    /// Indicates determinism check pass/fail when explicitly evaluated.
    public let determinismCheckPassed: Bool?

    public init(
        durationMs: Double,
        memoryUsedBytes: Int,
        determinismNotes: [String]? = nil,
        determinismCheckPassed: Bool? = nil
    ) {
        self.durationMs = durationMs
        self.memoryUsedBytes = memoryUsedBytes
        self.determinismNotes = determinismNotes
        self.determinismCheckPassed = determinismCheckPassed
    }
}

/// CoreReceipt container with deterministic core and optional observational envelope.
public struct MakerReceipt: Sendable, Codable {
    public let core: MakerReceiptCore
    public let observational: MakerReceiptObservational?

    public init(core: MakerReceiptCore, observational: MakerReceiptObservational? = nil) {
        self.core = core
        self.observational = observational
    }
}

/// Pointer stored in the command ledger.
public struct MakerReceiptPointer: Sendable, Codable {
    public let runId: String
    public let stepId: String
    public let receiptPath: String
    public let receiptHash: String

    public init(runId: String, stepId: String, receiptPath: String, receiptHash: String) {
        self.runId = runId
        self.stepId = stepId
        self.receiptPath = receiptPath
        self.receiptHash = receiptHash
    }
}

/// Persistence contract for receipts.
public protocol MakerReceiptPersisting: Sendable {
    func persist(receipt: MakerReceipt, runId: String, stepId: StepId) throws -> MakerReceiptPointer
}

/// File-backed receipt persistence with JSONL ledger pointers.
public struct FileMakerReceiptPersister: MakerReceiptPersisting {
    private let receiptsRoot: String
    private let ledgerPath: String

    public init(
        receiptsRoot: String = "Artifacts/maker/receipts",
        ledgerPath: String = ".opencode/ledger/maker-receipts.jsonl"
    ) {
        self.receiptsRoot = receiptsRoot
        self.ledgerPath = ledgerPath
    }

    public func persist(receipt: MakerReceipt, runId: String, stepId: StepId) throws -> MakerReceiptPointer {
        let fm = FileManager.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let runDir = URL(fileURLWithPath: receiptsRoot, isDirectory: true)
            .appendingPathComponent(runId, isDirectory: true)
        try fm.createDirectory(at: runDir, withIntermediateDirectories: true)

        let receiptURL = runDir.appendingPathComponent("\(stepId.value).json", isDirectory: false)
        let data = try encoder.encode(receipt)
        try data.write(to: receiptURL, options: [.atomic])

        let receiptHash = Self.blake3Hex(of: data)
        let pointer = MakerReceiptPointer(
            runId: runId,
            stepId: stepId.value,
            receiptPath: receiptURL.path,
            receiptHash: receiptHash
        )

        try appendLedgerRecord(pointer: pointer)
        return pointer
    }

    private func appendLedgerRecord(pointer: MakerReceiptPointer) throws {
        let fm = FileManager.default
        let ledgerURL = URL(fileURLWithPath: ledgerPath, isDirectory: false)
        if let parent = ledgerURL.deletingLastPathComponent().path.nilIfEmpty {
            try fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(pointer)
        let line = String(decoding: data, as: UTF8.self) + "\n"

        if fm.fileExists(atPath: ledgerURL.path) {
            guard let handle = FileHandle(forWritingAtPath: ledgerURL.path) else {
                throw ReceiptPersistenceError.unableToOpenLedger
            }
            try handle.seekToEnd()
            if let lineData = line.data(using: .utf8) {
                try handle.write(contentsOf: lineData)
            }
            try handle.close()
        } else {
            try line.write(to: ledgerURL, atomically: true, encoding: .utf8)
        }
    }

    private static func blake3Hex(of data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

enum ReceiptPersistenceError: Error {
    case unableToOpenLedger
}
