//
//  ExampleModuleRegistration.swift
//  AnigmaCore
//
//  Example of how capability modules register with PlatformRuntime.
//  This serves as documentation and a pattern for module migration (Phase 3).
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import DatabaseCore

// MARK: - Example Module Definition

/// Example capability module showing registration pattern
public enum ExampleModule {
    // MARK: - Schemas

    /// Define module schemas
    public struct Schemas {
        public static let sessions = ModuleSchema(
            name: "example_sessions",
            version: 1,
            module: "ExampleModule",
            migrations: [
                1: """
                    CREATE TABLE example_sessions (
                        id TEXT PRIMARY KEY,
                        created_at INTEGER NOT NULL,
                        data TEXT
                    )
                """
            ]
        )

        public static let results = ModuleSchema(
            name: "example_results",
            version: 2,
            module: "ExampleModule",
            migrations: [
                1: """
                    CREATE TABLE example_results (
                        id TEXT PRIMARY KEY,
                        session_id TEXT NOT NULL,
                        created_at INTEGER NOT NULL
                    )
                """,
                2: """
                    ALTER TABLE example_results ADD COLUMN metadata TEXT
                """
            ]
        )
    }

    // MARK: - Module Registration

    /// Register the module with the runtime
    /// - This is called once during app startup
    /// - Modules register schemas, workflows, and systems here
    public static func register(runtime: PlatformRuntime) async throws {
        // 1. Register schemas (runtime handles migrations)
        try await runtime.registerSchema(Schemas.sessions)
        try await runtime.registerSchema(Schemas.results)

        // 2. Register workflows
        await runtime.registerWorkflow(ExampleWorkflow.self)

        // 3. Register systems (if using ECS)
        // try await runtime.registerSystem(ExampleSystem())
    }
}

// MARK: - Example Workflow

/// Example workflow showing how to use runtime services
public struct ExampleWorkflow: PlatformWorkflow {
    public static var typeIdentifier: String { "example.workflow" }

    public let inputText: String

    public init(inputText: String) {
        self.inputText = inputText
    }

    public func execute(
        context: ExecutionContext,
        runtime: RuntimeServices
    ) async throws -> PlatformWorkflowResult {
        // 1. Query database through authority (no governance needed for reads)
        _ = try await runtime.database.query(
            "SELECT * FROM example_sessions WHERE created_at > ?",
            parameters: [.text("0")]
        )

        // 2. Process data (pure computation, no governance needed)
        let processedData = inputText.uppercased()

        // 3. Mutate database through authority (governance enforced automatically)
        let mutation = DatabaseMutation(
            sql: """
                INSERT INTO example_results (id, session_id, created_at, metadata)
                VALUES (?, ?, ?, ?)
            """,
            parameters: [
                .text(UUID().uuidString),
                .text(context.sessionId),
                .text(String(Int(Date().timeIntervalSince1970))),
                .text(processedData)
            ]
        )

        let mutationReceipt = try await runtime.database.mutate(mutation, context: context)

        // 4. Optionally store artifacts
        if processedData.count > 1000 {
            let artifactData = Data(processedData.utf8)
            let artifact = Artifact(
                id: ArtifactID(hash: "example-\(UUID().uuidString)"),
                mimeType: "text/plain",
                size: Int64(artifactData.count),
                tags: ["example", "processed"],
                content: artifactData
            )

            let (artifactId, _) = try await runtime.artifacts.store(
                artifact,
                context: context
            )

            print("Stored artifact: \(artifactId)")
        }

        // 5. Return result (evidence is recorded automatically by runtime)
        return PlatformWorkflowResult(
            outcome: .success,
            summary: "Processed \(inputText.count) characters",
            outputRefs: [],
            metadata: [
                "rows_affected": String(mutationReceipt.rowsAffected),
                "processed_length": String(processedData.count)
            ]
        )
    }
}

// MARK: - Example App Shell (macOS)

/// Example of how an app shell creates and uses the runtime
@available(macOS 14.0, *)
public struct ExampleAppShell {
    public static func main() async throws {
        // 1. Create runtime (ONE per app instance)
        let runtime = try await PlatformRuntime.local(config: .production)

        // 2. Register all modules
        try await ExampleModule.register(runtime: runtime)
        // In real app:
        // try await HarmoniaModule.register(runtime: runtime)
        // try await DiaplasionModule.register(runtime: runtime)
        // ... etc

        // 3. Create execution context
        let principal = Principal(
            id: "user-123",
            displayName: "Example User",
            roles: ["user"]
        )

        let context = ExecutionContext(
            principal: principal,
            projectId: "my-project"
        )

        // 4. Execute workflow
        let workflow = ExampleWorkflow(inputText: "Hello, Anigma!")
        let receipt = try await runtime.execute(workflow, context: context)

        print("Workflow completed: \(receipt.id)")
        print("Outcome: \(receipt.outcome)")
        print("Duration: \(receipt.durationMs)ms")

        // 5. Check runtime status
        let status = await runtime.status()
        print("Runtime initialized: \(status.isInitialized)")
        print("Registered schemas: \(status.registeredSchemas)")
        print("Governance mode: \(status.governanceStatus.operatingMode)")

        // 6. Shutdown
        await runtime.shutdown()
    }
}

// MARK: - Migration Example (Before → After)

/*
 ## Before (Direct Database Access):

 ```swift
 // In HarmoniaModule - OLD WAY
 public actor SessionManager {
     private let database: DatabaseActor

     public func createSession() async throws {
         // Direct database access - NO governance, NO evidence
         try await database.execute("""
             INSERT INTO harmonia_sessions (id, created_at) VALUES (?, ?)
         """, parameters: [.text(UUID().uuidString), .int(Int(Date().timeIntervalSince1970))])
     }
 }
 ```

 ## After (Runtime Authority):

 ```swift
 // In HarmoniaModule - NEW WAY
 public actor SessionManager {
     private let runtime: PlatformRuntime

     public func createSession(context: ExecutionContext) async throws {
         // Goes through runtime - governance ENFORCED, evidence RECORDED
         let mutation = DatabaseMutation(
             sql: "INSERT INTO harmonia_sessions (id, created_at) VALUES (?, ?)",
             parameters: [
                 "id": UUID().uuidString,
                 "created_at": String(Int(Date().timeIntervalSince1970))
             ]
         )

         let receipt = try await runtime.database.mutate(mutation, context: context)
         // receipt.evidence contains cryptographic proof of this operation
     }
 }
 ```

 ## Key Differences:

 1. **Governance**: KillSwitch and WriteGate are checked automatically
 2. **Evidence**: Every mutation generates a signed receipt
 3. **Context**: Operations carry principal, project, session info
 4. **Cannot Bypass**: No direct DatabaseActor access, must go through runtime

 ## Migration Steps for Existing Modules:

 1. Add `register(runtime:)` static method
 2. Define schemas in `ModuleSchema` format
 3. Update workflows to use `runtime.database.mutate()` instead of `dbActor.execute()`
 4. Add `ExecutionContext` parameter to mutation methods
 5. Return/store receipts for audit trails
 6. Remove direct `DatabaseActor` usage

 */
