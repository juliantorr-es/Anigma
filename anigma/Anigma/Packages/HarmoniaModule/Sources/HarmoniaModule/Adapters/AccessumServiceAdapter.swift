// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import AccessumModule

// MARK: - Accessum Service Adapter

/// ServiceHandler adapter for AccessumModule
/// Provides accessibility assessment, client management, and content evaluation capabilities
/// to HarmoniaModule's workflow orchestration system
public actor AccessumServiceAdapter: ServiceHandler {
    // MARK: - Properties
    
    public let serviceId: String = "accessum-service"
    private let coordinator: AccessumCoordinator
    private var clients: [String: UUID] = [:] // Map service client IDs to AccessumModule UUIDs
    
    public private(set) var descriptor: ServiceDescriptor
    private var healthStatus: HealthStatus = .unknown
    
    // MARK: - Initialization
    
    /// Initialize AccessumServiceAdapter with optional custom coordinator
    /// - Parameter coordinator: Custom AccessumCoordinator instance (defaults to new instance)
    public init(coordinator: AccessumCoordinator = AccessumCoordinator()) {
        self.coordinator = coordinator
        self.descriptor = ServiceDescriptor(
            id: serviceId,
            name: "Accessum Service",
            version: "1.0.0",
            capabilities: Self.defaultCapabilities(),
            healthStatus: .unknown,
            lastHealthCheck: nil
        )
    }
    
    // MARK: - ServiceHandler Protocol Implementation
    
    /// Execute an action on the accessibility service
    /// - Parameters:
    ///   - action: The action to perform (assessContent, createClient, updateClient)
    ///   - input: Input parameters for the action
    /// - Returns: Action output as AnyCodable dictionary
    public func execute(action: String, input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        switch action {
        case "assessContent":
            return try await assessContent(input: input)
            
        case "createClient":
            return try await createClient(input: input)
            
        case "updateClient":
            return try await updateClient(input: input)
            
        default:
            throw AccessumAdapterError.unknownAction(action)
        }
    }
    
    /// Check the health status of the accessibility service
    public func getHealth() async throws -> HealthStatus {
        do {
            // Attempt a simple operation to verify service health
            let testClient = await coordinator.createClient()
            
            // Attempt a minimal assessment
            _ = try await coordinator.assessContent("health-check", clientId: testClient.id)
            
            healthStatus = .healthy
            updateDescriptorHealth(.healthy)
            return .healthy
        } catch {
            healthStatus = .degraded
            updateDescriptorHealth(.degraded)
            return .degraded
        }
    }
    
    // MARK: - Action Implementations
    
    /// Assess content for accessibility issues
    /// Input: { "content": String, "wcagLevel": String? ("A", "AA", "AAA"), "clientId": String? }
    /// Output: { "assessment": [assessment data], "score": Double, "issues": Int }
    private func assessContent(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        guard let contentValue = input["content"],
              case .string(let content) = contentValue else {
            throw AccessumAdapterError.missingRequiredParameter("content")
        }
        
        // Extract optional WCAG level
        var wcagLevel = WCAGComplianceLevel.AA
        if let levelValue = input["wcagLevel"],
           case .string(let levelStr) = levelValue {
            wcagLevel = parseWCAGLevel(levelStr)
        }
        
        // Extract optional client ID
        var clientId: UUID? = nil
        if let clientIdValue = input["clientId"],
           case .string(let clientIdStr) = clientIdValue,
           let uuid = UUID(uuidString: clientIdStr) {
            clientId = uuid
        }
        
        do {
            let assessment = try await coordinator.assessContent(content, clientId: clientId)
            
            return [
                "assessmentId": .string(assessment.id.uuidString),
                "overallScore": .double(assessment.overallScore),
                "wcagCompliance": .dictionary(encodeWCAGResult(assessment.wcagCompliance)),
                "screenReaderCompatible": .bool(assessment.screenReaderCompatibility.compatible),
                "keyboardAccessible": .bool(assessment.keyboardNavigationResult.accessible),
                "colorContrastIssuesCount": .int(assessment.colorContrastIssues.count),
                "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
            ]
        } catch {
            throw AccessumAdapterError.assessmentFailed(error.localizedDescription)
        }
    }
    
    /// Create a new accessibility client
    /// Input: { "requirementsJson": String?, "preferencesJson": String? }
    /// Output: { "clientId": String, "createdAt": String }
    private func createClient(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        // Extract optional requirements
        var requirements = AccessibilityRequirements()
        if let reqValue = input["requirements"],
           case .dictionary(let reqDict) = reqValue {
            requirements = decodeAccessibilityRequirements(reqDict)
        }
        
        // Extract optional preferences
        var preferences = AccessibilityPreferences()
        if let prefValue = input["preferences"],
           case .dictionary(let prefDict) = prefValue {
            preferences = decodeAccessibilityPreferences(prefDict)
        }
        
        let client = await coordinator.createClient(
            requirements: requirements,
            preferences: preferences
        )
        
        // Store mapping for future reference
        clients[client.id.uuidString] = client.id
        
        return [
            "clientId": .string(client.id.uuidString),
            "createdAt": .string(ISO8601DateFormatter().string(from: Date())),
            "wcagLevel": .string(client.requirements.wcagLevel.rawValue)
        ]
    }
    
    /// Update an existing accessibility client
    /// Input: { "clientId": String, "requirements": [dict]?, "preferences": [dict]? }
    /// Output: { "clientId": String, "updated": Bool, "updatedAt": String }
    private func updateClient(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        guard let clientIdValue = input["clientId"],
              case .string(let clientIdStr) = clientIdValue,
              let clientId = UUID(uuidString: clientIdStr) else {
            throw AccessumAdapterError.missingRequiredParameter("clientId")
        }
        
        var updateCount = 0
        
        // Update requirements if provided
        if let reqValue = input["requirements"],
           case .dictionary(let reqDict) = reqValue {
            let requirements = decodeAccessibilityRequirements(reqDict)
            do {
                try await coordinator.updateClientRequirements(id: clientId, requirements: requirements)
                updateCount += 1
            } catch {
                throw AccessumAdapterError.updateFailed("requirements", error.localizedDescription)
            }
        }
        
        // Update preferences if provided
        if let prefValue = input["preferences"],
           case .dictionary(let prefDict) = prefValue {
            let preferences = decodeAccessibilityPreferences(prefDict)
            do {
                try await coordinator.updateClientPreferences(id: clientId, preferences: preferences)
                updateCount += 1
            } catch {
                throw AccessumAdapterError.updateFailed("preferences", error.localizedDescription)
            }
        }
        
        guard updateCount > 0 else {
            throw AccessumAdapterError.noUpdatesProvided
        }
        
        return [
            "clientId": .string(clientIdStr),
            "updated": .bool(true),
            "updatedAt": .string(ISO8601DateFormatter().string(from: Date())),
            "fieldsUpdated": .int(updateCount)
        ]
    }
    
    // MARK: - Helper Methods
    
    /// Default service capabilities
    private static func defaultCapabilities() -> [ServiceCapability] {
        [
            ServiceCapability(
                action: "assessContent",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 30.0
            ),
            ServiceCapability(
                action: "createClient",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 5.0
            ),
            ServiceCapability(
                action: "updateClient",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 5.0
            )
        ]
    }
    
    /// Update the descriptor with new health status
    private func updateDescriptorHealth(_ status: HealthStatus) {
        self.descriptor = ServiceDescriptor(
            id: descriptor.id,
            name: descriptor.name,
            version: descriptor.version,
            capabilities: descriptor.capabilities,
            healthStatus: status,
            lastHealthCheck: Date()
        )
    }
    
    /// Parse WCAG level string
    private func parseWCAGLevel(_ levelStr: String) -> WCAGComplianceLevel {
        switch levelStr.uppercased() {
        case "A":
            return .A
        case "AAA":
            return .AAA
        default:
            return .AA
        }
    }
    
    /// Encode WCAG compliance result to AnyCodable
    private func encodeWCAGResult(_ result: WCAGComplianceResult) -> [String: AnyCodable] {
        [
            "level": .string(result.level.rawValue),
            "passedCount": .int(result.passedCriteria.count),
            "failedCount": .int(result.failedCriteria.count),
            "compliancePercentage": .double(result.compliancePercentage)
        ]
    }
    
    /// Decode accessibility requirements from AnyCodable
    private func decodeAccessibilityRequirements(_ dict: [String: AnyCodable]) -> AccessibilityRequirements {
        var wcagLevel = WCAGComplianceLevel.AA
        if let levelValue = dict["wcagLevel"],
           case .string(let levelStr) = levelValue {
            wcagLevel = parseWCAGLevel(levelStr)
        }
        
        return AccessibilityRequirements(wcagLevel: wcagLevel)
    }
    
    /// Decode accessibility preferences from AnyCodable
    private func decodeAccessibilityPreferences(_ dict: [String: AnyCodable]) -> AccessibilityPreferences {
        var altTextGenerationEnabled = true
        var screenReaderOptimized = true
        var keyboardNavigationOptimized = true
        var highContrastMode = false
        
        if let altTextValue = dict["altTextGenerationEnabled"],
           case .bool(let enabled) = altTextValue {
            altTextGenerationEnabled = enabled
        }
        
        if let screenReaderValue = dict["screenReaderOptimized"],
           case .bool(let optimized) = screenReaderValue {
            screenReaderOptimized = optimized
        }
        
        if let keyboardValue = dict["keyboardNavigationOptimized"],
           case .bool(let optimized) = keyboardValue {
            keyboardNavigationOptimized = optimized
        }
        
        if let contrastValue = dict["highContrastMode"],
           case .bool(let enabled) = contrastValue {
            highContrastMode = enabled
        }
        
        return AccessibilityPreferences(
            altTextGenerationEnabled: altTextGenerationEnabled,
            screenReaderOptimized: screenReaderOptimized,
            keyboardNavigationOptimized: keyboardNavigationOptimized,
            highContrastMode: highContrastMode
        )
    }
}

// MARK: - Adapter Error Types

public enum AccessumAdapterError: LocalizedError, Sendable {
    case unknownAction(String)
    case missingRequiredParameter(String)
    case assessmentFailed(String)
    case updateFailed(String, String)
    case noUpdatesProvided
    case invalidInput(String)
    
    public var errorDescription: String? {
        switch self {
        case .unknownAction(let action):
            return "Unknown action: \(action)"
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
        case .assessmentFailed(let reason):
            return "Assessment failed: \(reason)"
        case .updateFailed(let field, let reason):
            return "Failed to update \(field): \(reason)"
        case .noUpdatesProvided:
            return "No updates provided in request"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        }
    }
}
