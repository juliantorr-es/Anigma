// CapsuleError+C.swift
// CapsuleCore - Bidirectional C↔Swift error mapping
// Part of the Anigma remediation plan

import Foundation

// MARK: - C Error Type Definition

/// C-compatible error codes for Anigma capsules.
/// These MUST stay in sync with anigma_capsule_error_code_t in C headers.
public enum CapsuleErrorCode: Int32 {
    case ok = 0
    case invalidConfig = 1
    case operationFailed = 2
    case resourceExhausted = 3
    case invalidInput = 4
    case nativeError = 5
    case timeout = 6
    case internalError = 7
}

// MARK: - Swift to C Mapping

/// Convert a Swift CapsuleError to a C-compatible structured representation.
/// 
/// - Parameter error: The Swift error to map
/// - Returns: A dictionary representation suitable for FFI or JSON serialization
public func capsuleErrorToC(_ error: CapsuleError) -> [String: Any] {
    let code: CapsuleErrorCode
    let message: String
    var context: [String: String] = [:]
    
    switch error {
    case .invalidConfiguration(let reason):
        code = .invalidConfig
        message = reason
        
    case .operationFailed(let c, let m, let ctx):
        code = .operationFailed
        message = m
        context = ctx
        context["original_code"] = String(c)
        
    case .resourceExhausted(let resource, let limit):
        code = .resourceExhausted
        message = "Resource exhausted: \(resource)"
        context = ["resource": resource, "limit": limit]
        
    case .invalidInput(let field, let constraint):
        code = .invalidInput
        message = "Invalid input for \(field)"
        context = ["field": field, "constraint": constraint]
        
    case .nativeError(let c, let libraryName):
        code = .nativeError
        message = "Native error in \(libraryName)"
        context = ["native_code": String(c), "library": libraryName]
        
    case .timeout(let operation, let deadline):
        code = .timeout
        message = "Timeout in \(operation)"
        context = ["operation": operation, "deadline": String(format: "%.3f", deadline)]
        
    case .internalError(let details):
        code = .internalError
        message = details
    }
    
    var result: [String: Any] = [
        "code": code.rawValue,
        "message": message,
        "type": "CapsuleError"
    ]
    
    if !context.isEmpty {
        if let contextData = try? JSONSerialization.data(withJSONObject: context),
           let contextString = String(data: contextData, encoding: .utf8) {
            result["context"] = contextString
        }
    }
    
    return result
}

// MARK: - C to Swift Mapping

/// Reconstruct a CapsuleError from C-style components.
public func capsuleErrorFromC(
    code: Int32,
    message: String,
    contextJson: String? = nil
) -> CapsuleError {
    let errorCode = CapsuleErrorCode(rawValue: code) ?? .internalError
    
    var context: [String: String] = [:]
    if let json = contextJson?.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: json) as? [String: String] {
        context = decoded
    }
    
    switch errorCode {
    case .ok:
        return .internalError(details: "Attempted to create error from OK status")
        
    case .invalidConfig:
        return .invalidConfiguration(reason: message)
        
    case .operationFailed:
        let originalCode = UInt32(context["original_code"] ?? "0") ?? 0
        return .operationFailed(code: originalCode, message: message, context: context.filter { $0.key != "original_code" })
        
    case .resourceExhausted:
        return .resourceExhausted(resource: context["resource"] ?? "unknown", limit: context["limit"] ?? "unknown")
        
    case .invalidInput:
        return .invalidInput(field: context["field"] ?? "unknown", constraint: context["constraint"] ?? "unknown")
        
    case .nativeError:
        let nativeCode = Int32(context["native_code"] ?? "0") ?? 0
        return .nativeError(code: nativeCode, libraryName: context["library"] ?? "unknown")
        
    case .timeout:
        let deadline = TimeInterval(context["deadline"] ?? "0") ?? 0
        return .timeout(operation: context["operation"] ?? "unknown", deadline: deadline)
        
    case .internalError:
        return .internalError(details: message)
    }
}

// MARK: - JSON Serialization

extension CapsuleError {
    public var jsonString: String? {
        let dict = capsuleErrorToC(self)
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
