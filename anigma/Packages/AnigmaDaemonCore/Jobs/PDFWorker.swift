//
//  PDFWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// pdf.render worker
/// Simulates rendering a PDF page to an image
public struct PDFWorker: JobWorker {
    public static let kind = "pdf.render"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: rendering PDF page...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let renderConfig = PDFRenderConfig.decode(from: config)
        let page = max(1, renderConfig.page)
        let mutoolPath = WorkerTooling.findTool(named: "mutool")
        guard let mutoolPath else {
            throw WorkerError.executionFailed(
                "MuPDF 'mutool' not found on PATH; install MuPDF or provide pdfium tooling.")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "pdf-render") { dir in
            let inputURL = dir.appendingPathComponent("input.pdf", isDirectory: false)
            let outputURL = dir.appendingPathComponent("page-\(page).png", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            let args = [
                "draw",
                "-r", "\(renderConfig.dpi)",
                "-o", outputURL.path,
                "-F", "png",
                "-p", "\(page)",
                inputURL.path
            ]
            let result = try WorkerTooling.runProcess(
                executable: mutoolPath,
                arguments: args,
                workingDirectory: dir
            )
            guard result.exitCode == 0 else {
                throw WorkerError.executionFailed(
                    "mutool failed (\(result.exitCode)): \(result.stderr)")
            }
            return try Data(contentsOf: outputURL)
        }

        fputs("Worker: PDF render complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: "image/png",
                kind: "derived"
            )
        ]
    }
}

private struct PDFRenderConfig: Codable {
    let dpi: Int
    let page: Int

    static let `default` = PDFRenderConfig(dpi: 144, page: 1)

    static func decode(from data: Data) -> PDFRenderConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(PDFRenderConfig.self, from: data)) ?? .default
    }
}
