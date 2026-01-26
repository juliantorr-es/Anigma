# AccessumModule

WCAG compliance checking, screen reader analysis, and AI-powered accessibility assessment for content.

## Invariants

- All assessments must follow WCAG 2.1 guidelines (levels A, AA, AAA configurable)
- AccessibilityClient profiles maintain immutable history of all assessments
- Alt text generation integrates exclusively through DiaplasionIntegration
- API handlers must validate AccessibilityRequirements before processing requests

## Entry Points

- **AccessumCoordinator**: Main actor for assessment workflows; create with `AccessumCoordinator()`, then call `assessContent(_:clientId:)` to run WCAG checks, keyboard navigation validation, screen reader compatibility, and color contrast analysis.
- **AccessibilityHandlers**: API layer for daemon integration; handlers for `handleAssessmentRequest`, `handleClientCreationRequest`, `handleClientUpdateRequest`, `handleAltTextRequest`.
- **DiaplasionIntegration**: AI-powered alt text generation; static methods `generateAltTextForImage(_:)` and `generateAltTextOptions(_:)` delegate to DiaplasionModule.
- **Data Models**: `AccessibilityClient` (profile + history), `AccessibilityAssessment` (results), `AccessibilityRequirements` (WCAG level), `WCAGComplianceResult`, `ScreenReaderResult`.

## Build & Test

```bash
# Build module
swift build -c release

# Run all tests
swift test

# Test specific component
swift test AccessumModuleTests
```

Tests cover: client management, assessment workflows, model validation, API handlers, integration utilities.

## Links

- **Docs**: `Docs/governance/accessibility.md` — WCAG compliance policy
- **Integration Guide**: See AnigmaDaemonCore for API handler registration
- **Related Packages**: DiaplasionModule (AI alt text), ObservatoriumModule (telemetry)
- **Source**: `Packages/AccessumModule/Sources/`
