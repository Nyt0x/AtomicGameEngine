#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

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
    float3 color = Sample2D(DiffMap, In.ScreenPos).rgb;
    Out.Color = float4(ToInverseGamma(color), 1.0);
}
