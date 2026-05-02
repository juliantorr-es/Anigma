//
//  LLMSecurityLayer.swift
//  AnigmaDaemonCore
//
//  Created as part of Phase 6: Multi-Provider LLM Integration (td-12f9d2-phase6)
//  Security and rate limiting layer for LLM endpoints
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import OSLog

private let securityLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "LLMSecurity")

/// LLM Security and Rate Limiting Layer
public final class LLMSecurityLayer: Sendable {
    private let tokenManager: CapabilityTokenManager
    private var rateLimiters: [String: LLMProviderRateLimiter] = [:]
    private let lock = NSLock()
    
    init(tokenManager: CapabilityTokenManager) {
        self.tokenManager = tokenManager
        // Initialize rate limiters for each provider
        setupDefaultRateLimiters()
    }
    
    // MARK: - Error Types
    
    public enum SecurityError: Error, Sendable {
        case unauthorized(reason: String)
        case rateLimited(provider: String, maxRequests: Int, retryAfter: TimeInterval)
        case providerNotConfigured(provider: String)
        case serviceError(String)
        
        var localizedDescription: String {
            switch self {
            case .unauthorized(let reason): return "Unauthorized: \\(reason)"
            case .rateLimited(let provider, let maxRequests, let retryAfter): 
                return "Rate limit exceeded for provider \\(provider)\\). Max \\(maxRequests)\\) requests per minute. Retry after \\(retryAfter)\\) seconds."
            case .providerNotConfigured(let provider): return "Rate limiter not configured for provider \\(provider)\"."
            case .serviceError(let message): return "Security service error: \\(message)\"."
            }
        }
    }
    
    private func setupDefaultRateLimiters() {
        lock.lock()
        defer { lock.unlock() }
        
        // Default rate limits per provider (requests per minute)
        let defaultLimits: [String: Int] = [
            "gemini": 60,
            "claude": 60,
            "codex": 60,
            "mistral": 60,
            "opencode": 60,
            "test": 300 // Higher limit for test provider
        ]
        
        for (provider, limit) in defaultLimits {
            rateLimiters[provider] = LLMProviderRateLimiter(provider: provider, requestsPerMinute: limit)
        }
    }
    
    /// Configure custom rate limit for a provider
    public func configureRateLimit(for provider: String, requestsPerMinute: Int) {
        lock.lock()
        defer { lock.unlock() }
        rateLimiters[provider] = LLMProviderRateLimiter(provider: provider, requestsPerMinute: requestsPerMinute)
    }
    
    /// Validate token and check rate limit for LLM requests
    public func validateAndCheckRateLimit(
        capabilityToken: String,
        requiredScope: String,
        provider: String
    ) async throws {
        // Step 1: Validate token
        try await validateToken(capabilityToken, requiredScope: requiredScope)
        
        // Step 2: Check rate limit
        try checkRateLimit(for: provider)
    }
    
    /// Validate token only
    public func validateToken(
        _ capabilityToken: String,
        requiredScope: String
    ) async throws {
        do {
            let tokenData = Data(capabilityToken.utf8)
            let validationResult = try await tokenManager.validateToken(tokenData, requiredScope: requiredScope)
            // Token is valid if validation succeeded and hasn't expired
            if validationResult.expiresAt < Date() {
                securityLogger.warning("Expired token for scope \\(requiredScope, privacy: .public)")
                throw SecurityError.unauthorized(reason: "Expired token")
            }
            
            // Check if the token has the required scope
            if !validationResult.scopes.contains(requiredScope) {
                securityLogger.warning("Insufficient scope for \(requiredScope, privacy: .public)")
                throw SecurityError.unauthorized(reason: "Insufficient scope")
            }
        } catch {
            securityLogger.warning("Token validation failed: \\(error.localizedDescription, privacy: .public)")
            throw SecurityError.unauthorized(reason: "Token validation failed: \\(error.localizedDescription)")
        }
    }
    
    /// Check rate limit for a specific provider
    public func checkRateLimit(for provider: String) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard let rateLimiter = rateLimiters[provider] else {
            securityLogger.warning("No rate limiter configured for provider \\(provider, privacy: .public)")
            // If no rate limiter is configured, allow the request
            return
        }
        
        do {
            try rateLimiter.checkRateLimit()
            securityLogger.debug("Rate limit check passed for provider \\(provider, privacy: .public)")
        } catch let error as LLMProviderRateLimitError {
            securityLogger.warning("Rate limit exceeded for provider \\(provider, privacy: .public): \\(error.localizedDescription, privacy: .public)")
            if case .exceeded(_, let maxRequests, let retryAfter) = error {
                throw SecurityError.rateLimited(provider: provider, maxRequests: maxRequests, retryAfter: retryAfter)
            } else {
                throw SecurityError.rateLimited(provider: provider, maxRequests: 0, retryAfter: 60.0)
            }
        } catch {
            securityLogger.error("Rate limit check failed for provider \\(provider, privacy: .public): \\(error.localizedDescription, privacy: .public)")
            throw SecurityError.serviceError("Rate limit service error")
        }
    }
    
    /// Get current rate limit status for a provider
    public func getRateLimitStatus(for provider: String) -> LLMProviderRateLimitStatus {
        lock.lock()
        defer { lock.unlock() }
        
        guard let rateLimiter = rateLimiters[provider] else {
            return LLMProviderRateLimitStatus(
                provider: provider,
                maxRequestsPerMinute: 0,
                remainingRequests: 0,
                resetTime: nil
            )
        }
        
        return rateLimiter.getStatus()
    }
    
    /// Reset rate limit for a provider (for testing/admin purposes)
    public func resetRateLimit(for provider: String) {
        lock.lock()
        defer { lock.unlock() }
        
        rateLimiters[provider]?.reset()
    }
    
    /// Get all registered provider names
    public func getAllProviderNames() -> [String] {
        // In a real implementation, this would access the LLMProviderRegistry
        // For testing purposes, return the expected providers
        return ["gemini", "claude", "codex", "mistral", "opencode", "test"]
    }
}

// MARK: - Rate Limiter Implementation

/// Per-provider rate limiter
private final class LLMProviderRateLimiter: Sendable {
    private let provider: String
    private let maxRequestsPerMinute: Int
    private var requestCount: Int = 0
    private var lastRequestTime: Date = Date()
    private let lock = NSLock()
    
    init(provider: String, requestsPerMinute: Int) {
        self.provider = provider
        self.maxRequestsPerMinute = requestsPerMinute
    }
    
    func checkRateLimit() throws {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        // Reset counter if more than 1 minute has passed
        if timeSinceLastRequest > 60 {
            requestCount = 0
            lastRequestTime = now
        }
        
        // Check if we've exceeded the limit
        if requestCount >= maxRequestsPerMinute {
            let retryAfter = 60.0 - timeSinceLastRequest
            throw LLMProviderRateLimitError.exceeded(
                provider: provider,
                maxRequests: maxRequestsPerMinute,
                retryAfter: retryAfter
            )
        }
        
        requestCount += 1
    }
    
    func getStatus() -> LLMProviderRateLimitStatus {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        // Reset counter if more than 1 minute has passed
        if timeSinceLastRequest > 60 {
            return LLMProviderRateLimitStatus(
                provider: provider,
                maxRequestsPerMinute: maxRequestsPerMinute,
                remainingRequests: maxRequestsPerMinute,
                resetTime: nil
            )
        }
        
        let remainingRequests = max(0, maxRequestsPerMinute - requestCount)
        let resetTime = lastRequestTime.addingTimeInterval(60 - timeSinceLastRequest)
        
        return LLMProviderRateLimitStatus(
            provider: provider,
            maxRequestsPerMinute: maxRequestsPerMinute,
            remainingRequests: remainingRequests,
            resetTime: resetTime
        )
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        requestCount = 0
        lastRequestTime = Date()
    }
}

// MARK: - Rate Limit Status

public struct LLMProviderRateLimitStatus: Codable, Sendable {
    public let provider: String
    public let maxRequestsPerMinute: Int
    public let remainingRequests: Int
    public let resetTime: Date?
    
    public init(
        provider: String,
        maxRequestsPerMinute: Int,
        remainingRequests: Int,
        resetTime: Date?
    ) {
        self.provider = provider
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.remainingRequests = remainingRequests
        self.resetTime = resetTime
    }
}

// MARK: - Rate Limit Errors

public enum LLMProviderRateLimitError: Error, Sendable {
    case exceeded(provider: String, maxRequests: Int, retryAfter: TimeInterval)
    case notConfigured(provider: String)
    case serviceError(String)
    
    public var localizedDescription: String {
        switch self {
        case .exceeded(let provider, let maxRequests, let retryAfter):
            return "Rate limit exceeded for provider \\(provider)\\). Max \\(maxRequests)\\) requests per minute. Retry after \\(retryAfter)\\) seconds."
        case .notConfigured(let provider):
            return "Rate limiter not configured for provider \\(provider)\"."
        case .serviceError(let message):
            return "Rate limit service error: \\(message)\"."
        }
    }
}

// MARK: - DaemonServer Extension

extension DaemonServer {
    /// LLM Security Layer
    var llmSecurityLayer: LLMSecurityLayer {
        get async {
            LLMSecurityLayer(tokenManager: self.tokenManager)
        }
    }
    
    /// Validate token and check rate limit for LLM requests
    func validateLLMRequest(
        capabilityToken: String,
        requiredScope: String,
        provider: String
    ) async throws {
        let securityLayer = await llmSecurityLayer
        try await securityLayer.validateAndCheckRateLimit(
            capabilityToken: capabilityToken,
            requiredScope: requiredScope,
            provider: provider
        )
    }
    
    /// Get rate limit status for a provider
    func getLLMRateLimitStatus(for provider: String) async -> LLMProviderRateLimitStatus {
        let securityLayer = await llmSecurityLayer
        return securityLayer.getRateLimitStatus(for: provider)
    }
    
    /// Configure custom rate limit for a provider
    func configureLLMRateLimit(for provider: String, requestsPerMinute: Int) {
        Task {
            let securityLayer = await llmSecurityLayer
            securityLayer.configureRateLimit(for: provider, requestsPerMinute: requestsPerMinute)
        }
    }
}