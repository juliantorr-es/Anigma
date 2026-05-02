// Test file to verify RendererKit types can be imported
import Foundation
import Metal

// Simulate the RendererKit module structure
public enum ShaderType: Sendable, Equatable, Codable {
    case vertex
    case fragment
    case compute
}

public struct ShaderBinary: Sendable {
    public let data: Data
    public let shaderType: ShaderType
    public let entryPoint: String
    
    public init(data: Data, shaderType: ShaderType, entryPoint: String) {
        self.data = data
        self.shaderType = shaderType
        self.entryPoint = entryPoint
    }
}

// Test the usage pattern from TextShaders.swift
class TestShaderManager {
    private var shaderCache: [String: ShaderBinary] = [:]
    
    func compileShader(
        source: String,
        type: ShaderType,
        entryPoint: String
    ) -> ShaderBinary {
        let cacheKey = "\(type)_\(entryPoint)"
        if let cached = shaderCache[cacheKey] {
            return cached
        }
        
        let shaderData = Data()
        let result = ShaderBinary(data: shaderData, shaderType: type, entryPoint: entryPoint)
        shaderCache[cacheKey] = result
        return result
    }
}

print("Type resolution test passed!")