// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import XCTest
@testable import AccessumModule

final class AccessumModuleTests: XCTestCase {
    
    var coordinator: AccessumCoordinator!
    
    override func setUp() async throws {
        coordinator = AccessumCoordinator()
    }
    
    // MARK: - Client Management Tests
    
    func testCreateClient() async throws {
        let client = await coordinator.createClient()
        
        XCTAssertNotNil(client.id)
        XCTAssertEqual(client.requirements.wcagLevel, .AA)
        XCTAssertTrue(client.requirements.screenReaderSupport)
        XCTAssertEqual(client.preferences.preferredLanguage, "en")
        XCTAssertTrue(client.preferences.altTextGenerationEnabled)
    }
    
    func testCreateClientWithCustomRequirements() async throws {
        let requirements = AccessibilityRequirements(
            wcagLevel: .AAA,
            screenReaderSupport: true,
            keyboardNavigation: true,
            colorBlindnessSupport: false,
            highContrastMode: true
        )
        
        let preferences = AccessibilityPreferences(
            preferredLanguage: "es",
            altTextGenerationEnabled: false,
            automaticAssessment: true,
            notificationLevel: .critical
        )
        
        let client = await coordinator.createClient(requirements: requirements, preferences: preferences)
        
        XCTAssertEqual(client.requirements.wcagLevel, .AAA)
        XCTAssertFalse(client.requirements.colorBlindnessSupport)
        XCTAssertTrue(client.requirements.highContrastMode)
        XCTAssertEqual(client.preferences.preferredLanguage, "es")
        XCTAssertFalse(client.preferences.altTextGenerationEnabled)
        XCTAssertEqual(client.preferences.notificationLevel, .critical)
    }
    
    func testGetClient() async throws {
        let client = await coordinator.createClient()
        let retrievedClient = await coordinator.getClient(id: client.id)
        
        XCTAssertNotNil(retrievedClient)
        XCTAssertEqual(retrievedClient?.id, client.id)
    }
    
    func testUpdateClientRequirements() async throws {
        let client = await coordinator.createClient()
        let newRequirements = AccessibilityRequirements(wcagLevel: .AAA)
        
        try await coordinator.updateClientRequirements(id: client.id, requirements: newRequirements)
        let updatedClient = await coordinator.getClient(id: client.id)
        
        XCTAssertEqual(updatedClient?.requirements.wcagLevel, .AAA)
    }
    
    func testUpdateClientPreferences() async throws {
        let client = await coordinator.createClient()
        let newPreferences = AccessibilityPreferences(preferredLanguage: "fr")
        
        try await coordinator.updateClientPreferences(id: client.id, preferences: newPreferences)
        let updatedClient = await coordinator.getClient(id: client.id)
        
        XCTAssertEqual(updatedClient?.preferences.preferredLanguage, "fr")
    }
    
    // MARK: - Assessment Tests
    
    func testAssessContent() async throws {
        let content = "<html><body><h1>Test Content</h1><img src='test.jpg'/></body></html>"
        let assessment = try await coordinator.assessContent(content)
        
        XCTAssertNotNil(assessment.id)
        XCTAssertNotNil(assessment.timestamp)
        XCTAssertGreaterThanOrEqual(assessment.overallScore, 0.0)
        XCTAssertLessThanOrEqual(assessment.overallScore, 1.0)
        XCTAssertEqual(assessment.status, .completed)
    }
    
    func testAssessContentWithClient() async throws {
        let client = await coordinator.createClient()
        let content = "<html><body><h1>Test Content</h1></body></html>"
        
        let assessment = try await coordinator.assessContent(content, clientId: client.id)
        
        let updatedClient = await coordinator.getClient(id: client.id)
        XCTAssertEqual(updatedClient?.assessmentHistory.count, 1)
        XCTAssertEqual(updatedClient?.assessmentHistory.first?.id, assessment.id)
    }
    
    func testWCAGComplianceCheck() async throws {
        let content = "<html><body><h1>Test</h1></body></html>"
        let result = try await coordinator.checkWCAGCompliance(for: content, level: .AA)
        
        XCTAssertEqual(result.level, .AA)
        XCTAssertGreaterThanOrEqual(result.compliancePercentage, 0.0)
        XCTAssertLessThanOrEqual(result.compliancePercentage, 100.0)
    }
    
    func testScreenReaderReport() async throws {
        let content = "<html><body><h1>Test</h1></body></html>"
        let result = try await coordinator.generateScreenReaderReport(for: content)
        
        XCTAssertNotNil(result.issues)
        XCTAssertNotNil(result.recommendations)
    }
    
    func testGenerateAltText() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // Mock PNG header
        let suggestions = try await coordinator.generateAltText(for: imageData)
        
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertGreaterThan(suggestions.first!.confidence, 0.0)
        XCTAssertLessThanOrEqual(suggestions.first!.confidence, 1.0)
    }
    
    // MARK: - Model Tests
    
    func testAccessibilityClientModel() {
        let client = AccessibilityClient()
        
        XCTAssertNotNil(client.id)
        XCTAssertEqual(client.assessmentHistory.count, 0)
        XCTAssertEqual(client.recommendations.count, 0)
    }
    
    func testAccessibilityAssessmentModel() {
        let wcagResult = WCAGComplianceResult(
            level: .AA,
            passedCriteria: [],
            failedCriteria: []
        )
        
        let screenReaderResult = ScreenReaderResult(compatible: true)
        let keyboardResult = KeyboardNavigationResult(accessible: true)
        
        let assessment = AccessibilityAssessment(
            wcagCompliance: wcagResult,
            screenReaderCompatibility: screenReaderResult,
            keyboardNavigationResult: keyboardResult,
            overallScore: 0.8
        )
        
        XCTAssertNotNil(assessment.id)
        XCTAssertEqual(assessment.overallScore, 0.8)
        XCTAssertEqual(assessment.status, .completed)
    }
    
    func testAccessibilityRecommendationModel() {
        let recommendation = AccessibilityRecommendation(
            title: "Test Recommendation",
            description: "Test description",
            priority: .high,
            category: .screenReader,
            wcagCriteria: ["1.1.1"],
            implementationSteps: ["Step 1", "Step 2"],
            estimatedEffort: .medium,
            impactScore: 0.8
        )
        
        XCTAssertEqual(recommendation.title, "Test Recommendation")
        XCTAssertEqual(recommendation.priority, .high)
        XCTAssertEqual(recommendation.category, .screenReader)
        XCTAssertEqual(recommendation.impactScore, 0.8)
    }
    
    // MARK: - Diaplasion Integration Tests
    
    func testDiaplasionIntegration() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let altText = try await DiaplasionIntegration.generateAltTextForImage(imageData: imageData)
        
        XCTAssertFalse(altText.isEmpty)
    }
    
    func testDiaplasionAltTextOptions() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let options = try await DiaplasionIntegration.generateAltTextOptions(imageData: imageData)
        
        XCTAssertEqual(options.count, 3)
        XCTAssertTrue(options.contains { $0.type == AltTextType.short })
        XCTAssertTrue(options.contains { $0.type == AltTextType.detailed })
        XCTAssertTrue(options.contains { $0.type == AltTextType.functional })
    }
    
    func testImageAccessibilityAnalysis() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let analysis = try await DiaplasionIntegration.analyzeImageAccessibility(imageData: imageData)
        
        XCTAssertGreaterThanOrEqual(analysis.recommendedAltTextLength, 50)
        XCTAssertLessThanOrEqual(analysis.recommendedAltTextLength, 300)
    }
    
    // MARK: - API Handler Tests
    
    func testAccessibilityHandlers() async throws {
        let handlers = AccessibilityHandlers()
        let request = AccessibilityAssessmentRequest(content: "<html><body><h1>Test</h1></body></html>")
        
        let response = try await handlers.handleAssessmentRequest(request: request)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.assessment)
        XCTAssertNil(response.error)
    }
    
    func testCreateClientHandler() async throws {
        let handlers = AccessibilityHandlers()
        let request = CreateClientRequest()
        
        let response = try await handlers.handleClientCreationRequest(request: request)
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.client)
        XCTAssertNil(response.error)
    }
}
