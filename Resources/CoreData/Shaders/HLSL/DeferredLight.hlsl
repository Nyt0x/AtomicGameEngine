#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"

struct VertexIn
{
    float4 Pos : POSITION;
};

struct PixelIn
{
#ifdef DIRLIGHT
    float2 ScreenPos : TEXCOORD0;
#else
    float4 ScreenPos : TEXCOORD0;
#endif
    float3 FarRay : TEXCOORD1;
#ifdef ORTHO
    float3 NearRay : TEXCOORD2;
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
    #ifdef DIRLIGHT
        Out.ScreenPos = GetScreenPosPreDiv(Out.Pos);
        Out.FarRay = GetFarRay(Out.Pos);
        #ifdef ORTHO
            Out.NearRay = GetNearRay(Out.Pos);
        #endif
    #else
        Out.ScreenPos = GetScreenPos(Out.Pos);
        Out.FarRay = GetFarRay(Out.Pos) * Out.Pos.w;
        #ifdef ORTHO
            Out.NearRay = GetNearRay(Out.Pos) * Out.Pos.w;
        #endif
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
    // If rendering a directional light quad, optimize out the w divide
    #ifdef DIRLIGHT
        float depth = Sample2DLod0(DepthBuffer, In.ScreenPos).r;
        #ifdef HWDEPTH
            depth = ReconstructDepth(depth);
        #endif
        #ifdef ORTHO
            float3 worldPos = lerp(In.NearRay, In.FarRay, depth);
        #else
            float3 worldPos = In.FarRay * depth;
        #endif
        float4 albedoInput = Sample2DLod0(AlbedoBuffer, In.ScreenPos);
        float4 normalInput = Sample2DLod0(NormalBuffer, In.ScreenPos);
    #else
        float depth = Sample2DProj(DepthBuffer, In.ScreenPos).r;
        #ifdef HWDEPTH
            depth = ReconstructDepth(depth);
        #endif
        #ifdef ORTHO
            float3 worldPos = lerp(In.NearRay, In.FarRay, depth) / In.ScreenPos.w;
        #else
            float3 worldPos = In.FarRay * depth / In.ScreenPos.w;
        #endif
        float4 albedoInput = Sample2DProj(AlbedoBuffer, In.ScreenPos);
        float4 normalInput = Sample2DProj(NormalBuffer, In.ScreenPos);
    #endif

    // Position acquired via near/far ray is relative to camera. Bring position to world space
    float3 eyeVec = -worldPos;
    worldPos += cCameraPosPS;

    float3 normal = normalize(normalInput.rgb * 2.0 - 1.0);
    float4 projWorldPos = float4(worldPos, 1.0);
    float3 lightColor;
    float3 lightDir;

    float diff = GetDiffuse(normal, worldPos, lightDir);

    #ifdef SHADOW
        diff *= GetShadowDeferred(projWorldPos, normal, depth);
    #endif

    #if defined(SPOTLIGHT)
        float4 spotPos = mul(projWorldPos, cLightMatricesPS[0]);
        lightColor = spotPos.w > 0.0 ? Sample2DProj(LightSpotMap, spotPos).rgb * cLightColor.rgb : 0.0;
    #elif defined(CUBEMASK)
        lightColor = texCUBE(sLightCubeMap, mul(worldPos - cLightPosPS.xyz, (float3x3)cLightMatricesPS[0])).rgb * cLightColor.rgb;
    #else
        lightColor = cLightColor.rgb;
    #endif

    #ifdef SPECULAR
        float spec = GetSpecular(normal, eyeVec, lightDir, normalInput.a * 255.0);
        Out.Color = diff * float4(lightColor * (albedoInput.rgb + spec * cLightColor.a * albedoInput.aaa), 0.0);
    #else
        Out.Color = diff * float4(lightColor * albedoInput.rgb, 0.0);
    #endif
}
