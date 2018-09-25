#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

uniform float2 cBlurDir;
uniform float cBlurRadius;
uniform float cBlurSigma;
uniform float2 cBlurHOffsets;
uniform float2 cBlurHInvSize;

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
    Out.TexCoord = GetQuadTexCoord(Out.Pos) + cBlurHOffsets;
    Out.ScreenPos = GetScreenPosPreDiv(Out.Pos);
}

void PS(PixelIn In, out PixelOut Out)
{
    #ifdef BLUR3
        #ifndef D3D11 
            Out.Color = GaussianBlur(3, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, sDiffMap, In.TexCoord);
        #else
            Out.Color = GaussianBlur(3, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
        #endif
    #endif

    #ifdef BLUR5
        #ifndef D3D11
            Out.Color = GaussianBlur(5, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, sDiffMap, In.TexCoord);
        #else
            Out.Color = GaussianBlur(5, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
        #endif
    #endif

    #ifdef BLUR7
        #ifndef D3D11
            Out.Color = GaussianBlur(7, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, sDiffMap, In.TexCoord);
        #else
            Out.Color = GaussianBlur(7, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
        #endif
    #endif

    #ifdef BLUR9
        #ifndef D3D11
            Out.Color = GaussianBlur(9, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, sDiffMap, In.TexCoord);
        #else
            Out.Color = GaussianBlur(9, cBlurDir, cBlurHInvSize * cBlurRadius, cBlurSigma, tDiffMap, sDiffMap, In.TexCoord);
        #endif
    #endif
}
