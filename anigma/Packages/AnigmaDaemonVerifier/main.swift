import AnigmaDaemonCore
import Foundation

@main
struct AnigmaDaemonVerifier {
    static func main() async throws {
        let daemonExecutablePath = ProcessInfo.processInfo.environment["ANIGMA_DAEMON_EXECUTABLE"]
            ?? "./.build/debug/anigmad"
        let socketPath = ProcessInfo.processInfo.environment["ANIGMA_DAEMON_SOCKET"]
            ?? "/tmp/anigmad-test.sock"
        let evidenceDirectory = ProcessInfo.processInfo.environment["ANIGMA_EVIDENCE_DIR"]

        let configuration = DaemonVerifierHarnessConfiguration(
            daemonExecutablePath: daemonExecutablePath,
            evidenceDirectory: evidenceDirectory,
            socketPath: socketPath
        )

        do {
            _ = try await DaemonVerifierHarness.run(configuration: configuration)
        } catch {
            fputs("Verification failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
