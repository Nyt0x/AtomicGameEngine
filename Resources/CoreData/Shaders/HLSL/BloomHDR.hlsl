#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float cBloomHDRThreshold;
uniform float2 cBloomHDRBlurDir;
uniform float cBloomHDRBlurRadius;
uniform float cBloomHDRBlurSigma;
uniform float2 cBloomHDRMix;
uniform float2 cBright2Offsets;
uniform float2 cBright4Offsets;
uniform float2 cBright8Offsets;
uniform float2 cBright16Offsets;
uniform float2 cBright2InvSize;
uniform float2 cBright4InvSize;
uniform float2 cBright8InvSize;
uniform float2 cBright16InvSize;

#else

// D3D11 constant buffers
#ifdef COMPILEVS
cbuffer CustomVS : register(b6)
{
    float2 cBright2Offsets;
    float2 cBright4Offsets;
    float2 cBright8Offsets;
    float2 cBright16Offsets;
}
#else
cbuffer CustomPS : register(b6)
{
    float cBloomHDRThreshold;
    float2 cBloomHDRBlurDir;
    float cBloomHDRBlurRadius;
    float cBloomHDRBlurSigma;
    float2 cBloomHDRMix;
    float2 cBright2InvSize;
    float2 cBright4InvSize;
    float2 cBright8InvSize;
    float2 cBright16InvSize;
}
#endif

#endif

static const int BlurKernelSize = 5;

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

    #ifdef BLUR2
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright2Offsets;
    #endif

    #ifdef BLUR4
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright4Offsets;
    #endif

    #ifdef BLUR8
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright8Offsets;
    #endif

    #ifdef BLUR16
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright16Offsets;
    #endif

    #ifdef COMBINE2
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright2Offsets;
    #endif

    #ifdef COMBINE4
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright4Offsets;
    #endif

    #ifdef COMBINE8
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright8Offsets;
    #endif

    #ifdef COMBINE16
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBright16Offsets;
    #endif

    Out.ScreenPos = GetScreenPosPreDiv(Out.Pos);
}

void PS(PixelIn In, out PixelOut Out)
{
    #ifdef BRIGHT
    float3 color = Sample2D(DiffMap, In.ScreenPos).rgb;
    Out.Color = float4(max(color - cBloomHDRThreshold, 0.0), 1.0);
    #endif

    #ifndef D3D11

    #ifdef BLUR16
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright16InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, sDiffMap, In.TexCoord);
    #endif

    #ifdef BLUR8
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright8InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, sDiffMap, In.TexCoord);
    #endif

    #ifdef BLUR4
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright4InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, sDiffMap, In.TexCoord);
    #endif

    #ifdef BLUR2
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright2InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, sDiffMap, In.TexCoord);
    #endif
    
    #else

    #ifdef BLUR16
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright16InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
    #endif

    #ifdef BLUR8
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright8InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
    #endif

    #ifdef BLUR4
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright4InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
    #endif

    #ifdef BLUR2
    Out.Color = GaussianBlur(BlurKernelSize, cBloomHDRBlurDir, cBright2InvSize * cBloomHDRBlurRadius, cBloomHDRBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
    #endif
    
    #endif

    #ifdef COMBINE16
    Out.Color = Sample2D(DiffMap, In.ScreenPos) + Sample2D(NormalMap, In.TexCoord);
    #endif

    #ifdef COMBINE8
    Out.Color = Sample2D(DiffMap, In.ScreenPos) + Sample2D(NormalMap, In.TexCoord);
    #endif

    #ifdef COMBINE4
    Out.Color = Sample2D(DiffMap, In.ScreenPos) + Sample2D(NormalMap, In.TexCoord);
    #endif

    #ifdef COMBINE2
    float3 color = Sample2D(DiffMap, In.ScreenPos).rgb * cBloomHDRMix.x;
    float3 bloom = Sample2D(NormalMap, In.TexCoord).rgb * cBloomHDRMix.y;
    Out.Color = float4(color + bloom, 1.0);
    #endif
}
