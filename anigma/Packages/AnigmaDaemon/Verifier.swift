import AnigmaDaemonCore
import Foundation

enum Verifier {
    static func run() async throws {
        let executablePath = Bundle.main.executablePath ?? "./anigmad"
        let configuration = DaemonVerifierHarnessConfiguration(
            daemonExecutablePath: executablePath,
            evidenceDirectory: ProcessInfo.processInfo.environment["ANIGMA_EVIDENCE_DIR"]
        )
        _ = try await DaemonVerifierHarness.run(configuration: configuration)
    }
}
