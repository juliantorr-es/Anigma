//
//  TranslatorRegistry.swift
//  AnigmaCore
//
//  Registry for transforming requests/responses between AI provider formats.
//  Inspired by CLIProxyAPI.
//

import Foundation

public enum InferenceFormat: String, Sendable, Hashable, Codable {
    case openai
    case gemini
    case claude
    case codex
    case anigma // Internal canonical format
}

public typealias RequestTransform = @Sendable (
    _ model: String,
    _ payload: Data,
    _ isStream: Bool
) throws -> Data

public typealias ResponseTransform = @Sendable (
    _ model: String,
    _ payload: Data
) throws -> Data

/// Registry for managing format transformations.
public actor TranslatorRegistry {
    public static let shared = TranslatorRegistry()

    private var requestTransforms: [InferenceFormat: [InferenceFormat: RequestTransform]] = [:]
    private var responseTransforms: [InferenceFormat: [InferenceFormat: ResponseTransform]] = [:]

    public init() {
        let defaults = Self.createDefaultTranslators()
        self.requestTransforms = defaults.0
        self.responseTransforms = defaults.1
    }

    private static func createDefaultTranslators() -> (
        [InferenceFormat: [InferenceFormat: RequestTransform]],
        [InferenceFormat: [InferenceFormat: ResponseTransform]]
    ) {
        var requestTransforms: [InferenceFormat: [InferenceFormat: RequestTransform]] = [:]
        var responseTransforms: [InferenceFormat: [InferenceFormat: ResponseTransform]] = [:]

        // OpenAI to Gemini
        requestTransforms[.openai] = [.gemini: { _, data, _ in return data }]
        responseTransforms[.openai] = [.gemini: { _, data in return data }]

        // OpenAI to Claude
        requestTransforms[.openai]?[.claude] = { _, data, _ in return data }
        responseTransforms[.openai]?[.claude] = { _, data in return data }

        return (requestTransforms, responseTransforms)
    }

    public func register(
        from: InferenceFormat,
        to: InferenceFormat,
        request: RequestTransform? = nil,
        response: ResponseTransform? = nil
    ) {
        if let request = request {
            if requestTransforms[from] == nil { requestTransforms[from] = [:] }
            requestTransforms[from]![to] = request
        }

        if let response = response {
            if responseTransforms[from] == nil { responseTransforms[from] = [:] }
            responseTransforms[from]![to] = response
        }
    }

    public func translateRequest(
        _ payload: Data,
        from: InferenceFormat,
        to: InferenceFormat,
        model: String,
        isStream: Bool
    ) throws -> Data {
        guard from != to else { return payload }

        // Check for direct transform
        if let transform = requestTransforms[from]?[to] {
            return try transform(model, payload, isStream)
        }

        // Fallback: Translate via canonical Anigma format
        if from != .anigma && to != .anigma {
            let canonical = try translateRequest(payload, from: from, to: .anigma, model: model, isStream: isStream)
            return try translateRequest(canonical, from: .anigma, to: to, model: model, isStream: isStream)
        }

        throw TranslatorError.unsupportedTransformation(from: from, to: to)
    }

    public func translateResponse(
        _ payload: Data,
        from: InferenceFormat,
        to: InferenceFormat,
        model: String
    ) throws -> Data {
        guard from != to else { return payload }

        if let transform = responseTransforms[from]?[to] {
            return try transform(model, payload)
        }

        if from != .anigma && to != .anigma {
            let canonical = try translateResponse(payload, from: from, to: .anigma, model: model)
            return try translateResponse(canonical, from: .anigma, to: to, model: model)
        }

        throw TranslatorError.unsupportedTransformation(from: from, to: to)
    }
}

public enum TranslatorError: Error, LocalizedError {
    case unsupportedTransformation(from: InferenceFormat, to: InferenceFormat)

    public var errorDescription: String? {
        switch self {
        case .unsupportedTransformation(let from, let to):
            return "No translator registered from \(from.rawValue) to \(to.rawValue)"
        }
    }
}
