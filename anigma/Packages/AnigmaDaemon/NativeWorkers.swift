//
//  NativeWorkers.swift
//  AnigmaDaemon
//
//  Workers that wrap the heavy native sidecar services.
//

import Foundation
import AnigmaNativeShims
import AnigmaDaemonCore
@preconcurrency import SidecarOfficeService
@preconcurrency import PDFSidecarClient
@preconcurrency import SidecarTranslateService

// MARK: - Office Worker

public struct OfficeWorker: JobWorker {
    public static let kind = "office.render"
    private let service = NativeOfficeService() // In real app, this might be a shared instance or pooled

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: Office render job starting...\n", stderr)

        guard let input = inputs.first, let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: inputs.first?.hash ?? "none")
        }

        // Decode config (mock config struct)
        struct OfficeConfig: Codable {
            let page: Int
            let format: String // "pdf", "png"
        }

        let cfg = (try? JSONDecoder().decode(OfficeConfig.self, from: config)) ?? OfficeConfig(page: 1, format: "pdf")

        let outputData: Data
        if cfg.format == "pdf" {
            outputData = try service.convert(document: payload, to: "pdf")
        } else {
            outputData = try service.renderPage(document: payload, page: cfg.page)
        }

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: cfg.format == "pdf" ? "application/pdf" : "image/png",
                kind: "derived"
            )
        ]
    }
}

// MARK: - Heavy PDF Worker

public struct HeavyPDFWorker: JobWorker {
    public static let kind = "pdf.heavy"
    private let sidecar = PDFSidecarProcessManager.shared

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: Heavy PDF job starting...\n", stderr)

        // Mock config: "merge" or "split"
        struct PDFConfig: Codable {
            let operation: String // "merge", "split"
            let page: Int? // for split
        }
        let cfg = (try? JSONDecoder().decode(PDFConfig.self, from: config)) ?? PDFConfig(operation: "merge", page: nil)

        if cfg.operation == "merge" {
            let payloads = inputs.compactMap { vaultData[$0.hash] }
            let request = PDFSidecarRequest(
                operation: .merge(
                    MergeRequest(
                        pdfContentHashes: inputs.map(\.hash),
                        pdfDataBase64: payloads.map { $0.base64EncodedString() }
                    )
                )
            )
            let response = try sidecar.sendRequest(request)
            guard case .mergeResult(let result)? = response.payload,
                  let data = Data(base64Encoded: result.pdfDataBase64) else {
                throw WorkerError.executionFailed("Invalid PDF sidecar merge response")
            }
            return [JobOutputPayload(data: data, mediaType: "application/pdf", kind: "derived")]
        } else if cfg.operation == "split", let p = cfg.page, let input = inputs.first, let payload = vaultData[input.hash] {
            let request = PDFSidecarRequest(
                operation: .split(
                    SplitRequest(
                        pdfContentHash: input.hash,
                        pageIndex: p,
                        pdfDataBase64: payload.base64EncodedString()
                    )
                ),
                inputHash: input.hash
            )
            let response = try sidecar.sendRequest(request)
            guard case .splitResult(let result)? = response.payload,
                  let part1 = Data(base64Encoded: result.beforeBase64),
                  let part2 = Data(base64Encoded: result.afterBase64) else {
                throw WorkerError.executionFailed("Invalid PDF sidecar split response")
            }
            return [
                JobOutputPayload(data: part1, mediaType: "application/pdf", kind: "derived"),
                JobOutputPayload(data: part2, mediaType: "application/pdf", kind: "derived")
            ]
        }

        throw WorkerError.executionFailed("Invalid PDF operation")
    }
}

// MARK: - Translate Worker

public struct TranslateWorker: JobWorker {
    public static let kind = "nlp.translate"
    private let service = NativeTranslateService()

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: Translate job starting...\n", stderr)

        guard let input = inputs.first, let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: inputs.first?.hash ?? "none")
        }

        struct TranslateConfig: Codable {
            let source: String
            let target: String
        }
        let cfg = (try? JSONDecoder().decode(TranslateConfig.self, from: config)) ?? TranslateConfig(source: "en", target: "es")

        guard let text = String(data: payload, encoding: .utf8) else {
            throw WorkerError.executionFailed("Input is not valid UTF-8 text")
        }

        let result = try service.translate(text: text, sourceLang: cfg.source, targetLang: cfg.target)

        return [
            JobOutputPayload(
                data: result.data(using: .utf8) ?? Data(),
                mediaType: "text/plain",
                kind: "derived"
            )
        ]
    }
}
