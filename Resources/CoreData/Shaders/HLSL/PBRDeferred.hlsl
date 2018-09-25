#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Constants.hlsl"
#include "PBR.hlsl"
#line 9

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

void PS(PixelIn In,
    float2 iFragPos : VPOS,
    out PixelOut Out
    )
{
    // If rendering a directional light quad, optimize out the w divide
    #ifdef DIRLIGHT
        float3 depth = Sample2DLod0(DepthBuffer, In.ScreenPos).r;
        #ifdef HWDEPTH
            depth = ReconstructDepth(depth);
        #endif
        #ifdef ORTHO
            float3 worldPos = lerp(In.NearRay, In.FarRay, depth);
        #else
            float3 worldPos = In.FarRay * depth;
        #endif
        const float4 albedoInput = Sample2DLod0(AlbedoBuffer, In.ScreenPos);
        const float4 normalInput = Sample2DLod0(NormalBuffer, In.ScreenPos);
        const float4 specularInput = Sample2DLod0(SpecMap, In.ScreenPos);
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
        const float4 albedoInput = Sample2DProj(AlbedoBuffer, In.ScreenPos);
        const float4 normalInput = Sample2DProj(NormalBuffer, In.ScreenPos);
        const float4 specularInput = Sample2DProj(SpecMap, In.ScreenPos);
    #endif

    // Position acquired via near/far ray is relative to camera. Bring position to world space
    float3 eyeVec = -worldPos;
    worldPos += cCameraPosPS;

    float3 normal = normalInput.rgb;
    const float roughness = length(normal);
    normal = normalize(normal);

    const float3 specColor = specularInput.rgb;

    const float4 projWorldPos = float4(worldPos, 1.0);

    float3 lightDir;
     float atten = 1;

        #if defined(DIRLIGHT)
            atten = GetAtten(normal, worldPos, lightDir);
        #elif defined(SPOTLIGHT)
            atten = GetAttenSpot(normal, worldPos, lightDir);
        #else
            atten = GetAttenPoint(normal, worldPos, lightDir);
        #endif

    float shadow = 1;
    #ifdef SHADOW
        shadow *= GetShadowDeferred(projWorldPos, normal, depth);
    #endif

    #if defined(SPOTLIGHT)
        const float4 spotPos = mul(projWorldPos, cLightMatricesPS[0]);
        const float3 lightColor = spotPos.w > 0.0 ? Sample2DProj(LightSpotMap, spotPos).rgb * cLightColor.rgb : 0.0;
    #elif defined(CUBEMASK)
        const float3 lightColor = texCUBE(sLightCubeMap, mul(worldPos - cLightPosPS.xyz, (float3x3)cLightMatricesPS[0])).rgb * cLightColor.rgb;
    #else
        const float3 lightColor = cLightColor.rgb;
    #endif

    const float3 toCamera = normalize(eyeVec);
    const float3 lightVec = normalize(lightDir);
    const float ndl = clamp(abs(dot(normal, lightVec)), M_EPSILON, 1.0);

    float3 BRDF = GetBRDF(worldPos, lightDir, lightVec, toCamera, normal, roughness, albedoInput.rgb, specColor);

    Out.Color = float4(BRDF * lightColor * shadow * atten / M_PI, 1.0);
}
