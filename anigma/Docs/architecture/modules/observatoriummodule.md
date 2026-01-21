# ObservatoriumModule

## Overview

ObservatoriumModule is a Swift module in the Anigma ecosystem with **3714 lines of code** across **12 files**.

## Statistics

- **Public Types**: 45
- **Public Functions**: 81  
- **Components**: 25
- **Systems**: 0
- **Services**: 10

## Architecture

### Components
- `AlertComponent`
- `AlertType`
- `AlertSource`
- `AlertState`
- `NotificationChannel`
- `AlertSummary`
- `ErrorRecordComponent`
- `ErrorState`
- `EnvironmentInfo`
- `ErrorSummary`
- `ErrorCluster`
- `FeedbackComponent`
- `FeedbackType`
- `UserSeverity`
- `ContactPreference`
- `FeedbackState`
- `FeedbackSummary`
- `MetricDefinitionComponent`
- `AggregationType`
- `MetricDataPoint`
- `AggregatedMetric`
- `TelemetryEventComponent`
- `TelemetryEventType`
- `TelemetrySensitivity`
- `TelemetryValue`

### Systems
No systems found

### Services
- `AlertDashboardSummary`
- `AlertStatistics`
- `ErrorStatistics`
- `FeedbackStatistics`
- `FeedbackSummaryReport`
- `HealthStatus`
- `SystemHealthSummary`
- `OperationsDashboard`
- `WeeklyOperationsReport`
- `TelemetryStatistics`

## Dependencies

- `AnigmaCore`
- `ContractsCore`

## File Structure


### Components/AlertComponent.swift

- **Lines**: 350
- **Public Types**: 6
- **Public Functions**: 3


**Public Types:**
- `struct AlertComponent` (line 14)
- `enum AlertType` (line 203)
- `enum AlertSource` (line 215)
- `enum AlertState` (line 226)
- `enum NotificationChannel` (line 236)
- `struct AlertSummary` (line 247)



**Public Functions:**
- `thresholdAlert` (static) (line 273)
- `slaViolation` (static) (line 306)
- `errorRateAlert` (static) (line 330)


### Components/ErrorComponent.swift

- **Lines**: 302
- **Public Types**: 5
- **Public Functions**: 1


**Public Types:**
- `struct ErrorRecordComponent` (line 14)
- `enum ErrorState` (line 161)
- `struct EnvironmentInfo` (line 171)
- `struct ErrorSummary` (line 226)
- `struct ErrorCluster` (line 255)



**Public Functions:**
- `createFingerprint` (static) (line 124)


### Components/FeedbackComponent.swift

- **Lines**: 290
- **Public Types**: 6
- **Public Functions**: 2


**Public Types:**
- `struct FeedbackComponent` (line 14)
- `enum FeedbackType` (line 162)
- `enum UserSeverity` (line 173)
- `enum ContactPreference` (line 181)
- `enum FeedbackState` (line 188)
- `struct FeedbackSummary` (line 202)



**Public Functions:**
- `bugReport` (static) (line 228)
- `featureRequest` (static) (line 251)


### Components/MetricComponent.swift

- **Lines**: 339
- **Public Types**: 4
- **Public Functions**: 1


**Public Types:**
- `struct MetricDefinitionComponent` (line 15)
- `enum AggregationType` (line 142)
- `struct MetricDataPoint` (line 159)
- `struct AggregatedMetric` (line 193)



**Public Functions:**
- `checkThresholds` (line 115)


### Components/TelemetryComponent.swift

- **Lines**: 299
- **Public Types**: 4
- **Public Functions**: 5


**Public Types:**
- `struct TelemetryEventComponent` (line 14)
- `enum TelemetryEventType` (line 127)
- `enum TelemetrySensitivity` (line 171)
- `enum TelemetryValue` (line 183)



**Public Functions:**
- `redacted` (line 112)
- `encode` (line 223)
- `performanceTrace` (static) (line 243)
- `workflowComplete` (static) (line 262)
- `fromError` (static) (line 281)


### ObservatoriumModule.swift

- **Lines**: 157
- **Public Types**: 10
- **Public Functions**: 1


**Public Types:**
- `enum ObservatoriumModule` (line 22)
- `enum MetricCategory` (line 38)
- `enum MetricUnit` (line 48)
- `enum AlertSeverity` (line 63)
- `enum ObservatoriumError` (line 78)
- `struct MetricId` (line 90)
- `struct TelemetryEventId` (line 107)
- `struct ErrorRecordId` (line 120)
- `struct FeedbackId` (line 133)
- `struct AlertId` (line 146)



**Public Functions:**
- `initialize` (static) (line 28)


### ObservatoriumTelemetryAdapter.swift

- **Lines**: 195
- **Public Types**: 0
- **Public Functions**: 3




**Public Functions:**
- `recordTelemetryEvent` (line 22)
- `recordMetric` (line 55)
- `recordWorkflowComplete` (line 83)


### Services/AlertService.swift

- **Lines**: 370
- **Public Types**: 2
- **Public Functions**: 16


**Public Types:**
- `struct AlertDashboardSummary` (line 351)
- `struct AlertStatistics` (line 364)



**Public Functions:**
- `triggerAlert` (line 58)
- `triggerThresholdAlert` (line 103)
- `triggerSLAAlert` (line 117)
- `triggerErrorRateAlert` (line 137)
- `getAlert` (line 155)
- `getActiveAlerts` (line 161)
- `getAlerts` (line 168)
- `getAlerts` (line 173)
- `getCriticalAlerts` (line 178)
- `getUnacknowledgedAlerts` (line 185)
- `acknowledgeAlert` (line 194)
- `resolveAlert` (line 221)
- `snoozeAlert` (line 249)
- `assignAlert` (line 276)
- `getDashboardSummary` (line 312)
- `getStatistics` (line 340)


### Services/ErrorService.swift

- **Lines**: 321
- **Public Types**: 1
- **Public Functions**: 12


**Public Types:**
- `struct ErrorStatistics` (line 313)



**Public Functions:**
- `recordError` (line 58)
- `recordSwiftError` (line 95)
- `getError` (line 169)
- `getErrorsByFingerprint` (line 175)
- `getClusters` (line 180)
- `getClusters` (line 185)
- `getUnresolvedClusters` (line 190)
- `getRecentErrors` (line 197)
- `getErrors` (line 202)
- `updateErrorState` (line 209)
- `promoteCluster` (line 241)
- `getStatistics` (line 290)


### Services/FeedbackService.swift

- **Lines**: 403
- **Public Types**: 2
- **Public Functions**: 14


**Public Types:**
- `struct FeedbackStatistics` (line 385)
- `struct FeedbackSummaryReport` (line 393)



**Public Functions:**
- `submitFeedback` (line 48)
- `submitBugReport` (line 81)
- `submitFeatureRequest` (line 104)
- `getFeedback` (line 125)
- `getFeedback` (line 131)
- `getFeedback` (line 146)
- `getPendingFeedback` (line 161)
- `getUrgentFeedback` (line 168)
- `triageFeedback` (line 176)
- `promoteToIssue` (line 212)
- `resolveFeedback` (line 245)
- `declineFeedback` (line 279)
- `getStatistics` (line 319)
- `generateWeeklySummary` (line 331)


### Services/ObservatoriumService.swift

- **Lines**: 339
- **Public Types**: 4
- **Public Functions**: 12


**Public Types:**
- `enum HealthStatus` (line 293)
- `struct SystemHealthSummary` (line 301)
- `struct OperationsDashboard` (line 314)
- `struct WeeklyOperationsReport` (line 324)



**Public Functions:**
- `trace` (line 42)
- `metric` (line 57)
- `error` (line 70)
- `error` (line 87)
- `measure` (line 94)
- `measureWithErrorTracking` (line 109)
- `recordAltMediaTurnaround` (line 132)
- `recordCaseResolution` (line 150)
- `recordQueueDepth` (line 168)
- `getHealthSummary` (line 182)
- `getOperationsDashboard` (line 215)
- `generateWeeklyReport` (line 235)


### Services/TelemetryService.swift

- **Lines**: 349
- **Public Types**: 1
- **Public Functions**: 11


**Public Types:**
- `struct TelemetryStatistics` (line 340)



**Public Functions:**
- `registerMetric` (line 74)
- `getMetric` (line 84)
- `listMetrics` (line 89)
- `record` (line 114)
- `recordTrace` (line 141)
- `recordWorkflowComplete` (line 165)
- `recordMetric` (line 183)
- `recordMetrics` (line 211)
- `flush` (line 247)
- `aggregateMetrics` (line 274)
- `getStatistics` (line 326)


