#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Constants.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"
#include "PBR.hlsl"
#include "IBL.hlsl"

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
#if defined(LIGHTMAP) || defined(AO)
    float2 TexCoord2 : TEXCOORD1;
#endif
    #if (defined(NORMALMAP)|| defined(IBL) || defined(TRAILFACECAM) || defined(TRAILBONE)) && !defined(BILLBOARD) && !defined(DIRBILLBOARD)
    float4 Tangent : TANGENT;
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
};

struct PixelIn
{
#if defined(NORMALMAP) || defined(IBL)
    float4 TexCoord : TEXCOORD0;
    float4 Tangent : TEXCOORD3;
#else
    float2 TexCoord : TEXCOORD0;
#endif
    float3 Normal : TEXCOORD1;
    float4 WorldPos : TEXCOORD2;
#ifdef PERPIXEL
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
    float4 ScreenPos : TEXCOORD5;
    #ifdef ENVCUBEMAP
        float3 ReflectionVec : TEXCOORD6;
    #endif
    #if defined(LIGHTMAP) || defined(AO)
        float2 TexCoord2 : TEXCOORD7;
    #endif
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
#ifdef PREPASS
    float4 Depth : OUTCOLOR1;
#endif
#ifdef DEFERRED
    float4 Albedo : OUTCOLOR1;
    float4 Normal : OUTCOLOR2;
    float4 Depth : OUTCOLOR3;
#endif
    float4 Color : OUTCOLOR0;
};

void VS(VertexIn In, out PixelIn Out)
{
    // Define a 0,0 UV coord if not expected from the vertex data
    #ifdef NOUV
        const float2 In.TexCoord = float2(0.0, 0.0);
    #endif

    const float4x3 modelMatrix = ModelMatrix;
    const float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);
    Out.Normal = GetWorldNormal(modelMatrix);
    Out.WorldPos = float4(worldPos, GetDepth(Out.Pos));

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
    #endif

    #ifdef VERTEXCOLOR
        Out.Color = In.Color;
    #endif

    #if defined(NORMALMAP) || defined(IBL)
        const float4 tangent = GetWorldTangent(modelMatrix);
        const float3 bitangent = cross(tangent.xyz, Out.Normal) * In.Tangent.w;
        Out.TexCoord = float4(GetTexCoord(iTexCoord), bitangent.xy);
        Out.Tangent = float4(tangent.xyz, bitangent.z);
    #else
        Out.TexCoord = GetTexCoord(In.TexCoord);
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        const float4 projWorldPos = float4(worldPos.xyz, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            GetShadowPos(projWorldPos, Out.Normal, Out.ShadowPos);
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
        #if defined(LIGHTMAP) || defined(AO)
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
            Out.VertexLight = float3(0.0, 0.0, 0.0);
            Out.TexCoord2 = In.TexCoord2;
        #else
            Out.VertexLight = GetAmbient(GetZonePos(worldPos));
        #endif

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                Out.VertexLight += GetVertexLight(i, worldPos, Out.Normal) * cVertexLights[i * 3].rgb;
        #endif

        Out.ScreenPos = GetScreenPos(Out.Pos);

        #ifdef ENVCUBEMAP
            Out.ReflectionVec = worldPos - cCameraPos;
        #endif
    #endif
}

void PS(PixelIn In,
    #ifdef DEFERRED
        #ifndef D3D11
            float2 iFragPos : VPOS,
        #else
            float4 iFragPos : SV_Position,
        #endif
    #endif
    out PixelOut Out)
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        const float4 diffInput = Sample2D(DiffMap, In.TexCoord.xy);
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

    // Get material specular albedo
    #ifdef METALLIC // METALNESS
        float4 roughMetalSrc = Sample2D(RoughMetalFresnel, In.TexCoord.xy);

        float roughness = roughMetalSrc.r + cRoughness;
        float metalness = roughMetalSrc.g + cMetallic;
    #else
        float roughness = cRoughness;
        float metalness = cMetallic;
    #endif

    roughness *= roughness;

    roughness = clamp(roughness, ROUGHNESS_FLOOR, 1.0);
    metalness = clamp(metalness, METALNESS_FLOOR, 1.0);

    float3 specColor = lerp(0.08 * cMatSpecColor.rgb, diffColor.rgb, metalness);
    specColor *= cMatSpecColor.rgb;
    diffColor.rgb = diffColor.rgb - diffColor.rgb * metalness; // Modulate down the diffuse

    // Get normal
    #if defined(NORMALMAP) || defined(IBL)
        const float3 tangent = normalize(In.Tangent.xyz);
        const float3 bitangent = normalize(float3(In.TexCoord.zw, In.Tangent.w));
        const float3x3 tbn = float3x3(tangent, bitangent, In.Normal);
    #endif

    #ifdef NORMALMAP
        const float3 nn = DecodeNormal(Sample2D(NormalMap, In.TexCoord.xy));
        //nn.rg *= 2.0;
        const float3 normal = normalize(mul(nn, tbn));
    #else
        const float3 normal = normalize(In.Normal);
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        const float fogFactor = GetHeightFogFactor(In.WorldPos.w, In.WorldPos.y);
    #else
        const float fogFactor = GetFogFactor(In.WorldPos.w);
    #endif

    #if defined(PERPIXEL)
        // Per-pixel forward lighting
        float3 lightDir;
        float3 lightColor;
        float3 finalColor;
        float atten = 1;

        #if defined(DIRLIGHT)
        atten = GetAtten(normal, In.WorldPos.xyz, lightDir);
        #elif defined(SPOTLIGHT)
            atten = GetAttenSpot(normal, In.WorldPos.xyz, lightDir);
        #else
            atten = GetAttenPoint(normal, In.WorldPos.xyz, lightDir);
        #endif

        float shadow = 1.0;

        #ifdef SHADOW
            shadow *= GetShadow(In.ShadowPos, In.WorldPos.w);
        #endif

        #if defined(SPOTLIGHT)
            lightColor = In.SpotPos.w > 0.0 ? Sample2DProj(LightSpotMap, In.SpotPos).rgb * cLightColor.rgb : 0.0;
        #elif defined(CUBEMASK)
            lightColor = SampleCube(LightCubeMap, In.CubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif

        const float3 toCamera = normalize(cCameraPosPS - In.WorldPos.xyz);

        const float3 lightVec = normalize(lightDir);
        const float ndl = clamp((dot(normal, lightVec)), M_EPSILON, 1.0);


        float3 BRDF = GetBRDF(In.WorldPos.xyz, lightDir, lightVec, toCamera, normal, roughness, diffColor.rgb, specColor);
        finalColor.rgb = BRDF * lightColor * (atten * shadow) / M_PI;

        #ifdef AMBIENT
            finalColor += cAmbientColor.rgb * diffColor.rgb;
            finalColor += cMatEmissiveColor;
            Out.Color = float4(GetFog(finalColor, fogFactor), diffColor.a);
        #else
            Out.Color = float4(GetLitFog(finalColor, fogFactor), diffColor.a);
        #endif
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        const float3 spareData = 0; // Can be used to pass more data to deferred renderer
        Out.Color = float4(specColor, spareData.r);
        Out.Albedo = float4(diffColor.rgb, spareData.g);
        Out.Normal = float4(normalize(normal) * roughness, spareData.b);
        Out.Depth = In.WorldPos.w;
    #else
        // Ambient & per-vertex lighting
        float3 finalColor = In.VertexLight * diffColor.rgb;
        #ifdef AO
            // If using AO, the vertex light ambient is black, calculate occluded ambient here
            finalColor += Sample2D(EmissiveMap, In.TexCoord2).rgb * cAmbientColor.rgb * diffColor.rgb;
        #endif

        #ifdef MATERIAL
            // Add light pre-pass accumulation result
            // Lights are accumulated at half intensity. Bring back to full intensity now
            float4 lightInput = 2.0 * Sample2DProj(LightBuffer, In.ScreenPos);
            float3 lightSpecColor = lightInput.a * lightInput.rgb / max(GetIntensity(lightInput.rgb), 0.001);

            finalColor += lightInput.rgb * diffColor.rgb + lightSpecColor * specColor;
        #endif

        const float3 toCamera = normalize(In.WorldPos.xyz - cCameraPosPS);

        const float3 reflection = normalize(reflect(toCamera, normal));
        float3 cubeColor = In.VertexLight.rgb;

        #ifdef IBL
            const float3 iblColor = ImageBasedLighting(reflection, tangent, bitangent, normal, toCamera, diffColor, specColor, roughness, cubeColor);
            const float gamma = 0;
            finalColor += iblColor;
        #endif

        #ifdef ENVCUBEMAP
            finalColor += cMatEnvMapColor * SampleCube(EnvCubeMap, reflect(In.ReflectionVec, normal)).rgb;
        #endif
        #ifdef LIGHTMAP
            finalColor += Sample2D(EmissiveMap, In.TexCoord2).rgb * diffColor.rgb;
        #endif
        #ifdef EMISSIVEMAP
            finalColor += cMatEmissiveColor * Sample2D(EmissiveMap, In.TexCoord.xy).rgb;
        #else
            finalColor += cMatEmissiveColor;
        #endif

        Out.Color = float4(GetFog(finalColor, fogFactor), diffColor.a);
    #endif
}
