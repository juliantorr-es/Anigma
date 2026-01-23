import Foundation
import AnigmaCLICore
import AnigmaCLIEventing
import AnigmaSidecar
import AnigmaPrimitives

/// Orchestrates interaction between TUI components and backend services
public actor ChatPresenter {
    private let sidecar: SidecarBridge
    private let sessionID: String
    private var subscriptionId: UUID?
    
    public init(sidecar: SidecarBridge, sessionID: String) {
        self.sidecar = sidecar
        self.sessionID = sessionID
    }
    
    public func start() async {
        // Subscribe to input events
        self.subscriptionId = await TUIEventBus.shared.subscribe { [weak self] event in
            if case .inputCommitted(let text) = event {
                Task {
                    await self?.handleUserInput(text)
                }
            }
        }
        
        // Initial status
        await TUIEventBus.shared.publish(.statusUpdated(message: "Connected to Daemon"))
    }
    
    public func stop() async {
        if let id = subscriptionId {
            await TUIEventBus.shared.unsubscribe(id: id)
        }
    }
    
    private func handleUserInput(_ input: String) async {
        // 1. Log user message
        await TUIEventBus.shared.publish(.messageAdded(role: "user", content: input))
        await TUIEventBus.shared.publish(.statusUpdated(message: "Transmitting..."))
        
        // 2. Add placeholder for assistant
        await TUIEventBus.shared.publish(.messageAdded(role: "assistant", content: ""))
        
        do {
            // 3. Construct Job Spec for Harmonia Chat
            // Note: We need a "Chat" specific config for HarmoniaWorker, or assume taskSummary is the prompt
            // For a persistent chat, we rely on the sessionID to keep context in the Daemon.
            
            // JSON config for the worker
            let configDict: [String: String] = [
                "taskSummary": input,
                "sessionID": sessionID,
                "governancePolicy": "standard",
                "useFastRAG": "true",
                "mode": "chat" // Hint to worker that this is a chat turn
            ]
            let configData = try JSONEncoder().encode(configDict)
            
            let jobSpec = AnigmaJobSpec(
                kind: "harmonia.execute",
                configCanonical: configData,
                inputs: []
            )
            
            // 4. Submit Job
            let submission = try await sidecar.submitJob(jobSpec)
            guard let jobId = submission.jobId else {
                await TUIEventBus.shared.publish(.statusUpdated(message: "❌ Failed to submit job"))
                return
            }
            
            await TUIEventBus.shared.publish(.statusUpdated(message: "Thinking..."))
            
            // 5. Stream Tokens
            // We assume the daemon streams tokens as events with type "job.token"
            // or we might need to adapt the HarmoniaWorker to stream properly.
            // For now, let's assume standard event streaming.
            
            for try await event in try await sidecar.streamJobEvents(jobId: jobId) {
                switch event.type {
                case "job.token":
                    if let token = event.message { // Assuming message field holds the token for this event type
                        await TUIEventBus.shared.publish(.tokenReceived(token: token))
                    }
                case "job.progress":
                    await TUIEventBus.shared.publish(.statusUpdated(message: event.message ?? "Working..."))
                case "job.completed":
                    await TUIEventBus.shared.publish(.statusUpdated(message: "Done"))
                    NotificationManager.send(title: "Anigma Task Complete", message: "Your task has finished successfully.")
                case "job.failed":
                    let msg = event.message ?? "Unknown error"
                    await TUIEventBus.shared.publish(.statusUpdated(message: "❌ Error: \(msg)"))
                    await TUIEventBus.shared.publish(.tokenReceived(token: "\n[Error: \(msg)]"))
                    NotificationManager.send(title: "Anigma Task Failed", message: msg)
                default:
                    break
                }
            }
            
        } catch {
            await TUIEventBus.shared.publish(.statusUpdated(message: "❌ Connection Error"))
            await TUIEventBus.shared.publish(.messageAdded(role: "system", content: "Error: \(error.localizedDescription)"))
        }
    }
}
