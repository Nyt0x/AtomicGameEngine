#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "Fog.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
#ifndef NOUV
    float2 TexCoord : TEXCOORD0;
#endif
#ifdef VERTEXCOLOR
    float4 Color : COLOR0;
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
#if defined(DIRBILLBOARD) || defined(TRAILBONE)
    float3 Normal : NORMAL;
#endif
#if defined(TRAILFACECAM) || defined(TRAILBONE)
    float4 Tangent : TANGENT;
#endif
};

struct PixelIn
{
    float2 TexCoord : TEXCOORD0;
    float4 WorldPos : TEXCOORD2;
#ifdef VERTEXCOLOR
    float4 Color : COLOR0;
#endif
#if defined(D3D11) && defined(CLIPPLANE)
    float Clip : SV_CLIPDISTANCE0;
#endif
    float4 Pos : OUTPOSITION;
};

struct PixelOut
{
#ifdef PREPASS
    float4 Depth : OUTCOLOR1;
#endif
#ifdef DEFERRED
    float4 Albedo : OUTCOLOR1;
    float4 Normal : OUTCOLOR2;
    float4 Depth : OUTCOLOR3;
#endif
    float4 Color : OUTCOLOR0;
}

void VS(VertexIn In, out PixelIn Out)
{
    // Define a 0,0 UV coord if not expected from the vertex data
    #ifdef NOUV
    float2 In.TexCoord = float2(0.0, 0.0);
    #endif

    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);
    Out.TexCoord = GetTexCoord(In.TexCoord);
    Out.WorldPos = float4(worldPos, GetDepth(Out.Pos));

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
    #endif
    
    #ifdef VERTEXCOLOR
        Out.Color = In.Color;
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        float4 diffColor = cMatDiffColor * Sample2D(DiffMap, In.TexCoord);
        #ifdef ALPHAMASK
            if (diffColor.a < 0.5)
                discard;
        #endif
    #else
        float4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
        diffColor *= In.Color;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(In.WorldPos.w, In.WorldPos.y);
    #else
        float fogFactor = GetFogFactor(In.WorldPos.w);
    #endif

    #if defined(PREPASS)
        // Fill light pre-pass G-Buffer
        Out.Color = float4(0.5, 0.5, 0.5, 1.0);
        Out.Depth = In.WorldPos.w;
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        Out.Color = float4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
        Out.Albedo = float4(0.0, 0.0, 0.0, 0.0);
        Out.Normal = float4(0.5, 0.5, 0.5, 1.0);
        Out.Depth = In.WorldPos.w;
    #else
        Out.Color = float4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
    #endif
}
