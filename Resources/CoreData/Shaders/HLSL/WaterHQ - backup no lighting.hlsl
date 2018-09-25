#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Fog.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float2 cNoiseSpeed;
uniform float cNoiseTiling;
uniform float cRefractNoiseStrength;
uniform float cReflectNoiseStrength;
uniform float cFresnelPower;
uniform float cFresnelBias;
uniform float3 cFoamColor;
uniform float cFoamTreshold;
uniform float3 cShallowColor;
uniform float3 cDeepColor;
uniform float cDepthScale;

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
    float cRefractNoiseStrength;
    float cReflectNoiseStrength;
    float cFresnelPower;
    float cFresnelBias;
    float3 cFoamColor;
    float cFoamTreshold;
    float3 cShallowColor;
    float3 cDeepColor;
    float cDepthScale;
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
    //Get reflect and refract UV
    float2 refractUV = In.ScreenPos.xy / In.ScreenPos.w;
    //float2 reflectUV = In.ReflectUV.xy / In.ScreenPos.w;

    //Store refract UV before applying noise
    float2 noiseLessRefractUV = refractUV;

    float3 noise = (Sample2D(SpecMap, In.WaterUV).rgb - 0.5);
    refractUV += noise.rg * cRefractNoiseStrength;

    //Do not shift reflect UV coordinate upward, because it will reveal the clipping of geometry below water
    if (noise.y < 0.0)
        noise.y = 0.0;
    //reflectUV += noise;
    float3 reflectDir = reflect(-In.EyeVec.xyz, In.Normal);
    reflectDir += noise * cReflectNoiseStrength;

    //float2 reflectDirUV = ;

    //Get depth and original depth
    float depth = Sample2DLod0(DepthBuffer, refractUV).r;
    float depthOriginal = Sample2DLod0(DepthBuffer, noiseLessRefractUV).r;

    #ifdef HWDEPTH
    depth = ReconstructDepth(depth);
    depthOriginal = ReconstructDepth(depthOriginal);
    #endif

    //Object above the water reset refracted UV and depth value
    refractUV = lerp(refractUV , noiseLessRefractUV, depth < depthOriginal);
    depth = lerp(depth , depthOriginal, depth < depthOriginal);

    //Calculate water depth
    float3 waterDepth = (depth - In.EyeVec.w) * (cFarClipPS - cNearClipPS);

    //Calculate fresnel component
    half facing = (1.0 - dot(normalize(In.EyeVec.xyz), In.Normal));
    float fresnel = max(cFresnelBias + (1.0 - cFresnelBias) * pow(facing, cFresnelPower), 0.0);

    float steepness = 1.0 - dot(float3(0.0,1.0,0.0), normalize(Sample2D(NormalMap, noiseLessRefractUV).rgb * 2.0 - 1.0));

    float3 refractColor = Sample2D(EnvMap, refractUV).rgb;
    //float3 reflectColor = Sample2D(EnvMap, reflectUV).rgb;   
    float3 reflectColor = SampleCube(DiffCubeMap, reflectDir);   

    float3 waterColor = lerp(cShallowColor, cDeepColor, clamp(waterDepth * cDepthScale, 0.0, 1.0));

    refractColor *= waterColor;

    float3 finalColor = lerp(refractColor, reflectColor, fresnel);

    finalColor = lerp(cFoamColor, finalColor, clamp(saturate((waterDepth + (noise.x * 0.1)) / cFoamTreshold) + steepness, 0.5, 1.0));

    Out.Color = float4(GetFog(finalColor, GetFogFactor(In.EyeVec.w)), 1.0 );
}