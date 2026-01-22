import Foundation
import AnigmaCore
import AnigmaSidecar
import AnigmaPrimitives

/// Executes a single task non-interactively using the remote Anigma Daemon.
/// This replaces the local `OneShotRunner` with a thin-client version.
public actor RemoteOneShotRunner {
    private let bridge: SidecarBridge
    
    public init(bridge: SidecarBridge) {
        self.bridge = bridge
    }
    
    public struct RunOptions: Sendable {
        public var verbose: Bool = false
        public var json: Bool = false
        
        public init(verbose: Bool = false, json: Bool = false) {
            self.verbose = verbose
            self.json = json
        }
    }
    
    /// Execute the task non-interactively on the daemon.
    public func execute(task: String, context: TaskContext, options: RunOptions = RunOptions()) async throws {
        if options.verbose {
            print("🔍 Dispatching task to Anigma Daemon: \"\(task)\"")
        }
        
        let startTime = Date()
        
        // 1. Construct Job Spec for Harmonia
        // We assume the daemon has the context of the current repo if we pass the path
        // For now, HarmoniaWorker logic is stateless w.r.t the CLI context unless passed explicitly
        // We'll pass the task description.
        
        // Use the same config structure as the worker expects
        let config = HarmoniaJobConfig(
            taskSummary: task,
            sessionID: UUID().uuidString,
            governancePolicy: "standard",
            useFastRAG: true
        )
        
        let configData = try JSONEncoder().encode(config)
        
        let jobSpec = AnigmaJobSpec(
            kind: "harmonia.execute",
            configCanonical: configData,
            inputs: [] // We could pass local files as artifacts here if needed
        )
        
        // 2. Submit Job
        let submission = try await bridge.submitJob(jobSpec)
        guard let jobId = submission.jobId else {
            print("❌ Failed to submit task to daemon.")
            // Print error details if available
            if let err = submission.error {
                print("Error: \(err.message)")
            }
            return
        }
        
        if options.verbose {
            print("✅ Job submitted (ID: \(jobId))")
            print("⏳ Waiting for remote execution...")
        }
        
        // 3. Stream Events and Result
        var finalResult: String?
        var artifactHash: String?
        
        for try await event in try await bridge.streamJobEvents(jobId: jobId) {
            if event.type == "job.progress" {
                if options.verbose {
                    print("  → [\(event.progressPermille/10)%] \(event.message)")
                }
            } else if event.type == "job.completed" {
                artifactHash = event.output?.hash
                break
            } else if event.type == "job.failed" {
                print("❌ Task execution failed: \(event.message)")
                return
            }
        }
        
        // 4. Retrieve Result Artifact
        // In a real implementation, we'd fetch the artifact content from the SidecarBridge
        // For this milestone, we'll simulate the retrieval or extract it if the event payload contained it
        // Assuming SidecarBridge will eventually support `retrieveArtifact(hash)`
        
        // Placeholder result until bridge supports artifact content retrieval
        finalResult = """
        [Remote Execution Complete]
        The task was executed by the Anigma Daemon using the High-Performance RLM stack.
        
        Artifact Hash: \(artifactHash ?? "unknown")
        """
        
        let duration = Date().timeIntervalSince(startTime)
        
        // 5. Output
        if options.json {
            // Minimal JSON output for piping
            let payload: [String: AnyCodable] = [
                "task": AnyCodable(task),
                "result": AnyCodable(finalResult ?? ""),
                "duration_ms": AnyCodable(Int(duration * 1000)),
                "status": AnyCodable("success"),
                "job_id": AnyCodable(jobId),
                "evidence_hash": AnyCodable(artifactHash ?? "")
            ]
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(payload), let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            if options.verbose {
                print("✅ Remote execution finished in \(Int(duration * 1000))ms")
                print("\n--- Daemon Response ---\n")
            }
            print(finalResult ?? "No result returned.")
        }
    }
}

// Helper for JSON output in this file
private struct AnyCodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
