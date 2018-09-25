#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "Lighting.hlsl"
#include "ScreenPos.hlsl"
#include "Fog.hlsl"

#if defined(COMPILEPS) && defined(SOFTPARTICLES)
#ifndef D3D11
// D3D9 uniform
uniform float cSoftParticleFadeScale;
#else
// D3D11 constant buffer
cbuffer CustomPS : register(b6)
{
    float cSoftParticleFadeScale;
}
#endif
#endif

struct VertexIn
{
float4 Pos : POSITION;
#if !defined(BILLBOARD) && !defined(TRAILFACECAM)
    float3 Normal : NORMAL;
#endif
#ifndef NOUV
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
#if defined(TRAILFACECAM) || defined(TRAILBONE)
    float4 Tangent : TANGENT;
#endif
};

struct PixelIn
{
    float2 TexCoord : TEXCOORD0;
    #ifdef SOFTPARTICLES
    	float4 ScreenPos : TEXCOORD1;
    #endif
    float4 WorldPos : TEXCOORD3;
#if PERPIXEL
    #ifdef SHADOW
        float4 ShadowPos[NUMCASCADES] : TEXCOORD4;
    #endif
    #ifdef SPOTLIGHT
        float4 SpotPos : TEXCOORD5;
    #endif
    #ifdef POINTLIGHT
        float3 CubeMaskVec : TEXCOORD5;
    #endif
#else
    float3 VertexLight : TEXCOORD4;
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
    // Define a 0,0 UV coord if not expected from the vertex data
    #ifdef NOUV
    float2 In.TexCoord = float2(0.0, 0.0);
    #endif
    
    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);
    Out.TexCoord = GetTexCoord(In.TexCoord);
    Out.WorldPos = float4(worldPos, GetDepth(Out.Pos));

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
    #endif

    #ifdef SOFTPARTICLES
        Out.ScreenPos = GetScreenPos(Out.Pos);
    #endif

    #ifdef VERTEXCOLOR
        Out.Color = In.Color;
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        float4 projWorldPos = float4(worldPos.xyz, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            GetShadowPos(projWorldPos, float3(0, 0, 0), Out.ShadowPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            Out.SpotPos = mul(projWorldPos, cLightMatrices[0]);
        #endif

        #ifdef POINTLIGHT
            Out.CubeMaskVec = mul(worldPos - cLightPos.xyz, (float3x3)cLightMatrices[0]);
        #endif
    #else
        // Ambient & per-vertex lighting
        Out.VertexLight = GetAmbient(GetZonePos(worldPos));

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                Out.VertexLight += GetVertexLightVolumetric(i, worldPos) * cVertexLights[i * 3].rgb;
        #endif
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        float4 diffInput = Sample2D(DiffMap, In.TexCoord);
        #ifdef ALPHAMASK
            if (diffInput.a < 0.5)
                discard;
        #endif
        float4 diffColor = cMatDiffColor * diffInput;
    #else
        float4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
        diffColor *= In.Color;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(In.WorldPos.w, In.WorldPos.y);
    #else
        float fogFactor = GetFogFactor(In.WorldPos.w);
    #endif

    // Soft particle fade
    // In expand mode depth test should be off. In that case do manual alpha discard test first to reduce fill rate
    #ifdef SOFTPARTICLES
        #ifdef EXPAND
            if (diffColor.a < 0.01)
                discard;
        #endif

        float particleDepth = In.WorldPos.w;
        float depth = Sample2DProj(DepthBuffer, In.ScreenPos).r;
        #ifdef HWDEPTH
            depth = ReconstructDepth(depth);
        #endif

        #ifdef EXPAND
            float diffZ = max(particleDepth - depth, 0.0) * (cFarClipPS - cNearClipPS);
            float fade = saturate(diffZ * cSoftParticleFadeScale);
        #else
            float diffZ = (depth - particleDepth) * (cFarClipPS - cNearClipPS);
            float fade = saturate(1.0 - diffZ * cSoftParticleFadeScale);
        #endif

        diffColor.a = max(diffColor.a - fade, 0.0);
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        float3 lightColor;
        float3 finalColor;
        
        float diff = GetDiffuseVolumetric(In.WorldPos.xyz);

        #ifdef SHADOW
            diff *= GetShadow(iShadowPos, In.WorldPos.w);
        #endif

        #if defined(SPOTLIGHT)
            lightColor = In.SpotPos.w > 0.0 ? Sample2DProj(LightSpotMap, In.SpotPos).rgb * cLightColor.rgb : 0.0;
        #elif defined(CUBEMASK)
            lightColor = texCUBE(sLightCubeMap, In.CubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif

        finalColor = diff * lightColor * diffColor.rgb;
        Out.Color = float4(GetLitFog(finalColor, fogFactor), diffColor.a);
    #else
        // Ambient & per-vertex lighting
        float3 finalColor = In.VertexLight * diffColor.rgb;

        Out.Color = float4(GetFog(finalColor, fogFactor), diffColor.a);
    #endif
}
