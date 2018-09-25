#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"

#line 8

#ifndef D3D11

// D3D9 uniforms and samplers
#ifdef COMPILEVS
uniform float2 cDetailTiling;
#else
sampler2D sWeightMap0 : register(s0);
sampler2D sDetailMap1 : register(s1);
sampler2D sDetailMap2 : register(s2);
sampler2D sDetailMap3 : register(s3);
#endif

#else

// D3D11 constant buffers and samplers
#ifdef COMPILEVS
cbuffer CustomVS : register(b6)
{
    float2 cDetailTiling;
}
#else
Texture2D tWeightMap0 : register(t0);
Texture2D tDetailMap1 : register(t1);
Texture2D tDetailMap2 : register(t2);
Texture2D tDetailMap3 : register(t3);
SamplerState sWeightMap0 : register(s0);
SamplerState sDetailMap1 : register(s1);
SamplerState sDetailMap2 : register(s2);
SamplerState sDetailMap3 : register(s3);
#endif

#endif

struct VertexIn
{
    float4 Pos : POSITION;
    float3 Normal : NORMAL;
    float2 TexCoord : TEXCOORD0;
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
#if defined(TRAILFACECAM) || defined(TRAILBONE)
    float4 Tangent : TANGENT;
#endif
};

struct PixelIn
{
    float2 TexCoord : TEXCOORD0;
    float3 Normal : TEXCOORD1;
    float4 WorldPos : TEXCOORD2;
    float2 DetailTexCoord : TEXCOORD3;
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
};

void VS(VertexIn In, out PixelIn Out)
{
    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);
    Out.Normal = GetWorldNormal(modelMatrix);
    Out.WorldPos = float4(worldPos, GetDepth(Out.Pos));
    Out.TexCoord = GetTexCoord(In.TexCoord);
    Out.DetailTexCoord = cDetailTiling * Out.TexCoord;

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
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
        Out.VertexLight = GetAmbient(GetZonePos(worldPos));

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                Out.VertexLight += GetVertexLight(i, worldPos, Out.Normal) * cVertexLights[i * 3].rgb;
        #endif
        
        Out.ScreenPos = GetScreenPos(Out.Pos);
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
    // Get material diffuse albedo
    float3 weights = Sample2D(WeightMap0, In.TexCoord).rgb;
    float sumWeights = weights.r + weights.g + weights.b;
    weights /= sumWeights;
    float4 diffColor = cMatDiffColor * (
        weights.r * Sample2D(DetailMap1, In.DetailTexCoord) +
        weights.g * Sample2D(DetailMap2, In.DetailTexCoord) +
        weights.b * Sample2D(DetailMap3, In.DetailTexCoord)
    );

    // Get material specular albedo
    float3 specColor = cMatSpecColor.rgb;

    // Get normal
    float3 normal = normalize(In.Normal);

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(In.WorldPos.w, In.WorldPos.y);
    #else
        float fogFactor = GetFogFactor(In.WorldPos.w);
    #endif

    #if defined(PERPIXEL)
        // Per-pixel forward lighting
        float3 lightDir;
        float3 lightColor;
        float3 finalColor;
        
        float diff = GetDiffuse(normal, In.WorldPos.xyz, lightDir);

        #ifdef SHADOW
            diff *= GetShadow(In.ShadowPos, In.WorldPos.w);
        #endif
    
        #if defined(SPOTLIGHT)
            lightColor = In.SpotPos.w > 0.0 ? Sample2DProj(LightSpotMap, In.SpotPos).rgb * cLightColor.rgb : 0.0;
        #elif defined(CUBEMASK)
            lightColor = SampleCube(LightCubeMap, In.CubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif
    
        #ifdef SPECULAR
            float spec = GetSpecular(normal, cCameraPosPS - In.WorldPos.xyz, lightDir, cMatSpecColor.a);
            finalColor = diff * lightColor * (diffColor.rgb + spec * specColor * cLightColor.a);
        #else
            finalColor = diff * lightColor * diffColor.rgb;
        #endif

        #ifdef AMBIENT
            finalColor += cAmbientColor.rgb * diffColor.rgb;
            finalColor += cMatEmissiveColor;
            Out.Color = float4(GetFog(finalColor, fogFactor), diffColor.a);
        #else
            Out.Color = float4(GetLitFog(finalColor, fogFactor), diffColor.a);
        #endif
    #elif defined(PREPASS)
        // Fill light pre-pass G-Buffer
        float specPower = cMatSpecColor.a / 255.0;

        Out.Color = float4(normal * 0.5 + 0.5, specPower);
        Out.Depth = In.WorldPos.w;
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        float specIntensity = specColor.g;
        float specPower = cMatSpecColor.a / 255.0;

        float3 finalColor = In.VertexLight * diffColor.rgb;

        Out.Color = float4(GetFog(finalColor, fogFactor), 1.0);
        Out.Albedo = fogFactor * float4(diffColor.rgb, specIntensity);
        Out.Normal = float4(normal * 0.5 + 0.5, specPower);
        Out.Depth = In.WorldPos.w;
    #else
        // Ambient & per-vertex lighting
        float3 finalColor = In.VertexLight * diffColor.rgb;

        #ifdef MATERIAL
            // Add light pre-pass accumulation result
            // Lights are accumulated at half intensity. Bring back to full intensity now
            float4 lightInput = 2.0 * Sample2DProj(LightBuffer, In.ScreenPos);
            float3 lightSpecColor = lightInput.a * (lightInput.rgb / GetIntensity(lightInput.rgb));

            finalColor += lightInput.rgb * diffColor.rgb + lightSpecColor * specColor;
        #endif

        Out.Color = float4(GetFog(finalColor, fogFactor), diffColor.a);
    #endif
}
