//
//  main.swift
//  SmokeTestRenderer
//
//  [Brief description of file purpose]
//

import AnigmaClientKit
import AnigmaHostKit  // The Host Logic (Separate Module)
import ContractsCore
import Foundation

@main
struct SmokeTestRenderer {
    static func main() async {
        print("--- Anigma Phase 8.2 Smoke Test: Authority Split ---")

        // HOST SIDE: Sets up authority and state
        let authority: AnigmaAuthority
        do {
            authority = try await AnigmaAuthority.create()
        } catch {
            print("[Host] FATAL: Could not create AnigmaAuthority. Is the daemon running?")
            print("[Host] Error: \(error)")
            return
        }
        let actorId = ActorId(rawValue: "user_test_01")

        print("[Host] Initializing Scenario...")

        // 1. Host Registers Surface
        let (surfaceId, token) = await authority.registerSurface(actorId: actorId)
        print("[Host] Surface Registered: \(surfaceId.rawValue)")
        print("[Host] Capability Token: \(token.id)")

        // RENDERER SIDE: Receives limited client
        let client = DirectAuthorityClient(authority: authority)

        // 2. Initial State: Empty IR
        let helloAction = ActionRef(rawValue: "hello_action", family: "ui")
        let initialIR = PresentationIR(
            root: ViewNode(
                id: "root",
                type: "Container",
                children: [
                    ViewNode(
                        id: "lbl1", type: "Text", properties: ["text": .string("Welcome to Anigma")]
                    )
                ],
                actions: []
            )
        )

        // Host Updates IR (Renderer cannot do this)
        // If we tried `client.updateIR(...)` it would fail to compile
        guard let snapshotId1 = await authority.updateIR(initialIR, for: surfaceId) else {
            print("[Host] FAIL: Authority did not return a snapshot ID.")
            return
        }
        print("[Host] IR State 1 Set. Snapshot: \(snapshotId1)")

        // 3. Renderer Attempts "hello_action" against snapshot 1
        // Expected: BLOCKED - SCHEMA_UNREACHABLE (Action not in IR)
        let intent1 = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId,
                actorId: actorId,
                capabilityToken: token.id,
                irSnapshotId: snapshotId1
            ),
            action: helloAction
        )

        print("[Renderer] Submitting 'hello_action' (Unreachable)...")
        let receipt1 = await client.submitIntent(intent1)
        print("[Renderer] CoreReceipt Outcome: \(receipt1.status.rawValue) -> \(receipt1.outcome)")

        // 4. Host Updates IR: Add Button with "hello_action"
        print("[Host] Updating IR to include 'hello_action'...")
        let updatedIR = PresentationIR(
            root: ViewNode(
                id: "root",
                type: "Container",
                children: [
                    ViewNode(
                        id: "btn1",
                        type: "Button",
                        properties: ["label": .string("Say Hello")],
                        actions: [helloAction]
                    )
                ]
            )
        )
        guard let snapshotId2 = await authority.updateIR(updatedIR, for: surfaceId) else {
            print("FAIL: No snapshot ID returned.")
            return
        }
        print("[Host] IR State 2 Set. Snapshot: \(snapshotId2)")

        // 5. Renderer Attempts "hello_action" against snapshot 2
        // Expected: SUCCESS
        let intent2 = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId,
                actorId: actorId,
                capabilityToken: token.id,
                irSnapshotId: snapshotId2
            ),
            action: helloAction
        )
        print("[Renderer] Submitting 'hello_action' (Valid)...")
        let receipt2 = await client.submitIntent(intent2)
        print("[Renderer] CoreReceipt Outcome: \(receipt2.status.rawValue) -> \(receipt2.outcome)")
        if case .signed = receipt2.seal { print("  Seal: Signed") }
        if case .unsigned(let hash) = receipt2.seal {
            print("  Seal: Unsigned(hash: \(hash.prefix(8))...)")
        }

        // 6. Renderer Attempts REPLAY of intent2
        // Expected: BLOCKED - INVALID_NONCE
        print("[Renderer] Replaying previous intent (Nonce Reuse)...")
        let receipt3 = await client.submitIntent(intent2)
        print("[Renderer] CoreReceipt Outcome: \(receipt3.status.rawValue) -> \(receipt3.outcome)")

        // 7. Renderer Attempts Intent against STALE snapshot (Snapshot 1)
        // Expected: BLOCKED - STALE_SNAPSHOT
        print("[Renderer] Submitting against Stale Snapshot 1...")
        let intentStale = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId,
                actorId: actorId,
                capabilityToken: token.id,
                irSnapshotId: snapshotId1  // Old snapshot
            ),
            action: helloAction
        )
        let receipt4 = await client.submitIntent(intentStale)
        print("[Renderer] CoreReceipt Outcome: \(receipt4.status.rawValue) -> \(receipt4.outcome)")

        // 8. Renderer Attempts SCOPE VIOLATION
        let forbiddenAction = ActionRef(rawValue: "forbidden", family: "ui")
        let forbiddenIR = PresentationIR(
            root: ViewNode(
                id: "root",
                type: "Container",
                children: [],
                actions: [forbiddenAction]
            )
        )
        // Host injects it (simulating malicious injection or admin override)
        guard let snapshotId4 = await authority.updateIR(forbiddenIR, for: surfaceId) else {
            return
        }

        print("[Renderer] Submitting 'forbidden' action (Scope Violation)...")
        let intentForbidden = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId,
                actorId: actorId,
                capabilityToken: token.id,
                irSnapshotId: snapshotId4
            ),
            action: forbiddenAction
        )
        let receipt6 = await client.submitIntent(intentForbidden)
        print("[Renderer] CoreReceipt Outcome: \(receipt6.status.rawValue) -> \(receipt6.outcome)")

        print("[Renderer] CoreReceipt Outcome: \(receipt6.status.rawValue) -> \(receipt6.outcome)")

        // --- PHASE 9 VERIFICATION ---

        print("\n[Phase 9] Parameter & Catalog Verification")

        // Setup IR with filesystem capabilities
        let fsActionValue = ActionRef(rawValue: "filesystem.read", family: "filesystem")
        let fsIR = PresentationIR(
            root: ViewNode(
                id: "root",
                type: "Container",
                actions: [fsActionValue]
            )
        )
        guard let fsSnapshot = await authority.updateIR(fsIR, for: surfaceId) else { return }

        // 9. Unknown Action
        print("[Renderer] Submitting Unknown Action...")
        let unknownAction = ActionRef(rawValue: "unknown.magic", family: "magic")
        let intentUnknown = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId, actorId: actorId, capabilityToken: token.id,
                irSnapshotId: fsSnapshot
            ),
            action: unknownAction
        )
        let receiptUnknown = await client.submitIntent(intentUnknown)
        print("  Outcome: \(receiptUnknown.status.rawValue) -> \(receiptUnknown.outcome)")

        // 10. Malformed Action (Missing Parameter)
        print("[Renderer] Submitting Malformed 'filesystem.read' (Missing 'path')...")
        let intentMalformed = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId, actorId: actorId, capabilityToken: token.id,
                irSnapshotId: fsSnapshot
            ),
            action: fsActionValue,  // defined in catalog, requires 'path'
            parameters: [:]
        )
        let receiptMalformed = await client.submitIntent(intentMalformed)
        print("  Outcome: \(receiptMalformed.status.rawValue) -> \(receiptMalformed.outcome)")

        // 11. Malformed Action (Wrong Type)
        print("[Renderer] Submitting Malformed 'filesystem.read' (Wrong Type)...")
        let intentWrongType = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId, actorId: actorId, capabilityToken: token.id,
                irSnapshotId: fsSnapshot
            ),
            action: fsActionValue,
            parameters: ["path": .number(123)]  // Expecting string
        )
        let receiptWrongType = await client.submitIntent(intentWrongType)
        print("  Outcome: \(receiptWrongType.status.rawValue) -> \(receiptWrongType.outcome)")

        // 12. Valid Action (But likely permission denied by default scope, testing parameter pass)
        // Wait, default scope is "ui:/", "action": "*" -> allow.
        // filesystem.read maps to "file:///..."
        // The token only allows families ["core", "ui"]. "filesystem" is not in allowed families.
        // So this should fail with CAPABILITY_DENIED (Family check), but AFTER parameter check?
        // Logic order in Authority:
        // 4. Catalog Check
        // 5. Parameter Check <-- We are testing this
        // 6. Scope Check
        // 7. Family Check
        // So if parameters are valid, it should hit Scope or Family check.

        print("[Renderer] Submitting Valid 'filesystem.read'...")
        let intentValid = ActionIntent(
            header: ActionIntent.Header(
                surfaceId: surfaceId, actorId: actorId, capabilityToken: token.id,
                irSnapshotId: fsSnapshot
            ),
            action: fsActionValue,
            parameters: ["path": .string("/tmp/test.txt")]
        )
        let receiptValid = await client.submitIntent(intentValid)
        print("  Outcome: \(receiptValid.status.rawValue) -> \(receiptValid.outcome)")

        print("--- Smoke Test Complete ---")
    }
}

struct DirectAuthorityClient {
    let authority: AnigmaAuthority

    func submitIntent(_ intent: ActionIntent) async -> CoreReceipt {
        return await authority.validateAndRouteIntent(intent)
    }
}
