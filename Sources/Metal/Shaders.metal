//
//  Shaders.metal
#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

typedef struct {
    int stereoMode;
    uint frameCounter;
} CustomData;

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} Uniforms;

typedef struct
{
    Uniforms uniforms[2];
} UniformsArray;

struct VertexIn
{
    float4 pos [[attribute(0)]];
    float2 uv [[attribute(1)]];
};

struct VertexOut {
    float4 renderedCoordinate [[position]];
    float2 textureCoordinate;
};

inline half4 gammaToLinear(half4 col) {
    half a = 0.305306011h;  // 使用 'h' 后缀来指明half类型的字面量
    half b = 0.682171111h;
    half c = 0.012522878h;

    // 只对颜色的RGB分量进行计算，保留Alpha分量不变
    half3 colRGB = col.rgb;
    colRGB = colRGB * (colRGB * (colRGB * a + b) + c);

    return half4(colRGB, col.a); // 重新构建包含修改后的RGB分量和原始Alpha分量的half4
}

vertex VertexOut mapTexture(VertexIn input [[stage_in]],
                            ushort ampId [[ amplification_id ]],
                            constant CustomData & customData [[ buffer(3) ]]) {
    VertexOut outVertex;
    float2 texCoord = input.uv;
    
    outVertex.renderedCoordinate = input.pos;
    if (customData.stereoMode == 1) {
        if (ampId == 0) {
            texCoord.x = texCoord.x * 0.5 + 0.5;
        } else {
            texCoord.x = texCoord.x * 0.5;
        }
    } else if (customData.stereoMode == 2) {
        if (ampId == 0) {
            texCoord.y = texCoord.y * 0.5;
        } else {
            texCoord.y = texCoord.y * 0.5 + 0.5;
        }
    }
    outVertex.textureCoordinate = texCoord;
    return outVertex;
}

vertex VertexOut mapSphereTexture(VertexIn input [[stage_in]],
                                  ushort ampId [[ amplification_id ]],
                                  constant CustomData& customData [[ buffer(3) ]],
                                  constant UniformsArray & uniformsArray [[ buffer(9) ]]) {
    VertexOut outVertex;
    Uniforms uniforms = uniformsArray.uniforms[ampId];
    
    outVertex.renderedCoordinate = uniforms.projectionMatrix * uniforms.modelViewMatrix * input.pos;
    float2 texCoord = input.uv;
    
    if (customData.stereoMode == 1) {
        if (ampId == 0) {
            texCoord.x = texCoord.x * 0.5;
        } else {
            texCoord.x = texCoord.x * 0.5 + 0.5;
        }
    } else if (customData.stereoMode == 2) {
        if (ampId == 0) {
            texCoord.y = texCoord.y * 0.5;
        } else {
            texCoord.y = texCoord.y * 0.5 + 0.5;
        }
    }
    outVertex.textureCoordinate = texCoord;
    
    return outVertex;
}

fragment half4 displayTexture(VertexOut mappingVertex [[ stage_in ]],
                              texture2d<half, access::sample> texture [[ texture(0) ]],
                              constant CustomData& customData [[ buffer(3) ]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 adjustedTexCoord = mappingVertex.textureCoordinate;
    
    half4 col = half4(texture.sample(s, adjustedTexCoord));
    half4 finalCol = gammaToLinear(col);
    return finalCol;
}

fragment half4 displayYUVTexture(VertexOut in [[ stage_in ]],
                                  texture2d<half> yTexture [[ texture(0) ]],
                                  texture2d<half> uTexture [[ texture(1) ]],
                                  texture2d<half> vTexture [[ texture(2) ]],
                                  sampler textureSampler [[ sampler(0) ]],
                                  constant float3x3& yuvToBGRMatrix [[ buffer(0) ]],
                                  constant float3& colorOffset [[ buffer(1) ]],
                                  constant uchar3& leftShift [[ buffer(2) ]],
                                  constant CustomData& customData [[ buffer(3) ]])
{
    half3 yuv;
    float2 adjustedTexCoord = in.textureCoordinate;

    yuv.x = yTexture.sample(textureSampler, adjustedTexCoord).r;
    yuv.y = uTexture.sample(textureSampler, adjustedTexCoord).r;
    yuv.z = vTexture.sample(textureSampler, adjustedTexCoord).r;
    half4 col = half4(half3x3(yuvToBGRMatrix)*(yuv*half3(leftShift)+half3(colorOffset)), 1);
    half4 finalCol = gammaToLinear(col);
    return finalCol;
}


fragment half4 displayNV12Texture(VertexOut in [[ stage_in ]],
                                  texture2d<half> lumaTexture [[ texture(0) ]],
                                  texture2d<half> chromaTexture [[ texture(1) ]],
                                  sampler textureSampler [[ sampler(0) ]],
                                  constant float3x3& yuvToBGRMatrix [[ buffer(0) ]],
                                  constant float3& colorOffset [[ buffer(1) ]],
                                  constant uchar3& leftShift [[ buffer(2) ]],
                                  constant CustomData& customData [[ buffer(3) ]])
{
    half3 yuv;
    float2 adjustedTexCoord = in.textureCoordinate;

    yuv.x = lumaTexture.sample(textureSampler, adjustedTexCoord).r;
    yuv.yz = chromaTexture.sample(textureSampler, adjustedTexCoord).rg;
    half4 col = half4(half3x3(yuvToBGRMatrix)*(yuv*half3(leftShift)+half3(colorOffset)), 1);
    half4 finalCol = gammaToLinear(col);
    return finalCol;
}



