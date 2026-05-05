import AnigmaDaemonCore
import Foundation

enum Verifier {
    static func run(configuration: DaemonConfiguration) async throws {
        let executablePath = Bundle.main.executablePath ?? "./anigmad"
        let harnessConfig = DaemonVerifierHarnessConfiguration(
            daemonExecutablePath: executablePath,
            evidenceDirectory: configuration.daemon.evidenceDirectory
        )
        _ = try await DaemonVerifierHarness.run(configuration: harnessConfig)
    }
}
