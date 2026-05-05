# State Flow Audit Bootstrap Proof

Date: 2026-05-05

## Commands Run
- `python3 scripts/anigma_state_flow_audit.py --mode advisory` -> `0`

## Scope
- scope: repo
- target: Workflows
- focus: None
- external_research_excluded: False
- include_tests: True

## Counts
- Total records: 288200
- State records: 270485
- Flow records: 17715
- Cohesion records: 4

## Counts By Source Category
- external_research: 172297
- production: 92046
- scripts: 10
- tests: 6077
- unknown: 55

## Flow Counts By Source Category
- external_research: 2259
- production: 14421
- scripts: 10
- tests: 790
- unknown: 235

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
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:6 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:15 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/Output/StreamRenderer.swift:24 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:57 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:83 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:87 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:91 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Examples/CodeReviewer/Sources/CodeReviewer/main.swift:105 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Package.swift:7 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Package.swift:19 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Package.swift:54 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Package.swift:68 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Package.swift:73 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Sources/Swarm/Agents/Agent.swift:576 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Sources/Swarm/Agents/Agent.swift:598 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Sources/Swarm/Agents/Agent.swift:830 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Sources/Swarm/Agents/Agent.swift:879 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Sources/Swarm/Agents/Agent.swift:1100 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Sources/Swarm/Agents/Agent.swift:1138 target=TableExtractionNative Mutable static or file-scoped variable
- mutable_global_state ExternalResearch/swift-tooling/swarm/Sources/Swarm/Agents/Agent.swift:1147 target=TableExtractionNative Mutable static or file-scoped variable

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
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBUtil/Debugger.swift -> bypass Direct ProcessInfo environment read
- ambient_process_read ExternalResearch/swift-tooling/swift-build/Sources/SWBUtil/Debugger.swift -> bypass Direct ProcessInfo environment read

## Top Cohesion Bottlenecks
- TableExtractionNative score=709014 state=172297 flow=2259
- Workflows score=442968 state=98078 flow=15190
- VizAggregationNative score=929 state=55 flow=235
- VectorIndexCapsuleTests score=318 state=55 flow=31

## Recommendation
- Use this audit as an architectural observability layer, not a refactor gate.
