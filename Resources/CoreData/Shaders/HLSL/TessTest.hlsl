
#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"


#line 10

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
#if (defined(NORMALMAP) || defined(TRAILFACECAM) || defined(TRAILBONE)) && !defined(BILLBOARD) && !defined(DIRBILLBOARD)
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

struct HullIn
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
#if (defined(NORMALMAP) || defined(TRAILFACECAM) || defined(TRAILBONE)) && !defined(BILLBOARD) && !defined(DIRBILLBOARD)
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

struct DomainIn
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
#if (defined(NORMALMAP) || defined(TRAILFACECAM) || defined(TRAILBONE)) && !defined(BILLBOARD) && !defined(DIRBILLBOARD)
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
#ifndef NORMALMAP
    float2 TexCoord : TEXCOORD0;
#else
    float4 TexCoord : TEXCOORD0;
    float4 Tangent : TEXCOORD3;
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

    float3 Barycentric: TEXCOORD8;
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

struct ConstantOutputType
{
    float edges[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

#ifdef COMPILEVS
void VS(VertexIn In, out HullIn Out)
{
    // Pass the vertex position into the hull shader.
    Out.Pos = In.Pos;
#if !defined(BILLBOARD) && !defined(TRAILFACECAM)
    Out.Normal = In.Normal;
#endif
#ifndef NOUV
    Out.TexCoord = In.TexCoord;
#endif
#ifdef VERTEXCOLOR
    Out.Color = In.Color;
#endif
#if defined(LIGHTMAP) || defined(AO)
    Out.TexCoord2 = In.TexCoord2;
#endif
#if defined(NORMALMAP) || defined(TRAILFACECAM) || defined(TRAILBONE)
    Out.Tangent = In.Tangent;
#endif
#ifdef SKINNED
    Out.BlendWeights = In.BlendWeights;
    Out.BlendIndices = In.BlendIndices;
#endif
#ifdef INSTANCED
    Out.ModelInstance = In.ModelInstance;
#endif
#if defined(BILLBOARD) || defined(DIRBILLBOARD)
    Out.Size = In.Size;
#endif
}
#endif

#ifdef COMPILEHS
ConstantOutputType PatchConstantFunction(InputPatch<HullIn, 3> inputPatch, uint patchId : SV_PrimitiveID)
{    
    ConstantOutputType output;


    // Set the tessellation factors for the three edges of the triangle.
    output.edges[0] = cTessellationAmount;
    output.edges[1] = cTessellationAmount;
    output.edges[2] = cTessellationAmount;

    // Set the tessellation factor for tessallating inside the triangle.
    output.inside = cTessellationAmount;

    return output;
}

[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("PatchConstantFunction")]
DomainIn HS(InputPatch<HullIn, 3> patch, uint pointId : SV_OutputControlPointID, uint patchId : SV_PrimitiveID)
{
    DomainIn Out;

    // Set the position for this control point as the output position.
    Out.Pos = patch[pointId].Pos;
#if !defined(BILLBOARD) && !defined(TRAILFACECAM)
    Out.Normal = patch[pointId].Normal;
#endif
#ifndef NOUV
    Out.TexCoord = patch[pointId].TexCoord;
#endif
#ifdef VERTEXCOLOR
    Out.Color = patch[pointId].Color;
#endif
#if defined(LIGHTMAP) || defined(AO)
    Out.TexCoord2 = patch[pointId].TexCoord2;
#endif
#if defined(NORMALMAP) || defined(TRAILFACECAM) || defined(TRAILBONE)
    Out.Tangent = patch[pointId].Tangent;
#endif
#ifdef SKINNED
    Out.BlendWeights = patch[pointId].BlendWeights;
    Out.BlendIndices = patch[pointId].BlendIndices;
#endif
#ifdef INSTANCED
    Out.ModelInstance = patch[pointId].ModelInstance;
#endif
#if defined(BILLBOARD) || defined(DIRBILLBOARD)
    Out.Size = patch[pointId].Size;
#endif
    
    return Out;
}
#endif

#ifdef COMPILEDS
[domain("tri")]
PixelIn DS(ConstantOutputType input, float3 uvwCoord : SV_DomainLocation, const OutputPatch<DomainIn, 3> patch)
{
    DomainIn In; //intermediate to grab patch value as define depends on In.attribute syntax
    PixelIn Out;

    Out.Barycentric = uvwCoord;

    //I don't think they need transformation
#if defined(BILLBOARD) || defined(DIRBILLBOARD)
    In.Size = patch[0].Size;
#endif
#ifdef SKINNED
    Out.BlendWeights = patch[0].BlendWeights * uvwCoord.x + patch[1].BlendWeights * uvwCoord.y + patch[2].BlendWeights * uvwCoord.z;
    Out.BlendIndices = patch[0].BlendIndices;
#endif
#ifdef INSTANCED
    In.ModelInstance = patch[0].ModelInstance;
#endif
    // Define a 0,0 UV coord if not expected from the vertex data
#ifdef NOUV
    float2 In.TexCoord = float2(0.0, 0.0);
#endif

    In.Pos = uvwCoord.x * patch[0].Pos + uvwCoord.y * patch[1].Pos + uvwCoord.z * patch[2].Pos;
    float4x3 modelMatrix = ModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    Out.Pos = GetClipPos(worldPos);
    In.Normal = uvwCoord.x * patch[0].Normal + uvwCoord.y * patch[1].Normal + uvwCoord.z * patch[2].Normal;
    Out.Normal = GetWorldNormal(modelMatrix);
    Out.WorldPos = float4(worldPos, GetDepth(Out.Pos));

#if defined(D3D11) && defined(CLIPPLANE)
    Out.Clip = dot(Out.Pos, cClipPlane);
#endif

#ifdef VERTEXCOLOR
    In.Color = uvwCoord.x * patch[0].Color + uvwCoord.y * patch[1].Color + uvwCoord.z * patch[2].Color;
    Out.Color = In.Color;
#endif

    In.TexCoord = uvwCoord.x * patch[0].TexCoord + uvwCoord.y * patch[1].TexCoord + uvwCoord.z * patch[2].TexCoord;
#ifdef NORMALMAP
    In.Tangent = uvwCoord.x * patch[0].Tangent + uvwCoord.y * patch[1].Tangent + uvwCoord.z * patch[2].Tangent;
    float3 tangent = GetWorldTangent(modelMatrix);
    float3 bitangent = cross(tangent.xyz, Out.Normal) * In.Tangent.w;
    Out.TexCoord = float4(GetTexCoord(In.TexCoord), bitangent.xy);
    Out.Tangent = float4(tangent.xyz, bitangent.z);
#else
    Out.TexCoord = GetTexCoord(In.TexCoord);
#endif

#ifdef PERPIXEL
    // Per-pixel forward lighting
    float4 projWorldPos = float4(worldPos.xyz, 1.0);

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
        In.TexCoord2 = uvwCoord.x * patch[0].TexCoord2 + uvwCoord.y * patch[1].TexCoord2 + uvwCoord.z * patch[2].TexCoord2;
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
    
    return Out;
}
#endif

#ifdef COMPILEPS

//float3 fwidth(float3 vBC) 
//{
//    return float3(abs(ddx(vBC)) + abs(ddy(vBC)));
//}

float edgeFactor(float3 Barycentric)
{
    float3 d = fwidth(Barycentric);
    float3 a3 = smoothstep(float3(0.0,0.0,0.0), d*1.0, Barycentric);
    return min(min(a3.x, a3.y), a3.z);
}

float4 wireFrameColor = float4(0,0.5,0.5,.5);

void PS(PixelIn In, out PixelOut Out)
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        float4 diffInput = Sample2D(DiffMap, In.TexCoord.xy);
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
    #ifdef SPECMAP
        float3 specColor = cMatSpecColor.rgb * Sample2D(SpecMap, In.TexCoord.xy).rgb;
    #else
        float3 specColor = cMatSpecColor.rgb;
    #endif

    // Get normal
    #ifdef NORMALMAP
        float3x3 tbn = float3x3(In.Tangent.xyz, float3(In.TexCoord.zw, In.Tangent.w), In.Normal);
        float3 normal = normalize(mul(DecodeNormal(Sample2D(NormalMap, In.TexCoord.xy)), tbn));
    #else
        float3 normal = normalize(In.Normal);
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(In.WorldPos.w, In.WorldPos.y);
    #else
        float fogFactor = GetFogFactor(In.WorldPos.w);
    #endif

    #if defined(PERPIXEL)
        // Per-pixel forward lighting
        float3 lightDir;
        float3 lightColor;
        float3 finalColor;

        float diff = GetDiffuse(normal, In.WorldPos.xyz, lightDir);

        #ifdef SHADOW
            diff *= GetShadow(In.ShadowPos, In.WorldPos.w);
        #endif

        #if defined(SPOTLIGHT)
            lightColor = In.SpotPos.w > 0.0 ? Sample2DProj(LightSpotMap, In.SpotPos).rgb * cLightColor.rgb : 0.0;
        #elif defined(CUBEMASK)
            lightColor = SampleCube(LightCubeMap, In.CubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif
    
        #ifdef SPECULAR
            float spec = GetSpecular(normal, cCameraPosPS - In.WorldPos.xyz, lightDir, cMatSpecColor.a);
            finalColor = diff * lightColor * (diffColor.rgb + spec * specColor * cLightColor.a);
        #else
            finalColor = diff * lightColor * diffColor.rgb;
        #endif

        #ifdef AMBIENT
            finalColor += cAmbientColor.rgb * diffColor.rgb;
            finalColor += cMatEmissiveColor;
            Out.Color = float4(GetFog(finalColor, fogFactor), diffColor.a);
            //float4 shadedColor = float4(GetFog(finalColor, fogFactor), diffColor.a);
            //Out.Color = lerp(wireFrameColor, shadedColor, edgeFactor(In.Barycentric));
        #else
            Out.Color = float4(GetLitFog(finalColor, fogFactor), diffColor.a);
            //float4 shadedColor = float4(GetLitFog(finalColor, fogFactor), diffColor.a);
            //Out.Color = lerp(wireFrameColor, shadedColor, edgeFactor(In.Barycentric));
        #endif
    #elif defined(PREPASS)
        // Fill light pre-pass G-Buffer
        float specPower = cMatSpecColor.a / 255.0;

        Out.Color = float4(normal * 0.5 + 0.5, specPower);
        Out.Depth = In.WorldPos.w;
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        float specIntensity = specColor.g;
        float specPower = cMatSpecColor.a / 255.0;

        float3 finalColor = In.VertexLight * diffColor.rgb;
        #ifdef AO
            // If using AO, the vertex light ambient is black, calculate occluded ambient here
            finalColor += Sample2D(EmissiveMap, In.TexCoord2).rgb * cAmbientColor.rgb * diffColor.rgb;
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

        Out.Color = float4(GetFog(finalColor, fogFactor), 1.0);
        //float4 shadedColor = float4(GetFog(finalColor, fogFactor), 1.0);
        //Out.Color = lerp(wireFrameColor, shadedColor, edgeFactor(In.Barycentric));
        Out.Albedo = fogFactor * float4(diffColor.rgb, specIntensity);
        Out.Normal = float4(normal * 0.5 + 0.5, specPower);
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
        //float4 shadedColor = float4(GetFog(finalColor, fogFactor), diffColor.a);
        //Out.Color = lerp(wireFrameColor, shadedColor, edgeFactor(In.Barycentric));
    #endif
}
#endif
