#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

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
#ifndef NOUV
    float2 TexCoord : TEXCOORD0;
#endif
};

struct PixelIn
{
    float3 TexCoord : TEXCOORD0;
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
    Out.TexCoord = float3(GetTexCoord(In.TexCoord), GetDepth(Out.Pos));
}

void PS(PixelIn In, out PixelOut Out)
{
    #ifdef ALPHAMASK
        float alpha = Sample2D(sDiffMap, In.TexCoord.xy).a;
        if (alpha < 0.5)
            discard;
    #endif

    Out.Color = In.TexCoord.z;
}
