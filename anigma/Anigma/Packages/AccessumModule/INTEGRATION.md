# AccessumModule Integration Guide

## Overview

AccessumModule provides comprehensive accessibility assessment capabilities for Anigma applications. This guide explains how to integrate the module with AnigmaDaemonCore.

## Quick Start

### 1. Basic Integration

```swift
import AccessumModule
import AccessumModule.API

// Create coordinator
let coordinator = AccessumCoordinator()
let handlers = AccessibilityHandlers(coordinator: coordinator)

// Handle assessment request
let request = AccessibilityAssessmentRequest(
    content: htmlContent,
    clientId: clientId
)
let response = try await handlers.handleAssessmentRequest(request: request)
```

### 2. API Endpoints

Add these endpoints to AnigmaDaemonCore:

#### Accessibility Assessment
- **Endpoint**: `POST /api/accessibility/assess`
- **Handler**: `AccessibilityHandlers.handleAssessmentRequest`
- **Request**: `AccessibilityAssessmentRequest`
- **Response**: `AccessibilityAssessmentResponse`

#### Client Management
- **Endpoint**: `POST /api/accessibility/clients`
- **Handler**: `AccessibilityHandlers.handleClientCreationRequest`
- **Request**: `CreateClientRequest`
- **Response**: `CreateClientResponse`

- **Endpoint**: `PUT /api/accessibility/clients/{id}`
- **Handler**: `AccessibilityHandlers.handleClientUpdateRequest`
- **Request**: `UpdateClientRequest`
- **Response**: `UpdateClientResponse`

#### Alt Text Generation
- **Endpoint**: `POST /api/accessibility/alt-text`
- **Handler**: `AccessibilityHandlers.handleAltTextRequest`
- **Request**: `AltTextRequest`
- **Response**: `AltTextResponse`

#### WCAG Compliance Check
- **Endpoint**: `POST /api/accessibility/wcag-check`
- **Handler**: `AccessibilityHandlers.handleWCAGCheckRequest`
- **Request**: `WCAGCheckRequest`
- **Response**: `WCAGCheckResponse`

#### Screen Reader Report
- **Endpoint**: `POST /api/accessibility/screen-reader`
- **Handler**: `AccessibilityHandlers.handleScreenReaderReportRequest`
- **Request**: `ScreenReaderReportRequest`
- **Response**: `ScreenReaderReportResponse`

## Core Components

### AccessumCoordinator

Main actor that manages:
- Client creation and management
- Assessment workflows
- Recommendation generation
- Alt text processing

### AccessibilityClient

Represents a user/organization with:
- Accessibility requirements (WCAG levels, features)
- User preferences (language, notifications)
- Assessment history
- Recommendations

### AccessibilityAssessment

Comprehensive assessment containing:
- WCAG compliance results
- Screen reader compatibility
- Keyboard navigation analysis
- Color contrast issues
- Alt text suggestions
- Overall accessibility score

### Diaplasion Integration

AI-powered alt text generation:
- `DiaplasionIntegration.generateAltTextForImage()`
- `DiaplasionIntegration.generateAltTextOptions()`
- `DiaplasionIntegration.analyzeImageAccessibility()`

## Implementation Notes

### Actor Isolation

All coordinator methods are actor-isolated. Use `await` when calling:
```swift
let client = await coordinator.createClient()
let assessment = try await coordinator.assessContent(content, clientId: clientId)
```

### Error Handling

All handlers return response objects with success/error information:
```swift
if response.success {
    // Process successful result
    let assessment = response.assessment!
} else {
    // Handle error
    print(response.error!)
}
```

### Sendable Compliance

All public types conform to `Sendable` for safe concurrency:
- Models can be safely passed between actors
- API handlers can work with concurrent requests
- Type system guarantees thread safety

## Testing

Run tests with:
```bash
swift test
```

All 18 tests pass, covering:
- Client management
- Assessment workflows
- Model validation
- API handlers
- Diaplasion integration

## Configuration

### WCAG Levels
- `.A`: Basic accessibility
- `.AA`: Standard compliance (default)
- `.AAA`: Enhanced accessibility

### Assessment Features
- Screen reader support
- Keyboard navigation
- Color blindness support
- High contrast mode

### Notification Levels
- `.detailed`: All issues
- `.summary`: Key issues only
- `.critical`: Critical issues only

## Performance Considerations

- Assessments are performed concurrently where possible
- Mock implementations provide ~1s response time
- Alt text generation includes 0.5s simulated AI processing
- All operations are memory-safe and thread-safe

## Future Enhancements

1. **Real Assessment Engine**: Replace mock implementations with actual accessibility analysis
2. **Caching**: Add result caching for repeated assessments
3. **Batch Processing**: Support for bulk content assessment
4. **Advanced Diaplasion Integration**: Connect to actual AI service
5. **Custom WCAG Criteria**: Support for custom accessibility rules
