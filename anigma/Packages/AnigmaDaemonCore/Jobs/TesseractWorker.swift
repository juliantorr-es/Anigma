//
//  TesseractWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// ocr.tesseract worker
/// Extracts text from images or PDFs using Tesseract OCR.
public struct TesseractWorker: JobWorker {
    public static let kind = "ocr.tesseract"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting Tesseract OCR...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let ocrConfig = TesseractOCRConfig.decode(from: config)
        let tesseractPath = WorkerTooling.findTool(named: "tesseract")
        guard let tesseractPath = tesseractPath else {
            throw WorkerError.executionFailed(
                "tesseract binary not found; install Tesseract OCR.")
        }

        let outputText = try WorkerTooling.withTemporaryDirectory(prefix: "ocr-tesseract") { dir in
            let inputURL = dir.appendingPathComponent("input", isDirectory: false)
            let outputBase = dir.appendingPathComponent("output", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            var args = [
                inputURL.path,
                outputBase.path,
                "-l", ocrConfig.language,
                "--psm", "\(ocrConfig.psm)"
            ]

            // Add custom config variables
            for (key, value) in ocrConfig.variables {
                args.append("-c")
                args.append("\(key)=\(value)")
            }

            // Output format (txt is default, but we can also produce pdf, hocr, etc.)
            args.append("txt")

            let result = try WorkerTooling.runProcess(
                executable: tesseractPath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "Tesseract failed (\(result.exitCode)): \(result.stderr)")
            }

            let outputURL = dir.appendingPathComponent("output.txt", isDirectory: false)
            return try String(contentsOf: outputURL, encoding: .utf8)
        }

        fputs("Worker: Tesseract OCR complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: Data(outputText.utf8),
                mediaType: "text/plain",
                kind: "derived"
            )
        ]
    }
}

private struct TesseractOCRConfig: Codable {
    let language: String
    let psm: Int
    let variables: [String: String]

    static let `default` = TesseractOCRConfig(
        language: "eng",
        psm: 3,
        variables: [:]
    )

    static func decode(from data: Data) -> TesseractOCRConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(TesseractOCRConfig.self, from: data)) ?? .default
    }
}
