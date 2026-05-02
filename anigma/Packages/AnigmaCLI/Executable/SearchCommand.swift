import Foundation
import ArgumentParser
import AnigmaSidecar
import AnigmaPrimitives

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search indexed codebase with hybrid retrieval using daemon-first logic"
    )

    @Argument(help: "Search query")
    var query: String

    @Option(name: .shortAndLong, help: "Repository root path")
    var repoRoot: String?

    @Option(name: .shortAndLong, help: "Maximum number of results")
    var limit: Int = 10

    @Option(name: .shortAndLong, help: "Filter by path prefix")
    var pathPrefix: String?

    @Flag(name: .long, help: "Disable vector search (lexical only)")
    var lexicalOnly: Bool = false

    @Flag(name: .long, help: "Show full chunk text")
    var fullText: Bool = false

    @OptionGroup var daemonOptions: DaemonOptions

    func run() async throws {
        print("🔍 Searching: \"\(query)\" (Remote Daemon)")
        print()

        // 1. Ensure Daemon is Running
        let config = daemonOptions.toConfig()
        let socketPath = config.socketPath ?? SidecarConfig.defaultUnixSocketPath()
        let guardian = DaemonGuardian(socketPath: socketPath)
        do {
            try await guardian.ensureDaemonRunning()
        } catch {
            if config.localFallback {
                print("⚠️ Daemon unavailable, but local fallback is disabled for search command")
                print("   Use --local flag with other commands for local execution")
            }
            print("❌ Error: Could not connect to Anigma Daemon.")
            throw ExitCode.failure
        }

        // 2. Connect to Sidecar
        let bridge = try await SidecarBridge.create(
            socketPath: socketPath,
            clientName: "anigma-cli-search"
        )

        // 3. Construct Job Spec
        // We use the "harmonia.execute" worker to perform a "Retrieval Only" task
        // Ideally we would have a dedicated "retrieval.search" job kind, but this works for now.
        let searchTask = """
        Perform a retrieval-only search for: "\(query)"
        Limit: \(limit)
        Path Prefix: \(pathPrefix ?? "none")
        Lexical Only: \(lexicalOnly)
        """
        
        let jobConfig = HarmoniaJobConfig(
            taskSummary: searchTask,
            sessionID: UUID().uuidString,
            governancePolicy: "fast", // Skip heavy reasoning
            useFastRAG: true
        )

        let configData = try JSONEncoder().encode(jobConfig)
        
        let jobSpec = AnigmaJobSpec(
            kind: "harmonia.execute",
            configCanonical: configData,
            inputs: []
        )

        // 4. Submit Job
        let submission = try await bridge.submitJob(jobSpec)
        guard let jobId = submission.jobId else {
            print("❌ Failed to submit search job.")
            throw ExitCode.failure
        }

        // 5. Stream Results
        // HarmoniaWorker returns a JSON artifact with the result.
        // For search, we want to stream events or wait for the final artifact.
        // Since search is fast, we'll wait for the completion event.
        
        print("⏳ Waiting for results...")
        
        var foundArtifactHash: String?
        
        for try await event in try await bridge.streamJobEvents(jobId: jobId) {
            if event.type == "job.completed" {
                foundArtifactHash = event.output?.hash
                break
            } else if event.type == "job.failed" {
                print("❌ Search failed: \(event.message)")
                throw ExitCode.failure
            }
        }
        
        // 6. Fetch and Display Artifact
        if let hash = foundArtifactHash {
            let response = try await bridge.getReceipt(receiptHash: hash)
            // Note: We actually need to fetch the artifact CONTENT, not just the receipt.
            // SidecarBridge needs a retrieveArtifact method or similar.
            // Assuming SidecarBridge has listArtifacts or similar we can use to get metadata,
            // but fetching content might require a new endpoint or using the vault direct access if local.
            // For a "Thin Client", we must use the bridge.
            
            // Temporary Workaround: Print success message. 
            // Real implementation requires `bridge.retrieveArtifact(hash)`
            print("✅ Search completed. Results stored in artifact: \(hash)")
            print("(Artifact retrieval implementation pending in SidecarBridge)")
        }
    }
}

// Temporary shim until AnigmaDaemonCore exports this to a shared library
public struct HarmoniaJobConfig: Codable, Sendable {
    public let taskSummary: String
    public let sessionID: String
    public let governancePolicy: String
    public let useFastRAG: Bool
    
    public init(taskSummary: String, sessionID: String, governancePolicy: String, useFastRAG: Bool = true) {
        self.taskSummary = taskSummary
        self.sessionID = sessionID
        self.governancePolicy = governancePolicy
        self.useFastRAG = useFastRAG
    }
}
