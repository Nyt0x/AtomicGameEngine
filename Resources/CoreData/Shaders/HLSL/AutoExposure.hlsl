#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

uniform float cAutoExposureAdaptRate;
uniform float2 cAutoExposureLumRange;
uniform float cAutoExposureMiddleGrey;
uniform float2 cHDR128Offsets;
uniform float2 cLum64Offsets;
uniform float2 cLum16Offsets;
uniform float2 cLum4Offsets;
uniform float2 cHDR128InvSize;
uniform float2 cLum64InvSize;
uniform float2 cLum16InvSize;
uniform float2 cLum4InvSize;

#ifndef D3D11
float GatherAvgLum(sampler2D texSampler, float2 texCoord, float2 texelSize)
#else
float GatherAvgLum(Texture2D tex, SamplerState texSampler, float2 texCoord, float2 texelSize)
#endif
{
    float lumAvg = 0.0;
    #ifndef D3D11
    lumAvg += tex2D(texSampler, texCoord + float2(0.0, 0.0) * texelSize).r;
    lumAvg += tex2D(texSampler, texCoord + float2(0.0, 2.0) * texelSize).r;
    lumAvg += tex2D(texSampler, texCoord + float2(2.0, 2.0) * texelSize).r;
    lumAvg += tex2D(texSampler, texCoord + float2(2.0, 0.0) * texelSize).r;
    #else
    lumAvg += tex.Sample(texSampler, texCoord + float2(0.0, 0.0) * texelSize).r;
    lumAvg += tex.Sample(texSampler, texCoord + float2(0.0, 2.0) * texelSize).r;
    lumAvg += tex.Sample(texSampler, texCoord + float2(2.0, 2.0) * texelSize).r;
    lumAvg += tex.Sample(texSampler, texCoord + float2(2.0, 0.0) * texelSize).r;
    #endif
    return lumAvg / 4.0;
}

struct VertexIn
{
    float4 Pos : POSITION;
};

struct PixelIn
{
    float2 TexCoord : TEXCOORD0;
    float2 ScreenPos : TEXCOORD1;
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

    Out.TexCoord = GetQuadTexCoord(Out.Pos);

    #ifdef LUMINANCE64
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cHDR128Offsets;
    #endif

    #ifdef LUMINANCE16
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cLum64Offsets;
    #endif

    #ifdef LUMINANCE4
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cLum16Offsets;
    #endif

    #ifdef LUMINANCE1
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cLum4Offsets;
    #endif

    Out.ScreenPos = GetScreenPosPreDiv(Out.Pos);
}

void PS(PixelIn In, out PixelOut Out)
{
    #ifdef LUMINANCE64
    float logLumSum = 0.0;
    logLumSum += log(dot(Sample2D(DiffMap, In.TexCoord + float2(0.0, 0.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    logLumSum += log(dot(Sample2D(DiffMap, In.TexCoord + float2(0.0, 2.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    logLumSum += log(dot(Sample2D(DiffMap, In.TexCoord + float2(2.0, 2.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    logLumSum += log(dot(Sample2D(DiffMap, In.TexCoord + float2(2.0, 0.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    Out.Color = logLumSum;
    #endif

    #ifdef LUMINANCE16
    #ifndef D3D11
    Out.Color = GatherAvgLum(sDiffMap, In.TexCoord, cLum64InvSize);
    #else
    Out.Color = GatherAvgLum(tDiffMap, sDiffMap, In.TexCoord, cLum64InvSize);
    #endif
    #endif

    #ifdef LUMINANCE4
    #ifndef D3D11
    Out.Color = GatherAvgLum(sDiffMap, In.TexCoord, cLum16InvSize);
    #else
    Out.Color = GatherAvgLum(tDiffMap, sDiffMap, In.TexCoord, cLum16InvSize);
    #endif
    #endif

    #ifdef LUMINANCE1
    #ifndef D3D11
    Out.Color = exp(GatherAvgLum(sDiffMap, In.TexCoord, cLum4InvSize) / 16.0);
    #else
    Out.Color = exp(GatherAvgLum(tDiffMap, sDiffMap, In.TexCoord, cLum4InvSize) / 16.0);
    #endif
    #endif

    #ifdef ADAPTLUMINANCE
    float adaptedLum = Sample2D(DiffMap, In.TexCoord).r;
    float lum = clamp(Sample2D(NormalMap, In.TexCoord).r, cAutoExposureLumRange.x, cAutoExposureLumRange.y);
    Out.Color = adaptedLum + (lum - adaptedLum) * (1.0 - exp(-cDeltaTimePS * cAutoExposureAdaptRate));
    #endif

    #ifdef EXPOSE
    float3 color = Sample2D(DiffMap, In.ScreenPos).rgb;
    float adaptedLum = Sample2D(NormalMap, In.TexCoord).r;
    Out.Color = float4(color * (cAutoExposureMiddleGrey / adaptedLum), 1.0);
    #endif
}
