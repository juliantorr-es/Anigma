# AccessumModule

Accessibility assessment and intake workflows for Anigma.

## Overview

AccessumModule provides comprehensive accessibility assessment capabilities including:

- WCAG compliance checking
- Alternative text generation for images
- Screen reader compatibility reports
- Keyboard navigation analysis
- Color contrast validation
- Integration with DiaplasionModule for AI-powered alt text generation

## Features

### Accessibility Assessment

- **WCAG Compliance**: Full support for WCAG 2.1 levels A, AA, and AAA
- **Screen Reader Analysis**: Detects issues with screen reader compatibility
- **Keyboard Navigation**: Validates keyboard accessibility and tab order
- **Color Contrast**: Analyzes color combinations for sufficient contrast ratios
- **Alt Text Generation**: AI-powered alternative text for images

### Client Management

- **Accessibility Profiles**: Customizable requirements and preferences per client
- **Assessment History**: Track all assessments and recommendations over time
- **Recommendation Engine**: Generate prioritized improvement recommendations

### API Integration

- **RESTful Handlers**: Ready-to-use API handlers for AnigmaDaemonCore integration
- **Request/Response Models**: Structured data models for API communication
- **Error Handling**: Comprehensive error handling and reporting

## Usage

### Basic Assessment

```swift
import AccessumModule

// Create coordinator
let coordinator = AccessumCoordinator()

// Assess content
let assessment = try await coordinator.assessContent(htmlContent)
print("Accessibility Score: \(assessment.overallScore)")
```

### Client Management

```swift
// Create client with custom requirements
let requirements = AccessibilityRequirements(wcagLevel: .AA)
let preferences = AccessibilityPreferences(preferredLanguage: "en")
let client = coordinator.createClient(requirements: requirements, preferences: preferences)

// Assess content for client
let assessment = try await coordinator.assessContent(content, clientId: client.id)
```

### API Integration

```swift
// Create handlers
let handlers = AccessibilityHandlers()

// Handle assessment request
let request = AccessibilityAssessmentRequest(content: htmlContent, clientId: client.id)
let response = try await handlers.handleAssessmentRequest(request: request)

if response.success {
    let assessment = response.assessment!
    // Process assessment results
}
```

### Diaplasion Integration

```swift
import AccessumModule.Integrations

// Generate alt text with AI
let imageData = // Image data
let altText = try await DiaplasionIntegration.generateAltTextForImage(imageData)

// Generate multiple options
let options = try await DiaplasionIntegration.generateAltTextOptions(imageData)
```

## Architecture

### Core Components

- **AccessumCoordinator**: Main actor managing assessment workflows
- **AccessibilityClient**: Model for client requirements and history
- **AccessibilityAssessment**: Comprehensive assessment results
- **AccessibilityHandlers**: API handlers for daemon integration
- **DiaplasionIntegration**: Integration utilities for alt text generation

### Data Models

- **AccessibilityRequirements**: WCAG levels and feature requirements
- **AccessibilityPreferences**: User preferences and settings
- **AccessibilityRecommendation**: Improvement suggestions with priority
- **WCAGComplianceResult**: Detailed WCAG compliance analysis
- **ScreenReaderResult**: Screen reader compatibility assessment

## Testing

Run tests with:

```bash
swift test
```

The module includes comprehensive unit tests covering:
- Client management
- Assessment workflows
- Model validation
- API handlers
- Integration utilities

## Integration with AnigmaDaemonCore

To integrate with AnigmaDaemonCore, add the following to your daemon:

```swift
import AccessumModule
import AccessumModule.API

// Create coordinator
let coordinator = AccessumCoordinator()
let handlers = AccessibilityHandlers(coordinator: coordinator)

// Register API endpoints
// POST /api/accessibility/assess -> handlers.handleAssessmentRequest
// POST /api/accessibility/clients -> handlers.handleClientCreationRequest
// PUT /api/accessibility/clients/{id} -> handlers.handleClientUpdateRequest
// POST /api/accessibility/alt-text -> handlers.handleAltTextRequest
```

## License

Copyright (c) 2025 Anigma
Licensed under the MIT License
