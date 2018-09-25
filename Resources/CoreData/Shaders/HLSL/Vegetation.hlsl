#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float cWindHeightFactor;
uniform float cWindHeightPivot;
uniform float cWindPeriod;
uniform float2 cWindWorldSpacing;

#else

// D3D11 constant buffer
cbuffer CustomVS : register(b6)
{
    float cWindHeightFactor;
    float cWindHeightPivot;
    float cWindPeriod;
    float2 cWindWorldSpacing;
}

#endif

struct VertexIn
{
float4 Pos : POSITION;
#if !defined(BILLBOARD) && !defined(TRAILFACECAM)
    float3 Normal : NORMAL;
#endif
#ifndef NOUV
    float2 TexCoord : TEXCOORD0;
#endif
#ifdef VERTEXCOLOR
    float4 Color : COLOR0;
#endif
#if defined(LIGHTMAP) || defined(AO)
    float2 TexCoord2 : TEXCOORD1;
#endif
#if (defined(NORMALMAP) || defined(TRAILFACECAM) || defined(TRAILBONE)) && !defined(BILLBOARD) && !defined(DIRBILLBOARD)
    float4 Tangent : TANGENT;
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
#ifndef NORMALMAP
    float2 TexCoord : TEXCOORD0;
#else
    float4 TexCoord : TEXCOORD0;
    float4 Tangent : TEXCOORD3;
#endif
float3 Normal : TEXCOORD1;
float4 WorldPos : TEXCOORD2;
#ifdef PERPIXEL
    #ifdef SHADOW
        float4 ShadowPos[NUMCASCADES] : TEXCOORD4;
    #endif
    #ifdef SPOTLIGHT
        float4 SpotPos : TEXCOORD5;
    #endif
    #ifdef POINTLIGHT
        float3 CubeMaskVec : TEXCOORD5;
    #endif
#else
    float3 VertexLight : TEXCOORD4;
    float4 ScreenPos : TEXCOORD5;
    #ifdef ENVCUBEMAP
        float3 ReflectionVec : TEXCOORD6;
    #endif
    #if defined(LIGHTMAP) || defined(AO)
        float2 TexCoord2 : TEXCOORD7;
    #endif
#endif
#ifdef VERTEXCOLOR
    float4 Color : COLOR0;
#endif
#if defined(D3D11) && defined(CLIPPLANE)
    float Clip : SV_CLIPDISTANCE0;
#endif
float4 Pos : OUTPOSITION;
};

void VS(VertexIn In, out PixelIn Out)
{
    // Define a 0,0 UV coord if not expected from the vertex data
    #ifdef NOUV
    float2 In.TexCoord = float2(0.0, 0.0);
    #endif

    float4x3 modelMatrix = In.ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    float height = worldPos.y - modelMatrix._m31;

    float windStrength = max(height - cWindHeightPivot, 0.0) * cWindHeightFactor;
    float windPeriod = cElapsedTime * cWindPeriod + dot(worldPos.xz, cWindWorldSpacing);
    worldPos.x += windStrength * sin(windPeriod);
    worldPos.z -= windStrength * cos(windPeriod);

    Out.Pos = GetClipPos(worldPos);
    Out.Normal = GetWorldNormal(modelMatrix);
    Out.WorldPos = float4(worldPos, GetDepth(Out.Pos));

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
    #endif

    #ifdef VERTEXCOLOR
        Out.Color = In.Color;
    #endif

    #ifdef NORMALMAP
        float4 tangent = GetWorldTangent(modelMatrix);
        float3 bitangent = cross(tangent.xyz, Out.Normal) * tangent.w;
        Out.TexCoord = float4(GetTexCoord(In.TexCoord), bitangent.xy);
        Out.Tangent = float4(tangent.xyz, bitangent.z);
    #else
        OutTexCoord = GetTexCoord(In.TexCoord);
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        float4 projWorldPos = float4(worldPos.xyz, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            GetShadowPos(projWorldPos, Out.Normal, Out.ShadowPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            Out.SpotPos = mul(projWorldPos, cLightMatrices[0]);
        #endif

        #ifdef POINTLIGHT
            Out.CubeMaskVec = mul(worldPos - cLightPos.xyz, (float3x3)cLightMatrices[0]);
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || defined(AO)
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
            Out.VertexLight = float3(0.0, 0.0, 0.0);
            Out.TexCoord2 = In.TexCoord2;
        #else
            Out.VertexLight = GetAmbient(GetZonePos(worldPos));
        #endif

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                Out.VertexLight += GetVertexLight(i, worldPos, Out.Normal) * cVertexLights[i * 3].rgb;
        #endif

        Out.ScreenPos = GetScreenPos(Out.Pos);

        #ifdef ENVCUBEMAP
            Out.ReflectionVec = worldPos - cCameraPos;
        #endif
    #endif
}
