//
//  GnuPGWorker.swift
//  AnigmaDaemonCore
//

import Foundation

/// security.sign worker
/// Signs artifacts or verifies signatures using GnuPG.
public struct GnuPGWorker: JobWorker {
    public static let kind = "security.sign"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting GnuPG operation...\n", stderr)
        fflush(stderr)

        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }

        let gpgConfig = GnuPGConfig.decode(from: config)
        let gpgPath = WorkerTooling.findTool(named: "gpg")
        guard let gpgPath = gpgPath else {
            throw WorkerError.executionFailed(
                "gpg binary not found; install GnuPG.")
        }

        let outputData = try WorkerTooling.withTemporaryDirectory(prefix: "security-sign") { dir in
            let inputURL = dir.appendingPathComponent("input.dat", isDirectory: false)
            let outputURL = dir.appendingPathComponent("output.sig", isDirectory: false)
            try payload.write(to: inputURL, options: .atomic)

            var args = [
                "--batch",
                "--no-tty",
                "--output", outputURL.path
            ]

            switch gpgConfig.mode {
            case .sign:
                args.append("--detach-sign")
                args.append("--armor")
                args.append(inputURL.path)
            case .verify:
                // For verification, we assume inputs[1] is the signature if provided,
                // or we are verifying a cleartext signature.
                // Simplified for MVP: verify input.dat against its own inline signature or separate one.
                args.append("--verify")
                args.append(inputURL.path)
            }

            let result = try WorkerTooling.runProcess(
                executable: gpgPath,
                arguments: args,
                workingDirectory: dir
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed(
                    "GPG failed (\(result.exitCode)): \(result.stderr)")
            }

            if gpgConfig.mode == .sign {
                return try Data(contentsOf: outputURL)
            } else {
                // Return verification status as text
                return Data(result.stderr.utf8)
            }
        }

        fputs("Worker: GnuPG operation complete\n", stderr)
        fflush(stderr)

        return [
            JobOutputPayload(
                data: outputData,
                mediaType: gpgConfig.mode == .sign ? "application/pgp-signature" : "text/plain",
                kind: "derived"
            )
        ]
    }
}

private struct GnuPGConfig: Codable {
    enum Mode: String, Codable {
        case sign
        case verify
    }

    let mode: Mode
    let keyId: String?

    static let `default` = GnuPGConfig(
        mode: .sign,
        keyId: nil
    )

    static func decode(from data: Data) -> GnuPGConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(GnuPGConfig.self, from: data)) ?? .default
    }
}
