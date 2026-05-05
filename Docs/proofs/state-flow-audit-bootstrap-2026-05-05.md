# State Flow Audit Bootstrap Proof

Date: 2026-05-05

## Commands Run
- `python3 -m py_compile scripts/anigma_state_flow_audit.py scripts/test_state_flow_audit.py scripts/anigma_build_repo_atlas.py scripts/anigma_context_query.py` -> `0`
- `python3 scripts/test_state_flow_audit.py` -> `0`
- `python3 scripts/anigma_state_flow_audit.py --mode advisory --target AnigmaDaemonCore --json-out .build/anigma-state-flow-audit.json --proof-out Docs/proofs/state-flow-audit-bootstrap-2026-05-05.md` -> `0`
- `python3 scripts/anigma_build_repo_atlas.py` -> `0`
- `python3 scripts/anigma_context_query.py --state path_constant --limit 5` -> `0`
- `python3 scripts/anigma_context_query.py --flow ambient_process_read --limit 5` -> `0`
- `python3 scripts/anigma_context_query.py --cohesion AnigmaDaemonCore --limit 5` -> `0`
- `python3 scripts/anigma_diagnose.py validate --task-id state-flow-audit-bootstrap --command true` -> `0`

## Counts
- Total records: 288200
- State records: 270485
- Flow records: 17715
- Cohesion records: 4

## Counts By Classification
- actor_owned_state: 1345
- environment_key: 239
- immutable_domain_constant: 126059
- mutable_global_state: 69491
- path_constant: 3101
- service_state: 4
- static_singleton: 8
- typealias_obscuring: 57
- typealias_semantic: 4899
- unknown: 65282

## Counts By Risk Label
- ambient_state_bypass: 239
- approved: 15560
- bypass: 899
- global_mutable_state: 69499
- integration_gap: 137
- path_ownership_ambiguous: 3101
- stringly_typed_boundary: 57
- unknown: 1256

## Top State Risks
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Package.swift:5 target=TableExtractionNative Immutable constant
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:6 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:15 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:24 target=TableExtractionNative Mutable static or file-scoped variable
- unknown ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:36 target=TableExtractionNative Unclassified state
- unknown ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:37 target=TableExtractionNative Unclassified state
- unknown ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:38 target=TableExtractionNative Unclassified state
- unknown ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:39 target=TableExtractionNative Unclassified state
- unknown ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:40 target=TableExtractionNative Unclassified state
- unknown ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:41 target=TableExtractionNative Unclassified state
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:49 target=TableExtractionNative Immutable constant
- environment_key ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:4 target=TableExtractionNative Ambient process read
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:5 target=TableExtractionNative Immutable constant
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:10 target=TableExtractionNative Immutable constant
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:11 target=TableExtractionNative Immutable constant
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:39 target=TableExtractionNative Immutable constant
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:40 target=TableExtractionNative Immutable constant
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:57 target=TableExtractionNative Mutable static or file-scoped variable
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:66 target=TableExtractionNative Immutable constant
- immutable_domain_constant ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:76 target=TableExtractionNative Immutable constant

## Top Flow Bypasses
- ambient_process_read ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift -> bypass Direct CommandLine arguments read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Package.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Sources/Swarm/Tools/BuiltInTools.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Sources/SwarmCapabilityShowcase/main.swift -> bypass Direct CommandLine arguments read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Sources/SwarmCapabilityShowcaseSupport/CapabilityShowcase.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Tests/SwarmTests/Agents/AgentDefaultInferenceProviderTests.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Tests/SwarmTests/Memory/PersistentSessionTests.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Tests/SwarmTests/Memory/SwiftDataMemoryTests.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swarm/Tests/SwarmTests/Providers/FoundationModelsToolCallingTests.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Plugins/run-xcodebuild/run-xcodebuild.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBBuildService/BuildServiceEntryPoint.swift -> bypass Direct CommandLine arguments read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBBuildSystem/BuildOperation.swift -> bypass Direct CommandLine arguments read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBTaskConstruction/TaskProducers/BuildPhaseTaskProducers/SourcesTaskProducer.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBTaskConstruction/TaskProducers/BuildPhaseTaskProducers/SourcesTaskProducer.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBTestSupport/BuildOperationTester.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBTestSupport/BuildOperationTester.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBUniversalPlatform/TestEntryPointGenerationTaskAction.swift -> bypass Direct CommandLine arguments read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBUniversalPlatform/TestEntryPointGenerationTaskAction.swift -> bypass Direct CommandLine arguments read
- socket_path_flow ExternalResearch/swift-tooling/swift-build/Sources/SWBUniversalPlatform/TestEntryPointGenerationTaskAction.swift -> bypass Direct socket/PID/lock ownership string
- socket_path_flow ExternalResearch/swift-tooling/swift-build/Sources/SWBUniversalPlatform/TestEntryPointGenerationTaskAction.swift -> bypass Direct socket/PID/lock ownership string

## Top Cohesion Bottlenecks
- TableExtractionNative score=709014 state=172297 flow=2259
- Workflows score=442968 state=98078 flow=15190
- VizAggregationNative score=929 state=55 flow=235
- VectorIndexCapsuleTests score=318 state=55 flow=31

## Recommendation
- Use this audit as an architectural observability layer, not a refactor gate.
