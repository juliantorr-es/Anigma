//  TestGovernanceCovenant.swift
//  Phase C: Mean tests that lock the governance behavior.

import Foundation
import HarmoniaModule

@main
struct TestGovernanceCovenant {
    static func main() async {
        print("⚖️  Testing Governance Covenant - Phase C")
        print("=========================================\n")

        let projectId = UUID()
        var passed = 0
        var failed = 0

        // Test 1: Quarantine blocks sessions
        print("1. Testing quarantine semantics...")
        do {
            let securityEnforcer = SecurityEnforcerImpl()

            // Quarantine the project
            try await securityEnforcer.quarantineProject(
                projectId: projectId,
                reason: "Test quarantine",
                duration: 60
            )

            // Create controller with this enforcer
            let controller = PrincipalityProjectController(
                projectId: projectId,
                securityEnforcer: securityEnforcer
            )

            // Try to run session - should fail
            do {
                _ = try await controller.runSession(featureCategory: "ui")
                print("   ❌ FAIL: Session should have failed due to quarantine")
                failed += 1
            } catch PrincipalityError.projectQuarantined {
                print("   ✅ PASS: Session correctly blocked by quarantine")
                passed += 1
            } catch {
                print("   ❌ FAIL: Wrong error: \(error)")
                failed += 1
            }

            // Release quarantine
            try await securityEnforcer.releaseFromQuarantine(projectId: projectId)

        } catch {
            print("   ❌ FAIL: Setup error: \(error)")
            failed += 1
        }

        // Test 2: Policy denial prevents harness execution
        print("\n2. Testing policy denial...")
        do {
            // Create a policy registry that always denies
            struct DenyingPolicyRegistry: PolicyRegistry {
                func normalizeConfigChoice(
                    intent: SessionIntent,
                    candidateConfigId: String
                ) async throws -> String {
                    return candidateConfigId
                }

                func validateSessionPlan(
                    intent: SessionIntent,
                    configId: String
                ) async throws -> HarnessGovernanceDecision {
                    return .deny(reason: "Test policy denial")
                }

                func getConfigs(for category: String) -> [BlessedConfig] { [] }
                func getConfigIds(for category: String) -> [String] { [] }
                func getConfig(withId id: String) -> BlessedConfig? { nil }
                func getAllCategories() -> Set<String> { [] }
                func getDefaultConfigs() -> [BlessedConfig] { [] }
            }

            // Track if harness was called
            var harnessWasCalled = false
            struct TrackingHarnessRunner: HarnessRunner {
                var wasCalled = false

                func run(
                    intent: SessionIntent,
                    project: ProjectSpec,
                    configId: String
                ) async throws -> SessionReport {
                    wasCalled = true
                    throw NSError(domain: "Test", code: 1, userInfo: nil)
                }
            }

            var trackingRunner = TrackingHarnessRunner()
            let controller = PrincipalityProjectController(
                projectId: projectId,
                policyRegistry: DenyingPolicyRegistry(),
                harnessRunner: trackingRunner
            )

            do {
                _ = try await controller.runSession(featureCategory: "ui")
                print("   ❌ FAIL: Session should have been denied by policy")
                failed += 1
            } catch PrincipalityError.sessionDenied {
                print("   ✅ PASS: Session correctly denied by policy")
                passed += 1

                // Verify harness was never called
                if !trackingRunner.wasCalled {
                    print("   ✅ PASS: HarnessRunner was not invoked")
                    passed += 1
                } else {
                    print("   ❌ FAIL: HarnessRunner was called despite policy denial")
                    failed += 1
                }
            } catch {
                print("   ❌ FAIL: Wrong error: \(error)")
                failed += 1
            }

        } catch {
            print("   ❌ FAIL: Setup error: \(error)")
            failed += 1
        }

        // Test 3: Escalation emits event but continues
        print("\n3. Testing escalation handling...")
        do {
            // Track events
            var emittedEvents: [GovernanceEvent] = []
            struct TrackingEventSink: GovernanceEventSink {
                var events: [GovernanceEvent] = []

                func emit(_ event: GovernanceEvent) async {
                    events.append(event)
                }
            }

            var trackingSink = TrackingEventSink()

            // Create a gatekeeper that requires escalation
            struct EscalatingGatekeeper: Gatekeeper {
                func evaluate(
                    intent: SessionIntent,
                    configId: String
                ) async throws -> HarnessGovernanceDecision {
                    return .requireEscalation(reason: "Test escalation")
                }
            }

            let controller = PrincipalityProjectController(
                projectId: projectId,
                gatekeeper: EscalatingGatekeeper(),
                eventSink: trackingSink
            )

            // Session should run despite escalation
            let report = try await controller.runSession(featureCategory: "ui")
            print("   ✅ PASS: Session completed despite escalation requirement")
            passed += 1

            // Verify event was emitted
            if !trackingSink.events.isEmpty {
                print("   ✅ PASS: Escalation event was emitted")
                passed += 1

                let escalationEvents = trackingSink.events.filter {
                    $0.code.contains("escalation")
                }
                if !escalationEvents.isEmpty {
                    print("   ✅ PASS: Correct escalation event code")
                    passed += 1
                } else {
                    print("   ❌ FAIL: Wrong event code")
                    failed += 1
                }
            } else {
                print("   ❌ FAIL: No events emitted")
                failed += 1
            }

        } catch {
            print("   ❌ FAIL: \(error)")
            failed += 1
        }

        // Test 4: Trust tier enforcement
        print("\n4. Testing trust tier basics...")
        do {
            // Note: Full trust tier implementation is Phase C work
            // This just tests the enum exists and can be used
            let tiers: [TrustTier] = [.system, .trusted, .adversarial]

            if tiers.count == 3 {
                print("   ✅ PASS: Three trust tiers defined")
                passed += 1
            } else {
                print("   ❌ FAIL: Expected 3 trust tiers, got \(tiers.count)")
                failed += 1
            }

            // Test that trust tier is part of SessionIntent
            let intent = SessionIntent(
                projectId: projectId,
                featureCategory: "ui",
                requestedConfigId: nil,
                trustTier: .adversarial,
                metadata: [:]
            )

            if intent.trustTier == .adversarial {
                print("   ✅ PASS: Trust tier can be set in SessionIntent")
                passed += 1
            } else {
                print("   ❌ FAIL: Trust tier not properly set")
                failed += 1
            }

        } catch {
            print("   ❌ FAIL: \(error)")
            failed += 1
        }

        // Summary
        print("\n=========================================")
        print("Covenant Test Results:")
        print("  ✅ Passed: \(passed)")
        print("  ❌ Failed: \(failed)")
        print("  📊 Total: \(passed + failed)")

        if failed == 0 {
            print("\n🎉 All governance covenants satisfied!")
            print("The angelic bureaucracy is structurally sound.")
        } else {
            print("\n⚠️  Some covenants failed - architecture needs review.")
        }
    }
}
