#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float2 position;
    float2 texCoord;
    float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                             constant Vertex *vertices [[buffer(0)]],
                             constant float4x4 &projectionMatrix [[buffer(1)]]) {
    VertexOut out;
    float2 pos = vertices[vertexID].position;
    out.position = projectionMatrix * float4(pos, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    out.color = vertices[vertexID].color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                               texture2d<float> tex [[texture(0)]],
                               sampler smp [[sampler(0)]],
                               constant bool &hasTexture [[buffer(0)]]) {
    if (hasTexture) {
        return tex.sample(smp, in.texCoord) * in.color;
    } else {
        return in.color;
    }
}
