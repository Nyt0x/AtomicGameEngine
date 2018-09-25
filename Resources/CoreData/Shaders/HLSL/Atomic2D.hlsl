#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR0;
};

struct PixelIn
{
    float4 Color : COLOR0;
    float2 TexCoord : TEXCOORD0;
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

    Out.Color = In.Color;
    Out.TexCoord = In.TexCoord;
}

void PS(PixelIn In, out PixelOut Out)
{
    float4 diffColor = cMatDiffColor * In.Color;
    float4 diffInput = Sample2D(DiffMap, In.TexCoord);
    Out.Color = diffColor * diffInput;
}
