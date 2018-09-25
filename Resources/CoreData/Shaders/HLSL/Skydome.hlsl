#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
    float2 TexCoord: TEXCOORD0;
};

struct PixelIn
{
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
    
    Out.Pos.z = oPos.w;
    Out.TexCoord = In.TexCoord;
}

void PS(PixelIn In, out PixelOut Out)
{
    Out.Color = cMatDiffColor * Sample2D(DiffMap, In.TexCoord);
}
