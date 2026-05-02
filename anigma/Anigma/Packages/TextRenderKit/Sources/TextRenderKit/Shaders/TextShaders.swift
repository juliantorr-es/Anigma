import Foundation
import Metal
import RendererKit

// MARK: - Text Shader Manager

/// Manages compilation and caching of text rendering shaders
public final class TextShaderManager: ShaderManager, @unchecked Sendable {
    
    // Shader cache
    private var shaderCache: [String: RendererKit.ShaderBinary] = [:]
    private let device: MTLDevice
    private let library: MTLLibrary
    
    // MARK: - Initialization
    
    public init(device: MTLDevice) throws {
        self.device = device
        
        // Load the default Metal library
        guard let library = device.makeDefaultLibrary() else {
            throw TextShaderError.libraryLoadFailed
        }
        self.library = library
        
    }

    // MARK: - Precompilation
    
    private func precompileEssentialShaders() async throws {
        // Pre-compile text vertex shader
        _ = try await compileShader(
            source: TextVertexShader.source,
            type: RendererKit.ShaderType.vertex,
            entryPoint: "text_vertex_main"
        )
        
        // Pre-compile text fragment shader
        _ = try await compileShader(
            source: TextFragmentShader.source,
            type: RendererKit.ShaderType.fragment,
            entryPoint: "text_fragment_main"
        )
        
        // Pre-compile SDF text fragment shader
        _ = try await compileShader(
            source: TextSDFFragmentShader.source,
            type: RendererKit.ShaderType.fragment,
            entryPoint: "text_sdf_fragment_main"
        )
    }
    
    // MARK: - Shader Compilation
    
    public func compileShader(
        source: String,
        type: RendererKit.ShaderType,
        entryPoint: String
    ) async throws -> RendererKit.ShaderBinary {
        // Check cache first
        let cacheKey = "\(type)_\(entryPoint)"
        if let cached = shaderCache[cacheKey] {
            return cached
        }
        
        // Compile the shader
        let shaderData: Data
        
        do {
            if type == .vertex {
                shaderData = try compileVertexShader(source, entryPoint: entryPoint)
            } else {
                shaderData = try compileFragmentShader(source, entryPoint: entryPoint)
            }
            
            let binary = RendererKit.ShaderBinary(
                data: shaderData,
                shaderType: type,
                entryPoint: entryPoint
            )
            
            // Cache the result
            shaderCache[cacheKey] = binary
            return binary
            
        } catch {
            throw TextShaderError.compilationFailed(
                "Failed to compile \(type) shader \(entryPoint): \(error)"
            )
        }
    }
    
    private func compileVertexShader(_ source: String, entryPoint: String) throws -> Data {
        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = makeShaderFunction(source, entryPoint: entryPoint)
        pipelineDescriptor.fragmentFunction = nil // Will be set separately
        
        // Create pipeline state
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Serialize the pipeline state (conceptual - in real implementation, we'd manage this differently)
        return Data(pipelineState.description.utf8)
    }
    
    private func compileFragmentShader(_ source: String, entryPoint: String) throws -> Data {
        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.fragmentFunction = makeShaderFunction(source, entryPoint: entryPoint)
        
        // Create pipeline state
        let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Serialize the pipeline state
        return Data(pipelineState.description.utf8)
    }
    
    private func makeShaderFunction(_ source: String, entryPoint: String) -> MTLFunction? {
        // Try to get function from library
        if let function = library.makeFunction(name: entryPoint) {
            return function
        }
        
        // If not found in default library, try to create from source
        // Note: In a real implementation, we'd use MTLLibrary(source:options:completionHandler:)
        // For this MVP, we'll return nil and let the error handling take over
        return nil
    }
    
    // MARK: - Cached Access
    
    public func getOrCompileShader(
        key: String,
        source: String,
        type: RendererKit.ShaderType
    ) async throws -> RendererKit.ShaderBinary {
        // Check cache first
        if let cached = shaderCache[key] {
            return cached
        }
        
        // Determine entry point from key
        let entryPoint: String
        if key.contains("vertex") {
            entryPoint = "text_vertex_main"
        } else if key.contains("sdf") {
            entryPoint = "text_sdf_fragment_main"
        } else {
            entryPoint = "text_fragment_main"
        }
        
        // Compile and cache
        let binary = try await compileShader(source: source, type: type, entryPoint: entryPoint)
        shaderCache[key] = binary
        return binary
    }
    
    // MARK: - Cache Management
    
    public func clearCache() async throws {
        shaderCache.removeAll()
    }
    
    // MARK: - Built-in Shaders
    
    public func getTextVertexShader() async throws -> RendererKit.ShaderBinary {
        return try await getOrCompileShader(
            key: "vertex_text",
            source: TextVertexShader.source,
            type: .vertex
        )
    }
    
    public func getTextFragmentShader() async throws -> RendererKit.ShaderBinary {
        return try await getOrCompileShader(
            key: "fragment_text",
            source: TextFragmentShader.source,
            type: .fragment
        )
    }
    
    public func getTextSDFFragmentShader() async throws -> RendererKit.ShaderBinary {
        return try await getOrCompileShader(
            key: "fragment_text_sdf",
            source: TextSDFFragmentShader.source,
            type: .fragment
        )
    }
}

// MARK: - Vertex Shader

/// Text vertex shader using Metal Shading Language
public enum TextVertexShader: Sendable {
    
    public static let source = """
    #include <metal_stdlib>
    using namespace metal;
    
    // Input vertex structure
    struct TextVertexIn {
        float2 position [[attribute(0)]];
        float2 uv [[attribute(1)]];
        float4 color [[attribute(2)]];
        uint glyph_id [[attribute(3)]];
    };
    
    // Output structure
    struct TextVertexOut {
        float4 position [[position]];
        float2 uv;
        float4 color;
        float glyph_id;
    };
    
    // Uniforms
    struct TextUniforms {
        float4x4 model_view_projection_matrix;
        float2 viewport_size;
        float font_size;
        float gamma;
    };
    
    vertex TextVertexOut text_vertex_main(
        TextVertexIn in [[stage_in]],
        constant TextUniforms &uniforms [[buffer(0)]]
    ) {
        TextVertexOut out;
        
        // Transform position
        float4 position = float4(in.position, 0.0, 1.0);
        position = uniforms.model_view_projection_matrix * position;
        out.position = position;
        
        // Pass through UV coordinates
        out.uv = in.uv;
        
        // Pass through color
        out.color = in.color;
        
        // Convert glyph ID to float for interpolation
        out.glyph_id = float(in.glyph_id);
        
        return out;
    }
    """
}

// MARK: - Fragment Shader (Basic)

/// Basic text fragment shader
public enum TextFragmentShader: Sendable {
    
    public static let source = """
    #include <metal_stdlib>
    using namespace metal;
    
    // Input from vertex shader
    struct TextVertexOut {
        float4 position [[position]];
        float2 uv;
        float4 color;
        float glyph_id;
    };
    
    // Texture for glyph atlas
    texture2d<float> glyph_atlas [[texture(0)]];
    sampler texture_sampler [[sampler(0)]];
    
    // Fragment shader
    fragment float4 text_fragment_main(
        TextVertexOut in [[stage_in]]
    ) {
        // Sample glyph from atlas
        float4 glyph_color = glyph_atlas.sample(texture_sampler, in.uv);
        
        // Apply text color
        float4 final_color = in.color * glyph_color;
        
        // Premultiply alpha
        final_color.rgb *= final_color.a;
        
        return final_color;
    }
    """
}

// MARK: - Fragment Shader (SDF - Signed Distance Field)

/// Advanced SDF text fragment shader for smooth rendering
public enum TextSDFFragmentShader: Sendable {
    
    public static let source = """
    #include <metal_stdlib>
    using namespace metal;
    
    // Input from vertex shader
    struct TextVertexOut {
        float4 position [[position]];
        float2 uv;
        float4 color;
        float glyph_id;
    };
    
    // SDF texture
    texture2d<float> sdf_atlas [[texture(0)]];
    sampler texture_sampler [[sampler(0)]];
    
    // Uniforms
    struct SDFUniforms {
        float smoothness;
        float width;
        float edge;
        float gamma;
    };
    
    fragment float4 text_sdf_fragment_main(
        TextVertexOut in [[stage_in]],
        constant SDFUniforms &uniforms [[buffer(1)]]
    ) {
        // Sample SDF value from texture
        float distance = sdf_atlas.sample(texture_sampler, in.uv).r;
        
        // Smoothstep for anti-aliasing
        float alpha = smoothstep(uniforms.width - uniforms.edge, uniforms.width + uniforms.edge, distance);
        
        // Apply smoothness
        alpha = smoothstep(0.0, 1.0, alpha);
        alpha = pow(alpha, uniforms.gamma);
        
        // Apply text color
        float4 final_color = in.color;
        final_color.a *= alpha;
        final_color.rgb *= final_color.a;
        
        return final_color;
    }
    """
}

// MARK: - Shader Pipeline Creator

/// Creates complete shader pipelines for text rendering
public struct TextShaderPipelineCreator: Sendable {
    
    public static func createTextPipeline(
        device: MTLDevice,
        vertexShader: RendererKit.ShaderBinary,
        fragmentShader: RendererKit.ShaderBinary,
        colorFormat: TextureFormat
    ) throws -> RenderPipeline {
        // In a real implementation, this would create an actual Metal pipeline
        // For this MVP, we return a placeholder
        
        return RenderPipeline(id: UUID(), backend: .metal)
    }
    
    public static func createSDFTextPipeline(
        device: MTLDevice,
        sdfFragmentShader: RendererKit.ShaderBinary,
        colorFormat: TextureFormat
    ) throws -> RenderPipeline {
        // SDF pipeline creation
        return RenderPipeline(id: UUID(), backend: .metal)
    }
}

// MARK: - Errors

public enum TextShaderError: Error, Equatable, Sendable {
    case libraryLoadFailed
    case compilationFailed(String)
    case pipelineCreationFailed(String)
    case shaderNotFound(String)
    case deviceUnsupported
    case metalNotAvailable
}
