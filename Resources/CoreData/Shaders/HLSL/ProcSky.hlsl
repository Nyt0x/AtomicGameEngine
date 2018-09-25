#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
    float3 Normal : NORMAL;
};

struct PixelIn
{
    float4 Pos : POSITION;
    float3 TexCoord : TEXCOORD0;
};

struct PixelOut
{
    float4 Color : OUTCOLOR0;
};

void VS(VertexIn In, out PixelIn Out)
{
    Out.Pos = In.Pos;
    Out.TexCoord = In.Normal;
}

void PS(PixelIn In, out PixelOut Out)
{
    float3 V = normalize( In.TexCoord ) + float3(0, 0.2 ,0);
    float2 lt = float2( (1.0 + normalize( V.xz ).y) / 2.0, 1.0 - normalize( V ).y );
    Out.Color = float4(tex2D( sDiffMap, lt ).rgb, 1.0);
}


