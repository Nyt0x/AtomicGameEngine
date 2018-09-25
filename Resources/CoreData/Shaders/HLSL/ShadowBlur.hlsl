#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float2 cBlurOffsets;

#else

#ifdef COMPILEPS
// D3D11 constant buffers
cbuffer CustomPS : register(b6)
{
    float2 cBlurOffsets;
}
#endif

#endif

struct VertexIn
{
    float4 iPos : POSITION;
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
    float2 color = 0.0;

    color += 0.015625 * Sample2D(DiffMap, In.ScreenPos - 3.0 * cBlurOffsets).rg;
    color += 0.09375 * Sample2D(DiffMap, In.ScreenPos - 2.0 * cBlurOffsets).rg;
    color += 0.234375 * Sample2D(DiffMap, In.ScreenPos - cBlurOffsets).rg;
    color += 0.3125 * Sample2D(DiffMap, In.ScreenPos).rg;
    color += 0.234375 * Sample2D(DiffMap, In.ScreenPos + cBlurOffsets).rg;
    color += 0.09375 * Sample2D(DiffMap, In.ScreenPos + 2.0 * cBlurOffsets).rg;
    color += 0.015625 * Sample2D(DiffMap, In.ScreenPos + 3.0 * cBlurOffsets).rg;

    Out.Color = float4(color, 0.0, 0.0);
}

