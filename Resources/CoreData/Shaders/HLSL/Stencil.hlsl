#include "Uniforms.hlsl"
#include "Transform.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
};

struct PixelIn
{
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
}

void PS(PixelIn In, out PixelOut Out)
{
    Out.Color = 1.0;
}
