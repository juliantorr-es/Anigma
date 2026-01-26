# Observability and Telemetry

## Telemetry Core
- Telemetry is implemented as an actor in `Packages/TelemetryCore/TelemetryClient.swift`.
- Emissions are redacted and sampled before reaching sinks defined in `Packages/TelemetryCore/TelemetrySinks.swift`.

## Privacy-First Signals
- Telemetry enforces redaction via `Packages/TelemetryCore/Redaction.swift` and privacy classification in `Packages/TelemetryCore/TelemetryEvent.swift`.
- Redacted telemetry values are hashed or truncated before emission.

## Runtime Monitoring
- The daemon configures telemetry sinks at startup in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.
- Resource monitoring and health state are owned by `ResourceMonitor` and `HealthManager` in the daemon core.

## Observability Kit
- A lightweight observability layer is exposed by `Packages/ObservabilityKit` (declared in `Package.swift`).

## Key References
- `Packages/TelemetryCore/TelemetryClient.swift`
- `Packages/TelemetryCore/Redaction.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
