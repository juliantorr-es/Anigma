// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

/// API handlers for accessibility assessments to be integrated with AnigmaDaemonCore
public struct AccessibilityHandlers {
    private let coordinator: AccessumCoordinator
    
    public init(coordinator: AccessumCoordinator = AccessumCoordinator()) {
        self.coordinator = coordinator
    }
    
    // MARK: - Public API Endpoints
    
    /// Handle accessibility assessment request
    public func handleAssessmentRequest(request: AccessibilityAssessmentRequest) async throws -> AccessibilityAssessmentResponse {
        do {
            let assessment = try await coordinator.assessContent(
                request.content,
                clientId: request.clientId
            )
            
            return AccessibilityAssessmentResponse(
                success: true,
                assessment: assessment,
                error: nil
            )
        } catch {
            return AccessibilityAssessmentResponse(
                success: false,
                assessment: nil,
                error: error.localizedDescription
            )
        }
    }
    
    /// Handle client creation request
    public func handleClientCreationRequest(request: CreateClientRequest) async throws -> CreateClientResponse {
        let client = await coordinator.createClient(
            requirements: request.requirements,
            preferences: request.preferences
        )
        
        return CreateClientResponse(
            success: true,
            client: client,
            error: nil
        )
    }
    
    /// Handle client update request
    public func handleClientUpdateRequest(request: UpdateClientRequest) async throws -> UpdateClientResponse {
        do {
            if let requirements = request.requirements {
                try await coordinator.updateClientRequirements(id: request.clientId, requirements: requirements)
            }
            
            if let preferences = request.preferences {
                try await coordinator.updateClientPreferences(id: request.clientId, preferences: preferences)
            }
            
            let updatedClient = await coordinator.getClient(id: request.clientId)
            
            return UpdateClientResponse(
                success: true,
                client: updatedClient,
                error: nil
            )
        } catch {
            return UpdateClientResponse(
                success: false,
                client: nil,
                error: error.localizedDescription
            )
        }
    }
    
    /// Handle alt text generation request
    public func handleAltTextRequest(request: AltTextRequest) async throws -> AltTextResponse {
        do {
            let suggestions = try await coordinator.generateAltText(
                for: request.imageData,
                clientId: request.clientId
            )
            
            return AltTextResponse(
                success: true,
                suggestions: suggestions,
                error: nil
            )
        } catch {
            return AltTextResponse(
                success: false,
                suggestions: nil,
                error: error.localizedDescription
            )
        }
    }
    
    /// Handle WCAG compliance check request
    public func handleWCAGCheckRequest(request: WCAGCheckRequest) async throws -> WCAGCheckResponse {
        do {
            let result = try await coordinator.checkWCAGCompliance(
                for: request.content,
                level: request.level
            )
            
            return WCAGCheckResponse(
                success: true,
                result: result,
                error: nil
            )
        } catch {
            return WCAGCheckResponse(
                success: false,
                result: nil,
                error: error.localizedDescription
            )
        }
    }
    
    /// Handle screen reader report request
    public func handleScreenReaderReportRequest(request: ScreenReaderReportRequest) async throws -> ScreenReaderReportResponse {
        do {
            let result = try await coordinator.generateScreenReaderReport(for: request.content)
            
            return ScreenReaderReportResponse(
                success: true,
                result: result,
                error: nil
            )
        } catch {
            return ScreenReaderReportResponse(
                success: false,
                result: nil,
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Request/Response Models

/// Request model for accessibility assessment
public struct AccessibilityAssessmentRequest: Codable, Sendable {
    public let content: String
    public let clientId: UUID?
    
    public init(content: String, clientId: UUID? = nil) {
        self.content = content
        self.clientId = clientId
    }
}

/// Response model for accessibility assessment
public struct AccessibilityAssessmentResponse: Codable, Sendable {
    public let success: Bool
    public let assessment: AccessibilityAssessment?
    public let error: String?
    
    public init(success: Bool, assessment: AccessibilityAssessment?, error: String?) {
        self.success = success
        self.assessment = assessment
        self.error = error
    }
}

/// Request model for client creation
public struct CreateClientRequest: Codable, Sendable {
    public let requirements: AccessibilityRequirements
    public let preferences: AccessibilityPreferences
    
    public init(requirements: AccessibilityRequirements = AccessibilityRequirements(),
                preferences: AccessibilityPreferences = AccessibilityPreferences()) {
        self.requirements = requirements
        self.preferences = preferences
    }
}

/// Response model for client creation
public struct CreateClientResponse: Codable, Sendable {
    public let success: Bool
    public let client: AccessibilityClient?
    public let error: String?
    
    public init(success: Bool, client: AccessibilityClient?, error: String?) {
        self.success = success
        self.client = client
        self.error = error
    }
}

/// Request model for client update
public struct UpdateClientRequest: Codable, Sendable {
    public let clientId: UUID
    public let requirements: AccessibilityRequirements?
    public let preferences: AccessibilityPreferences?
    
    public init(clientId: UUID, requirements: AccessibilityRequirements?, preferences: AccessibilityPreferences?) {
        self.clientId = clientId
        self.requirements = requirements
        self.preferences = preferences
    }
}

/// Response model for client update
public struct UpdateClientResponse: Codable, Sendable {
    public let success: Bool
    public let client: AccessibilityClient?
    public let error: String?
    
    public init(success: Bool, client: AccessibilityClient?, error: String?) {
        self.success = success
        self.client = client
        self.error = error
    }
}

/// Request model for alt text generation
public struct AltTextRequest: Codable, Sendable {
    public let imageData: Data
    public let clientId: UUID?
    
    public init(imageData: Data, clientId: UUID? = nil) {
        self.imageData = imageData
        self.clientId = clientId
    }
}

/// Response model for alt text generation
public struct AltTextResponse: Codable, Sendable {
    public let success: Bool
    public let suggestions: [AltTextSuggestion]?
    public let error: String?
    
    public init(success: Bool, suggestions: [AltTextSuggestion]?, error: String?) {
        self.success = success
        self.suggestions = suggestions
        self.error = error
    }
}

/// Request model for WCAG compliance check
public struct WCAGCheckRequest: Codable, Sendable {
    public let content: String
    public let level: WCAGComplianceLevel
    
    public init(content: String, level: WCAGComplianceLevel = .AA) {
        self.content = content
        self.level = level
    }
}

/// Response model for WCAG compliance check
public struct WCAGCheckResponse: Codable, Sendable {
    public let success: Bool
    public let result: WCAGComplianceResult?
    public let error: String?
    
    public init(success: Bool, result: WCAGComplianceResult?, error: String?) {
        self.success = success
        self.result = result
        self.error = error
    }
}

/// Request model for screen reader report
public struct ScreenReaderReportRequest: Codable, Sendable {
    public let content: String
    
    public init(content: String) {
        self.content = content
    }
}

/// Response model for screen reader report
public struct ScreenReaderReportResponse: Codable, Sendable {
    public let success: Bool
    public let result: ScreenReaderResult?
    public let error: String?
    
    public init(success: Bool, result: ScreenReaderResult?, error: String?) {
        self.success = success
        self.result = result
        self.error = error
    }
}
