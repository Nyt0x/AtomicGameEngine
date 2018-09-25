#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
#ifndef NOUV
    float2 TexCoord : TEXCOORD0;
#endif
#ifdef SKINNED
    float4 BlendWeights : BLENDWEIGHT;
    int4 BlendIndices : BLENDINDICES;
#endif
#ifdef INSTANCED
    float4x3 ModelInstance : TEXCOORD4;
#endif
#if defined(BILLBOARD) || defined(DIRBILLBOARD)
    float2 Size : TEXCOORD1;
#endif
};

struct PixelIn
{
#ifdef VSM_SHADOW
    float4 TexCoord : TEXCOORD0;
#else
    float2 TexCoord : TEXCOORD0;
#endif
    float4 Pos : OUTPOSITION;
};

struct PixelOut
{
    float4 Color : OUTCOLOR0;
};

void VS(VertexIn In, out PixelIn Out)
{
    // Define a 0,0 UV coord if not expected from the vertex data
    #ifdef NOUV
    float2 In.TexCoord = float2(0.0, 0.0);
    #endif

    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);
    #ifdef VSM_SHADOW
        Out.TexCoord = float4(GetTexCoord(In.TexCoord), Out.Pos.z, Out.Pos.w);
    #else
        Out.TexCoord = GetTexCoord(In.TexCoord);
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
    #ifdef ALPHAMASK
        float alpha = Sample2D(DiffMap, In.TexCoord.xy).a;
        if (alpha < 0.5)
            discard;
    #endif

    #ifdef VSM_SHADOW
        float depth = In.TexCoord.z / In.TexCoord.w;
        Out.Color = float4(depth, depth * depth, 1.0, 1.0);
    #else
        Out.Color = 1.0;
    #endif
}
