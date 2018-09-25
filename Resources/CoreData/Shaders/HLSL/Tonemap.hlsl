#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float cTonemapExposureBias;
uniform float cTonemapMaxWhite;

#else

#ifdef COMPILEPS
// D3D11 constant buffers
cbuffer CustomPS : register(b6)
{
    float cTonemapExposureBias;
    float cTonemapMaxWhite;
}
#endif

#endif

struct VertexIn
{
    float4 Pos : POSITION;
};

struct PixelIn
{
    float2 ScreenPos : TEXCOORD0;
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
    Out.ScreenPos = GetScreenPosPreDiv(Out.Pos);
}

void PS(PixelIn In, out PixelOut Out)
{
    #ifdef REINHARDEQ3
    float3 color = ReinhardEq3Tonemap(max(Sample2D(DiffMap, In.ScreenPos).rgb * cTonemapExposureBias, 0.0));
    Out.Color = float4(color, 1.0);
    #endif

    #ifdef REINHARDEQ4
    float3 color = ReinhardEq4Tonemap(max(Sample2D(DiffMap, In.ScreenPos).rgb * cTonemapExposureBias, 0.0), cTonemapMaxWhite);
    Out.Color = float4(color, 1.0);
    #endif

    #ifdef UNCHARTED2
    float3 color = Uncharted2Tonemap(max(Sample2D(DiffMap, In.ScreenPos).rgb * cTonemapExposureBias, 0.0)) / 
        Uncharted2Tonemap(float3(cTonemapMaxWhite, cTonemapMaxWhite, cTonemapMaxWhite));
    Out.Color = float4(color, 1.0);
    #endif
}
