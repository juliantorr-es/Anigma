//
//  OnboardingManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public enum OnboardingStep: String, Codable, Sendable {
    case welcome
    case selectIdentitySource
    case connectSchool
    case connectStorage
    case connectLMS
    case configureSSO
    case validateMDM
    case setProjections
    case complete
}

public struct OnboardingFlow: Codable, Sendable {
    public let role: UserRole
    public let steps: [OnboardingStep]
    public var currentStepIndex: Int

    public init(role: UserRole, steps: [OnboardingStep], currentStepIndex: Int = 0) {
        self.role = role
        self.steps = steps
        self.currentStepIndex = currentStepIndex
    }

    public var currentStep: OnboardingStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
}

public actor OnboardingManager {
    private var flows: [String: OnboardingFlow] = [:] // UserID -> Flow

    public init() {}

    public func startOnboarding(userId: String, role: UserRole) -> OnboardingFlow {
        let steps: [OnboardingStep]

        switch role {
        case .user: // Student/Standard User
            steps = [.welcome, .connectSchool, .connectStorage, .setProjections, .complete]
        case .auditor: // Staff/Auditor
            steps = [.welcome, .selectIdentitySource, .connectLMS, .complete]
        case .admin: // School Admin
            steps = [.welcome, .configureSSO, .connectLMS, .complete]
        case .itAdmin: // IT Admin
            steps = [.welcome, .validateMDM, .configureSSO, .complete]
        }

        let flow = OnboardingFlow(role: role, steps: steps)
        flows[userId] = flow
        return flow
    }

    public func completeStep(userId: String) -> OnboardingFlow? {
        guard var flow = flows[userId] else { return nil }

        if flow.currentStepIndex < flow.steps.count {
            flow.currentStepIndex += 1
        }

        flows[userId] = flow
        return flow
    }

    public func getFlow(userId: String) -> OnboardingFlow? {
        return flows[userId]
    }
}
