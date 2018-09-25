#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
#ifdef DIFFMAP
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
#ifdef DIFFMAP
    float2 TexCoord : TEXCOORD0;
#endif
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
    float4 Color : OUTCOLOR0;
};

void VS(VertexIn In, out PixelIn Out)
{
    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
    #endif

    #ifdef VERTEXCOLOR
        Out.Color = In.Color;
    #endif
    #ifdef DIFFMAP
        Out.TexCoord = In.TexCoord;
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
    float4 diffColor = cMatDiffColor;

    #ifdef VERTEXCOLOR
        diffColor *= In.Color;
    #endif

    #if (!defined(DIFFMAP)) && (!defined(ALPHAMAP))
        Out.Color = diffColor;
    #endif
    #ifdef DIFFMAP
        float4 diffInput = Sample2D(DiffMap, In.TexCoord);
        #ifdef ALPHAMASK
            if (diffInput.a < 0.5)
                discard;
        #endif
        Out.Color = diffColor * diffInput;
    #endif
    #ifdef ALPHAMAP
        float alphaInput = Sample2D(DiffMap, In.TexCoord).a;
        Out.Color = float4(diffColor.rgb, diffColor.a * alphaInput);
    #endif
}
