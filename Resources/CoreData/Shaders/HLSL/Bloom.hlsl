#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float cBloomThreshold;
uniform float2 cBloomMix;
uniform float2 cBlurHOffsets;
uniform float2 cBlurHInvSize;

#else

// D3D11 constant buffers
#ifdef COMPILEVS
cbuffer CustomVS : register(b6)
{
    float2 cBlurHOffsets;
}
#else
cbuffer CustomPS : register(b6)
{
    float cBloomThreshold;
    float2 cBloomMix;
    float2 cBlurHInvSize;
}
#endif

#endif

static const float offsets[5] = {
    2.0,
    1.0,
    0.0,
    -1.0,
    -2.0,
};

static const float weights[5] = {
    0.1,
    0.25,
    0.3,
    0.25,
    0.1
};

struct VertexIn
{
    float4 iPos : POSITION;
};

struct PixelIn
{
    float2 TexCoord : TEXCOORD0;
    float2 ScreenPos : TEXCOORD1;
    float4 Pos : OUTPOSITION;
};

struct PixelOut
{
    float4 Color : OUTCOLOR0;
};


void VS(VertexIn In, out PixelIn Out)
{
    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBlurHOffsets;
    Out.ScreenPos = GetScreenPosPreDiv(Out.Pos);
}

void PS(PixelIn In, out PixelOut Out)
{
    #ifdef BRIGHT
    float3 rgb = Sample2D(DiffMap, In.ScreenPos).rgb;
    Out.Color = float4((rgb - cBloomThreshold) / (1.0 - cBloomThreshold), 1.0);
    #endif

    #ifdef BLURH
    float3 rgb = 0.0;
    for (int i = 0; i < 5; ++i)
        rgb += Sample2D(DiffMap, In.TexCoord + (float2(offsets[i], 0.0)) * cBlurHInvSize).rgb * weights[i];
    Out.Color = float4(rgb, 1.0);
    #endif

    #ifdef BLURV
    float3 rgb = 0.0;
    for (int i = 0; i < 5; ++i)
        rgb += Sample2D(DiffMap, In.TexCoord + (float2(0.0, offsets[i])) * cBlurHInvSize).rgb * weights[i];
    Out.Color = float4(rgb, 1.0);
    #endif

    #ifdef COMBINE
    float3 original = Sample2D(DiffMap, In.ScreenPos).rgb * cBloomMix.x;
    float3 bloom = Sample2D(NormalMap, In.TexCoord).rgb  * cBloomMix.y;
    // Prevent oversaturation
    original *= saturate(1.0 - bloom);
    Out.Color = float4(original + bloom, 1.0);
    #endif
}
