#!/usr/bin/env swift

import Foundation
import AccessumModule
import AccessumModule.API

@main
struct Demo {
    static func main() async throws {
        print("🔍 AccessumModule Demo")
        print("========================")
        
        // Create coordinator and handlers
        let coordinator = AccessumCoordinator()
        let handlers = AccessibilityHandlers(coordinator: coordinator)
        
        // Create a client with custom requirements
        let requirements = AccessibilityRequirements(
            wcagLevel: .AA,
            screenReaderSupport: true,
            keyboardNavigation: true,
            colorBlindnessSupport: true,
            highContrastMode: false
        )
        
        let preferences = AccessibilityPreferences(
            preferredLanguage: "en",
            altTextGenerationEnabled: true,
            automaticAssessment: false,
            notificationLevel: .summary
        )
        
        print("\n👤 Creating Accessibility Client...")
        let createRequest = CreateClientRequest(requirements: requirements, preferences: preferences)
        let createResponse = try await handlers.handleClientCreationRequest(request: createRequest)
        
        if createResponse.success {
            let client = createResponse.client!
            print("✅ Client created successfully!")
            print("   ID: \(client.id)")
            print("   WCAG Level: \(client.requirements.wcagLevel.rawValue)")
            print("   Language: \(client.preferences.preferredLanguage)")
            
            // Perform accessibility assessment
            print("\n🔍 Performing Accessibility Assessment...")
            let htmlContent = """
            <html>
                <head><title>Test Page</title></head>
                <body>
                    <h1>Welcome to Our Site</h1>
                    <img src="logo.png" alt="Company Logo">
                    <button>Click Me</button>
                    <a href="/about">Learn More</a>
                </body>
            </html>
            """
            
            let assessmentRequest = AccessibilityAssessmentRequest(
                content: htmlContent,
                clientId: client.id
            )
            
            let assessmentResponse = try await handlers.handleAssessmentRequest(request: assessmentRequest)
            
            if assessmentResponse.success {
                let assessment = assessmentResponse.assessment!
                print("✅ Assessment completed!")
                print("   Overall Score: \(String(format: "%.1f%%", assessment.overallScore * 100))")
                print("   WCAG Compliance: \(String(format: "%.1f%%", assessment.wcagCompliance.compliancePercentage))")
                print("   Screen Reader Compatible: \(assessment.screenReaderCompatibility.compatible ? "Yes" : "No")")
                print("   Keyboard Accessible: \(assessment.keyboardNavigationResult.accessible ? "Yes" : "No")")
                print("   Color Contrast Issues: \(assessment.colorContrastIssues.count)")
                print("   Alt Text Suggestions: \(assessment.altTextSuggestions.count)")
                
                // Generate alt text for an image
                print("\n🖼️  Generating Alt Text...")
                let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // Mock PNG
                let altTextRequest = AltTextRequest(imageData: imageData, clientId: client.id)
                let altTextResponse = try await handlers.handleAltTextRequest(request: altTextRequest)
                
                if altTextResponse.success {
                    let suggestions = altTextResponse.suggestions!
                    print("✅ Alt text generated!")
                    for suggestion in suggestions {
                        print("   \(suggestion.type.rawValue): \(suggestion.text) (confidence: \(String(format: "%.0f%%", suggestion.confidence * 100)))")
                    }
                }
                
                // Generate recommendations
                print("\n💡 Accessibility Recommendations:")
                let updatedClient = await coordinator.getClient(id: client.id)
                if let client = updatedClient {
                    for recommendation in client.recommendations.prefix(3) {
                        print("   • \(recommendation.title) (\(recommendation.priority.rawValue))")
                        print("     \(recommendation.description)")
                    }
                }
                
            } else {
                print("❌ Assessment failed: \(assessmentResponse.error!)")
            }
        } else {
            print("❌ Client creation failed: \(createResponse.error!)")
        }
        
        print("\n🎉 Demo completed!")
    }
}
