#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
#ifdef INSTANCED
    float4x3 ModelInstance : TEXCOORD4;
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
    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);

    Out.Pos.z = Out.Pos.w;
    Out.TexCoord = In.Pos.xyz;
}

void PS(PixelIn In, out PixelOut Out)
{
    float4 sky = cMatDiffColor * SampleCube(DiffCubeMap, In.TexCoord);
    #ifdef HDRSCALE
        sky = pow(sky + clamp((cAmbientColor.a - 1.0) * 0.1, 0.0, 0.25), max(cAmbientColor.a, 1.0)) * clamp(cAmbientColor.a, 0.0, 1.0);
    #endif
    Out.Color = sky;
}
