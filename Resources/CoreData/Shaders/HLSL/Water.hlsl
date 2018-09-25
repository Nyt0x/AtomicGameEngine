#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Fog.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float2 cNoiseSpeed;
uniform float cNoiseTiling;
uniform float cNoiseStrength;
uniform float cFresnelPower;
uniform float3 cWaterTint;

#else

// D3D11 constant buffers
#ifdef COMPILEVS
cbuffer CustomVS : register(b6)
{
    float2 cNoiseSpeed;
    float cNoiseTiling;
}
#else
cbuffer CustomPS : register(b6)
{
    float cNoiseStrength;
    float cFresnelPower;
    float3 cWaterTint;
}
#endif

#endif

struct VertexIn
{
    float4 Pos : POSITION;
    float3 Normal: NORMAL;
    float2 TexCoord : TEXCOORD0;
    #ifdef INSTANCED
        float4x3 ModelInstance : TEXCOORD4;
    #endif
};

struct PixelIn
{
    float4 ScreenPos : TEXCOORD0;
    float2 ReflectUV : TEXCOORD1;
    float2 WaterUV : TEXCOORD2;
    float3 Normal : TEXCOORD3;
    float4 EyeVec : TEXCOORD4;
    #if defined(D3D11) && defined(CLIPPLANE)
        float Clip : SV_CLIPDISTANCE0;
    #endif
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

    Out.ScreenPos = GetScreenPos(Out.Pos);
    // GetQuadTexCoord() returns a float2 that is OK for quad rendering; multiply it with output W
    // coordinate to make it work with arbitrary meshes such as the water plane (perform divide in pixel shader)
    Out.ReflectUV = GetQuadTexCoord(Out.Pos) * Out.Pos.w;
    Out.WaterUV = In.TexCoord * cNoiseTiling + cElapsedTime * cNoiseSpeed;
    Out.Normal = GetWorldNormal(modelMatrix);
    Out.EyeVec = float4(cCameraPos - worldPos, GetDepth(Out.Pos));

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
    float2 refractUV = In.ScreenPos.xy / In.ScreenPos.w;
    float2 reflectUV = In.ReflectUV.xy / In.ScreenPos.w;

    float2 noise = (Sample2D(NormalMap, In.WaterUV).rg - 0.5) * cNoiseStrength;
    refractUV += noise;
    // Do not shift reflect UV coordinate upward, because it will reveal the clipping of geometry below water
    if (noise.y < 0.0)
        noise.y = 0.0;
    reflectUV += noise;

    float fresnel = pow(1.0 - saturate(dot(normalize(In.EyeVec.xyz), In.Normal)), cFresnelPower);
    float3 refractColor = Sample2D(EnvMap, refractUV).rgb * cWaterTint;
    float3 reflectColor = Sample2D(DiffMap, reflectUV).rgb;
    float3 finalColor = lerp(refractColor, reflectColor, fresnel);

    Out.Color = float4(GetFog(finalColor, GetFogFactor(In.EyeVec.w)), 1.0);
}