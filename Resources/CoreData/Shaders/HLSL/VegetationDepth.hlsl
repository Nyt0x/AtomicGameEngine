#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float cWindHeightFactor;
uniform float cWindHeightPivot;
uniform float cWindPeriod;
uniform float2 cWindWorldSpacing;

#else

// D3D11 constant buffer
cbuffer CustomVS : register(b6)
{
    float cWindHeightFactor;
    float cWindHeightPivot;
    float cWindPeriod;
    float2 cWindWorldSpacing;
}

#endif

struct VertexIn
{
    float4 Pos : POSITION;
#ifdef SKINNED
    float4 BlendWeights : BLENDWEIGHT;
    int4 BlendIndices : BLENDINDICES;
#endif
#ifdef INSTANCED
    float4x3 ModelInstance : TEXCOORD4;
#endif
    float2 TexCoord : TEXCOORD0;
};

struct PixelIn
{
    float3 TexCoord : TEXCOORD0;
    float4 Pos : OUTPOSITION;
};

void VS(VertexIn In, out PixelIn Out)
{
    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);

    float windStrength = max(In.Pos.y - cWindHeightPivot, 0.0) * cWindHeightFactor;
    float windPeriod = cElapsedTime * cWindPeriod + dot(worldPos.xz, cWindWorldSpacing);
    worldPos.x += windStrength * sin(windPeriod);
    worldPos.z -= windStrength * cos(windPeriod);

    Out.Pos = GetClipPos(worldPos);
    Out.TexCoord = float3(GetTexCoord(In.TexCoord), GetDepth(Out.Pos));
}
