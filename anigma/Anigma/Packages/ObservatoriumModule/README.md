# ObservatoriumModule

Integrated observability platform providing telemetry, rule-based alerting, and feedback management for Anigma daemon.

## Invariants

- **Alert Cooldown**: Rules enforce minimum 5-minute cooldown between triggers to prevent alert storms; configurable per rule
- **Health Score Formula**: System status (critical/poor/fair/good/excellent) calculated from alert severity, error rates, and feedback priority; scores below 30 trigger system-wide critical alerts
- **Data Retention**: Telemetry retained 7 days, feedback retained 1 year; automatic purging beyond configured limits prevents unbounded memory growth
- **Rule Uniqueness**: Each alert rule must have unique ID; duplicate rule additions throw `ruleAlreadyExists` error

## Entry Points

- **ObservatoriumModule.shared** (@MainActor singleton) — `start()` initializes telemetry collection, alert evaluation, and health monitoring; `stop()` gracefully shuts down all services
- **TelemetryService** — `recordEvent()` / `recordMetric()` store observability data; `getAggregatedMetrics(for:timeRange)` retrieves CPU/memory/network/error statistics; automatic 30-second polling via `startCollection()`
- **AlertService** — `createRule()` / `updateRule()` / `deleteRule()` manage alert rules; `getActiveAlerts()` / `acknowledgeAlert()` / `resolveAlert()` lifecycle; multi-channel notifications (email, Slack, webhook, push, SMS) via `addNotificationChannel()`
- **FeedbackService** — `submitFeedback()` / `updateFeedback()` collect user/system feedback; `analyzeFeedback()` performs sentiment analysis and key phrase extraction; `getTrendAnalysis()` returns category/priority/status breakdowns with resolution metrics

## Build & Test

```bash
# Build release binary
swift build -c release

# Run all tests
swift test

# Test specific service
swift test ObservatoriumModuleTests
```

Tests verify: telemetry collection, alert rule evaluation, notification dispatch, feedback analysis, health score calculation, data retention policies.

## Links

- **Coordinator**: `Coordinator/ObservatoriumCoordinator.swift` (455 lines) — orchestration, lifecycle, health checks
- **Services**: `Services/` — TelemetryService (280 LOC), AlertService (412 LOC), FeedbackService (508 LOC)
- **Models**: `Models/` — TelemetryModels, AlertModels, FeedbackModels with full Codable support
- **Unit Tests**: `Tests/ObservatoriumModuleTests/`
- **Related Packages**: AnigmaDaemonCore (integration), PolytroposModule (event source)
- **Minimum Platform**: macOS 14+, iOS 17+
