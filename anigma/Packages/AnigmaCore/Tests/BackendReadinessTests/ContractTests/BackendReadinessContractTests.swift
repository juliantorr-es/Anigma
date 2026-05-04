//
//  BackendReadinessContractTests.swift
//  AnigmaCoreTests
//
//  Tests for backend readiness contracts (td-358315)
//

import XCTest
import AnigmaCore

class BackendReadinessContractTests: XCTestCase {

    // MARK: - Contract Structure Tests

    func testBackendIdStructure() {
        let backendId = BackendId(rawValue: "test-backend-123")
        XCTAssertEqual(backendId.rawValue, "test-backend-123")
        XCTAssertEqual(backendId.description, "Backend(test-b)")
        
        let autoBackendId = BackendId()
        XCTAssertFalse(autoBackendId.rawValue.isEmpty)
        XCTAssertTrue(autoBackendId.rawValue.contains("-"))
    }

    func testBackendIdConvenienceMethods() {
        let inferenceId = BackendId.inferenceBackend()
        XCTAssertEqual(inferenceId.rawValue, "inference-backend")
        
        let rendererId = BackendId.rendererBackend()
        XCTAssertEqual(rendererId.rawValue, "renderer-backend")
        
        let databaseId = BackendId.databaseBackend()
        XCTAssertEqual(databaseId.rawValue, "database-backend")
    }

    func testBackendKindCases() {
        let allKinds: [BackendKind] = [.database, .inference, .renderer, .mlWorker, .cliTool, .cloudProvider, .mediaProcessor, .custom]
        XCTAssertEqual(allKinds.count, 8)
    }

    func testBackendLifecycleStateCases() {
        let allStates: [BackendLifecycleState] = [.uninitialized, .initializing, .active, .draining, .terminated]
        XCTAssertEqual(allStates.count, 5)
    }

    func testBackendReadinessStateCases() {
        let allStates: [BackendReadinessState] = [
            .unregistered, .registered, .initializing, .ready, .degraded,
            .unavailable, .failed, .draining, .shuttingDown
        ]
        XCTAssertEqual(allStates.count, 9)
    }

    func testContractCompatibilityCases() {
        let allCompatibilities: [ContractCompatibility] = [.compatible, .incompatible, .downgraded, .upgraded]
        XCTAssertEqual(allCompatibilities.count, 4)
    }

    func testBackoffStrategyCases() {
        let allStrategies: [BackoffStrategy] = [.none, .linear, .exponential, .custom]
        XCTAssertEqual(allStrategies.count, 4)
    }

    func testFallbackStrategyCases() {
        let allStrategies: [FallbackStrategy] = [.none, .defaultBackend, .specificBackend, .degrade]
        XCTAssertEqual(allStrategies.count, 4)
    }

    // MARK: - Contract Validation Tests

    func testBackendCapabilityContractInitialization() {
        let backendId = BackendId(rawValue: "test-backend")
        let contract = BackendCapabilityContract(
            backendId: backendId,
            kind: .custom,
            contractId: "test.v1",
            contractVersion: 1,
            supportedOperations: ["op1", "op2"],
            minPlatformVersion: "1.0",
            dependencies: ["dep1"],
            metadata: ["key": "value"]
        )

        XCTAssertEqual(contract.backendId, backendId)
        XCTAssertEqual(contract.kind, .custom)
        XCTAssertEqual(contract.contractId, "test.v1")
        XCTAssertEqual(contract.contractVersion, 1)
        XCTAssertEqual(contract.supportedOperations, ["op1", "op2"])
        XCTAssertEqual(contract.minPlatformVersion, "1.0")
        XCTAssertEqual(contract.dependencies, ["dep1"])
        XCTAssertEqual(contract.metadata, ["key": "value"])
    }

    func testBackendCapabilityContractConvenienceMethods() {
        let inferenceContract = BackendCapabilityContract.inferenceContract()
        XCTAssertEqual(inferenceContract.backendId, .inferenceBackend())
        XCTAssertEqual(inferenceContract.kind, .inference)
        XCTAssertEqual(inferenceContract.contractId, "inference.v1")
        XCTAssertEqual(inferenceContract.contractVersion, 1)
        XCTAssertTrue(inferenceContract.supportedOperations.contains("text-generation"))
        XCTAssertTrue(inferenceContract.supportedOperations.contains("embedding"))
        XCTAssertTrue(inferenceContract.supportedOperations.contains("chat"))

        let rendererContract = BackendCapabilityContract.rendererContract()
        XCTAssertEqual(rendererContract.backendId, .rendererBackend())
        XCTAssertEqual(rendererContract.kind, .renderer)
        XCTAssertEqual(rendererContract.contractId, "renderer.v1")
        XCTAssertEqual(rendererContract.contractVersion, 1)
        XCTAssertTrue(rendererContract.supportedOperations.contains("video-render"))
        XCTAssertTrue(rendererContract.supportedOperations.contains("audio-render"))
        XCTAssertTrue(rendererContract.supportedOperations.contains("preview"))
    }

    func testBackendReadinessCheckInitialization() {
        let backendId = BackendId(rawValue: "test-backend")
        let readiness = BackendReadinessCheck(
            backendId: backendId,
            isReady: true,
            state: .ready,
            contractCompatibility: .compatible,
            lifecycleState: .active,
            retryPolicy: BackendRetryPolicy(maxAttempts: 3, backoffStrategy: .exponential),
            fallbackPolicy: FallbackPolicy(strategy: .degrade, maxDegradation: 2),
            lastValidation: Date(),
            denialReason: nil,
            diagnostics: ["health": "good"]
        )

        XCTAssertEqual(readiness.backendId, backendId)
        XCTAssertTrue(readiness.isReady)
        XCTAssertEqual(readiness.state, .ready)
        XCTAssertEqual(readiness.contractCompatibility, .compatible)
        XCTAssertEqual(readiness.lifecycleState, .active)
        XCTAssertNotNil(readiness.retryPolicy)
        XCTAssertNotNil(readiness.fallbackPolicy)
        XCTAssertNotNil(readiness.lastValidation)
        XCTAssertNil(readiness.denialReason)
        XCTAssertEqual(readiness.diagnostics, ["health": "good"])
    }

    func testBackendReadinessCheckConvenienceMethods() {
        let readyCheck = BackendReadinessCheck.readyCheck()
        XCTAssertTrue(readyCheck.isReady)
        XCTAssertEqual(readyCheck.state, .ready)
        XCTAssertEqual(readyCheck.contractCompatibility, .compatible)
        XCTAssertEqual(readyCheck.lifecycleState, .active)

        let notRegisteredCheck = BackendReadinessCheck.notRegisteredCheck()
        XCTAssertFalse(notRegisteredCheck.isReady)
        XCTAssertEqual(notRegisteredCheck.state, .unregistered)
        XCTAssertEqual(notRegisteredCheck.contractCompatibility, .incompatible)
        XCTAssertEqual(notRegisteredCheck.lifecycleState, .uninitialized)
        XCTAssertNotNil(notRegisteredCheck.denialReason)
        XCTAssertTrue(notRegisteredCheck.denialReason!.contains("not registered"))
    }

    func testBackendRegistrationReceiptInitialization() {
        let backendId = BackendId(rawValue: "test-backend")
        let date = Date()
        let receipt = BackendRegistrationReceipt(
            backendId: backendId,
            registeredAt: date,
            context: ["module": "test"],
            evidenceReceiptId: "evidence-123"
        )

        XCTAssertEqual(receipt.backendId, backendId)
        XCTAssertEqual(receipt.registeredAt, date)
        XCTAssertEqual(receipt.context, ["module": "test"])
        XCTAssertEqual(receipt.evidenceReceiptId, "evidence-123")
    }

    func testBackendOperationContextInitialization() {
        let context = BackendOperationContext(
            operationId: "op-123",
            operationType: "test-operation",
            requiresEvidence: true,
            metadata: ["key": "value"]
        )

        XCTAssertEqual(context.operationId, "op-123")
        XCTAssertEqual(context.operationType, "test-operation")
        XCTAssertTrue(context.requiresEvidence)
        XCTAssertEqual(context.metadata, ["key": "value"])
    }

    // MARK: - Codable Conformance Tests

    func testBackendIdCodable() throws {
        let backendId = BackendId(rawValue: "test-backend")
        let data = try JSONEncoder().encode(backendId)
        let decoded = try JSONDecoder().decode(BackendId.self, from: data)
        XCTAssertEqual(decoded, backendId)
    }

    func testBackendKindCodable() throws {
        let kinds: [BackendKind] = [.database, .inference, .renderer, .custom]
        for kind in kinds {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(BackendKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    func testBackendLifecycleStateCodable() throws {
        let states: [BackendLifecycleState] = [.uninitialized, .initializing, .active, .draining, .terminated]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(BackendLifecycleState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testBackendReadinessStateCodable() throws {
        let states: [BackendReadinessState] = [.unregistered, .ready, .degraded, .failed]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(BackendReadinessState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testBackendCapabilityContractCodable() throws {
        let contract = BackendCapabilityContract.inferenceContract()
        let data = try JSONEncoder().encode(contract)
        let decoded = try JSONDecoder().decode(BackendCapabilityContract.self, from: data)
        XCTAssertEqual(decoded.backendId, contract.backendId)
        XCTAssertEqual(decoded.kind, contract.kind)
        XCTAssertEqual(decoded.contractId, contract.contractId)
        XCTAssertEqual(decoded.contractVersion, contract.contractVersion)
    }

    func testBackendReadinessCheckCodable() throws {
        let readiness = BackendReadinessCheck.readyCheck()
        let data = try JSONEncoder().encode(readiness)
        let decoded = try JSONDecoder().decode(BackendReadinessCheck.self, from: data)
        XCTAssertEqual(decoded.backendId, readiness.backendId)
        XCTAssertEqual(decoded.isReady, readiness.isReady)
        XCTAssertEqual(decoded.state, readiness.state)
    }

    // MARK: - Sendable Conformance Tests

    func testBackendIdSendable() async {
        let backendId = BackendId(rawValue: "test-backend")
        await verifySendable(backendId)
    }

    func testBackendCapabilityContractSendable() async {
        let contract = BackendCapabilityContract.inferenceContract()
        await verifySendable(contract)
    }

    func testBackendReadinessCheckSendable() async {
        let readiness = BackendReadinessCheck.readyCheck()
        await verifySendable(readiness)
    }

    func testBackendRegistrationReceiptSendable() async {
        let receipt = BackendRegistrationReceipt(
            backendId: .inferenceBackend(),
            registeredAt: Date()
        )
        await verifySendable(receipt)
    }

    func testBackendOperationContextSendable() async {
        let context = BackendOperationContext(operationType: "test")
        await verifySendable(context)
    }

    private func verifySendable<T: Sendable>(_ value: T) async {
        // Sendable conformance is verified at compile time
        // This method exists to document that we've considered Sendable requirements
        _ = value
    }
}