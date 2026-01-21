//
//  LaTeXWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// latex.build worker
/// Simulates building a LaTeX document to PDF
public struct LaTeXWorker: JobWorker {
    public static let kind = "latex.build"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: building LaTeX document...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let buildConfig = LaTeXBuildConfig.decode(from: config)
        let latexmkPath = WorkerTooling.findTool(named: "latexmk")
        let pdflatexPath = WorkerTooling.findTool(named: "pdflatex")

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "latex-build") { dir in
            let inputURL = dir.appendingPathComponent("input.tex", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            // Handle bibliography if provided in inputs[1]
            if inputs.count > 1, let bibData = vaultData[inputs[1].hash] {
                let bibURL = dir.appendingPathComponent("refs.bib", isDirectory: false)
                try bibData.write(to: bibURL, options: .atomic)
            }

            if let latexmk = latexmkPath {
                // Use latexmk for automated multi-pass and bib handling
                var args = [
                    "-pdf",
                    "-interaction=nonstopmode",
                    "-halt-on-error",
                    "-outdir=\(dir.path)",
                    inputURL.path
                ]
                if buildConfig.useXeLaTeX {
                    args.append("-xelatex")
                }

                let result = try WorkerTooling.runProcess(
                    executable: latexmk,
                    arguments: args,
                    workingDirectory: dir
                )
                if result.exitCode != 0 {
                    throw WorkerError.executionFailed("latexmk failed: \(result.stderr)")
                }
            } else if let pdflatex = pdflatexPath {
                // Fallback to manual multi-pass if latexmk missing
                let baseArgs = [
                    "-interaction=nonstopmode",
                    "-halt-on-error",
                    "-no-shell-escape",
                    "-output-directory", dir.path,
                    inputURL.path
                ]

                for pass in 0..<max(1, min(buildConfig.passes, 4)) {
                    let result = try WorkerTooling.runProcess(
                        executable: pdflatex,
                        arguments: baseArgs,
                        workingDirectory: dir
                    )
                    if result.exitCode != 0 {
                        throw WorkerError.executionFailed(
                            "pdflatex failed on pass \(pass + 1): \(result.stderr)")
                    }
                }
            } else {
                throw WorkerError.executionFailed("No LaTeX engine (latexmk or pdflatex) found.")
            }

            let outputURL = dir.appendingPathComponent("input.pdf", isDirectory: false)
            return try Data(contentsOf: outputURL)
        }

        fputs("Worker: LaTeX build complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: "application/pdf",
                kind: "derived"
            )
        ]
    }
}

private struct LaTeXBuildConfig: Codable {
    let passes: Int
    let useXeLaTeX: Bool

    static let `default` = LaTeXBuildConfig(passes: 1, useXeLaTeX: false)

    static func decode(from data: Data) -> LaTeXBuildConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(LaTeXBuildConfig.self, from: data)) ?? .default
    }
}
