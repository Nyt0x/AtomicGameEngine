
#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"

#ifdef COMPILEPS
uniform float4 cShadowAmbient;
#endif

struct VertexIn
{
    float4 Pos : POSITION;
};

struct PixelIn
{
    float2 ScreenPos : TEXCOORD0;
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
    Out.ScreenPos = GetScreenPosPreDiv(Out.Pos);
}

void PS(PixelIn In, out PixelOut Out)
{
    float4 Color;
    float4 diffInput = Sample2D(DiffMap, In.ScreenPos);
    float4 lightInput = Sample2D(EmissiveMap, In.ScreenPos);

    Out.Color = float4(diffInput.rgb * (lightInput.rgb + cShadowAmbient.rgb) * (lightInput.a + cShadowAmbient.a), 1.0);
}
