#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"
#include "SSR.hlsl"

#line 9
#ifndef D3D11

// D3D9 uniforms
uniform float2 cNoiseSpeed;
uniform float cNoiseTiling;
uniform float cRefractNoiseStrength;
uniform float cReflectNoiseStrength;
uniform float cFresnelPower;
uniform float cFresnelBias;
uniform float3 cFoamColor;
uniform float cFoamTreshold;
uniform float3 cShallowColor;
uniform float3 cDeepColor;
uniform float cDepthScale;
uniform float cDefaultPlaneElevationWorld;

#else

// D3D11 constant buffers
#ifdef COMPILEVS
cbuffer CustomVS : register(b6)
{
    float2 cNoiseSpeed;
    float cNoiseTiling;
    float cDefaultPlaneElevationWorld;
}
#else
cbuffer CustomPS : register(b6)
{
    float cRefractNoiseStrength;
    float cReflectNoiseStrength;
    float cFresnelPower;
    float cFresnelBias;
    float3 cFoamColor;
    float cFoamTreshold;
    float3 cShallowColor;
    float3 cDeepColor;
    float cDepthScale;
}
#endif

#endif

struct VertexIn
{
    float4 Pos : POSITION;
    float3 Normal: NORMAL;

#if LIGHTING
    float4 Tangent : TANGENT;
#endif

    float2 TexCoord : TEXCOORD0;

#ifdef INSTANCED
    float4x3 ModelInstance : TEXCOORD4;
#endif
};

struct PixelIn
{
#if LIGHTING
    float4 WorldPos :TEXCOORD4;

    #ifdef PERPIXEL
        #ifdef SPOTLIGHT
            float4 SpotPos : TEXCOORD5;
        #endif
        #ifdef POINTLIGHT
            float3 CubeMaskVec : TEXCOORD5;
        #endif
    
        float4 Tangent : TEXCOORD0;
        float4 TexCoord : TEXCOORD1;
        float4 TexCoord2 : TEXCOORD2;
    #endif
#else
    float4 ScreenPos : TEXCOORD0;
    float2 ReflectUV : TEXCOORD1;
    float2 WaterUV : TEXCOORD2;
    float4 EyeVec : TEXCOORD4;
    float4 WorldPos : TEXCOORD5;
    #if SSR
        //float3 ViewPos : TEXCOORD5;
        float3 CameraRay : TEXCOORD6;
        float3 ViewNormal : TEXCOORD7;
        //float3 EyePosition : TEXCOORD5;
    #endif
#endif
    float3 Normal : TEXCOORD3;
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

    Out.Normal = GetWorldNormal(modelMatrix);

    #if LIGHTING
        Out.WorldPos = float4(worldPos, GetDepth(Out.Pos));

        #ifdef PERPIXEL
            // Per-pixel forward lighting
            float4 projWorldPos = float4(worldPos, 1.0);
                
            float3 tangent = GetWorldTangent(modelMatrix);
            float3 bitangent = cross(tangent, Out.Normal) * In.Tangent.w;
            Out.TexCoord = float4(GetTexCoord(In.TexCoord * cNoiseTiling + cElapsedTime * cNoiseSpeed), bitangent.xy);
            Out.TexCoord2 = float4(GetTexCoord(In.TexCoord.yx * cNoiseTiling - cElapsedTime * cNoiseSpeed), bitangent.xy);
            Out.Tangent = float4(tangent, bitangent.z);
        
            #ifdef SPOTLIGHT
                // Spotlight projection: transform from world space to projector texture coordinates
                Out.SpotPos = mul(projWorldPos, cLightMatrices[0]);
            #endif
        
            #ifdef POINTLIGHT
                Out.CubeMaskVec = mul(worldPos - cLightPos.xyz, (float3x3)cLightMatrices[0]);
            #endif
        #endif
    #else
        Out.ScreenPos = GetScreenPos(Out.Pos);
        Out.EyeVec = float4(cCameraPos - worldPos, GetDepth(Out.Pos));
        // GetQuadTexCoord() returns a float2 that is OK for quad rendering; multiply it with output W
        // coordinate to make it work with arbitrary meshes such as the water plane (perform divide in pixel shader)
        Out.ReflectUV = GetQuadTexCoord(Out.Pos) * Out.Pos.w;
        Out.WaterUV = In.TexCoord * cNoiseTiling + cElapsedTime * cNoiseSpeed;
        Out.WorldPos = float4(worldPos, max(worldPos.y - cDefaultPlaneElevationWorld, 0.0)); 
        #if SSR
            //float4 cameraRay = float4( In.TexCoord * 2.0 - 1.0, 1.0, 1.0);
            //cameraRay = mul(cameraRay, cProjInv);
            //Out.CameraRay = cameraRay.xyz / cameraRay.w;
            //Out.ViewPos = mul(worldPos, cView); 
            //Out.ViewNormal = mul(mul(In.Normal, (float3x3)modelMatrix), cView);
            Out.CameraRay = mul(GetWorldPos(modelMatrix) - cCameraPos, cView);
            Out.ViewNormal = mul(GetWorldNormal(modelMatrix), cView);
        #endif
    #endif

    #if defined(D3D11) && defined(CLIPPLANE)
        Out.Clip = dot(Out.Pos, cClipPlane);
    #endif
}

void PS(PixelIn In, out PixelOut Out)
{
#if LIGHTING
    #ifdef PERPIXEL
        #if defined(SPOTLIGHT)
            float3 lightColor = In.SpotPos.w > 0.0 ? Sample2DProj(LightSpotMap, In.SpotPos).rgb * cLightColor.rgb : 0.0;
        #elif defined(CUBEMASK)
            float3 lightColor = SampleCube(LightCubeMap, In.CubeMaskVec).rgb * cLightColor.rgb;
        #else
            float3 lightColor = cLightColor.rgb;
        #endif

        #ifdef DIRLIGHT
            float3 lightDir = cLightDirPS;
        #else
            float3 lightVec = (cLightPosPS.xyz - In.WorldPos.xyz) * cLightPosPS.w;
            float3 lightDir = normalize(lightVec);
        #endif
        
        float3x3 tbn = float3x3(In.Tangent.xyz, float3(In.TexCoord.zw, In.Tangent.w), In.Normal);
        float3 normal = normalize(mul(DecodeNormal(Sample2D(SpecMap, In.TexCoord.xy)), tbn)); //Those are normals but I had to use the unit3 to store the normals
        float3 normal2 = normalize(mul(DecodeNormal(Sample2D(SpecMap, In.TexCoord2.xy)), tbn));
        normal = normalize(normal + normal2);
        
        #ifdef HEIGHTFOG
            float fogFactor = GetHeightFogFactor(In.WorldPos.w, In.WorldPos.y);
        #else
            float fogFactor = GetFogFactor(In.WorldPos.w);
        #endif
        
        //Not sure about that
        float3 spec = GetSpecular(normal, cCameraPosPS - In.WorldPos.xyz, lightDir, 200.0) * lightColor * cLightColor.a;
        
        Out.Color = float4(GetLitFog(spec, fogFactor), 1.0);
    #endif
#else
        //Get reflect and refract UV
        float2 refractUV = In.ScreenPos.xy / In.ScreenPos.w;
        //float2 reflectUV = In.ReflectUV.xy / In.ScreenPos.w;
    
        //Store refract UV before applying noise
        float2 noiseLessRefractUV = refractUV;
    
        float3 noise = (Sample2D(SpecMap, In.WaterUV).rgb - 0.5);
        refractUV += noise.rg * cRefractNoiseStrength;
    
        //Do not shift reflect UV coordinate upward, because it will reveal the clipping of geometry below water
        if (noise.y < 0.0)
            noise.y = 0.0;
        //reflectUV += noise;
        //float3 reflectDir = reflect(normalize(In.ViewPos), In.ViewNormal);
        //convert from eye to world
        //reflectDir = mul(reflectDir, cViewInvPS);
        //float3 reflectDir = reflect(-In.EyeVec.xyz, In.Normal);
        //float3 reflectDir = reflect(normalize(In.CameraRay), In.Normal);
        float3 reflectDir = mul(reflect(normalize(In.CameraRay), normalize(In.ViewNormal)), cViewInvPS);
        reflectDir += noise * cReflectNoiseStrength;
    
        //float2 reflectDirUV = ;
    
        //Get depth and original depth
        float depth = Sample2DLod0(DepthBuffer, refractUV).r;
        float depthOriginal = Sample2DLod0(DepthBuffer, noiseLessRefractUV).r;
    
        #ifdef HWDEPTH
        depth = ReconstructDepth(depth);
        depthOriginal = ReconstructDepth(depthOriginal);
        #endif
    
        //Object above the water reset refracted UV and depth value
        refractUV = lerp(refractUV , noiseLessRefractUV, depth < depthOriginal);
        depth = lerp(depth , depthOriginal, depth < depthOriginal);
    
        //Calculate water depth
        float waterDepth = (depth - In.EyeVec.w) * (cFarClipPS - cNearClipPS);
        
        //Calculate original water depth
        float originalWaterDepth = (depthOriginal - In.EyeVec.w) * (cFarClipPS - cNearClipPS);
    
        //Calculate fresnel component
        half facing = (1.0 - dot(normalize(In.EyeVec.xyz), In.Normal));
        float fresnel = max(cFresnelBias + (1.0 - cFresnelBias) * pow(facing, cFresnelPower), 0.0);

        float3 decodedNormal = DecodeNormal(Sample2D(NormalMap, noiseLessRefractUV));
        float steepness = 1.0 - dot(float3(0.0,1.0,0.0), normalize(decodedNormal));
    
        float3 refractColor = Sample2D(EnvMap, refractUV).rgb;

        float3 reflectColor;
        
        //Parallax-correction code
        float3 ReflDirectionWS = reflectDir;
        //// Following is the parallax-correction code
        //// Find the ray intersection with box plane
        //float3 FirstPlaneIntersect = (cZoneMax - In.WorldPos) / ReflDirectionWS;
        //float3 SecondPlaneIntersect = (cZoneMin - In.WorldPos) / ReflDirectionWS;
        //// Get the furthest of these intersections along the ray
        //// (Ok because x/0 give +inf and -x/0 give –inf )
        //float3 FurthestPlane = max(FirstPlaneIntersect, SecondPlaneIntersect);
        //// Find the closest far intersection
        //float Distance = min(min(FurthestPlane.x, FurthestPlane.y), FurthestPlane.z);
        //
        //// Get the intersection position
        //float3 IntersectPositionWS = In.WorldPos + ReflDirectionWS * Distance;
        //// Get corrected reflection
        //ReflDirectionWS = IntersectPositionWS - cZonePositionWS;
        // End parallax-correction code
//SSR or fallback
    #ifdef SSR
        //float3 vsRayOrigin = mul(In.CameraRay.xyz, cViewPS);
        //float3 vsRayOrigin =  mul(-In.EyeVec.xyz, cViewPS);//ScreenSpaceToViewSpace(-In.EyeVec.xyz, depthOriginal);
        //float3 vsRayOrigin = In.CameraRay * iEyeVec.w;//ScreenSpaceToViewSpace(In.CameraRay, In.EyeVec.w);
        float3 vsRayOrigin = In.CameraRay;
    
        //float3 vsRayDirection = normalize(mul(reflectDir.xyz, cViewPS));//normalize( reflect( normalize(vsRayOrigin), mul(In.Normal, cViewPS)));
        //float3 vsRayDirection = normalize( reflect( normalize(vsRayOrigin), mul(In.Normal, cViewPS)));
        //float3 vsRayDirection = normalize( reflect( normalize(vsRayOrigin), In.ViewNormal));
        float3 vsRayDirection = reflect(normalize(In.CameraRay), normalize(In.ViewNormal));
        
        float2 hitPixel = float2(0.0f, 0.0f); 
        float3 hitPoint = float3(0.0f, 0.0f, 0.0f);

        //float2 uv2 = noiseLessRefractUV * cRenderBufferSize;
        //float c = (uv2.x + uv2.y) * 0.25;
        //float jitter = fmod( c, 1.0);
        
        float stride = 1.0; //tbd by user
        float jitter = stride > 1.0f ? float(int(noiseLessRefractUV.x + noiseLessRefractUV.y) & 1) * 0.5f : 0.0f;
        
        float zThickness = 1.0; //use double depth ?
        
        float pixelStrideZCuttoff = 0.0f;//(cFarClipPS - cNearClipPS) * 0.5;
        const float numberIterations = 500.0;
        float maxDistance = 5000.0;//(cFarClipPS - cNearClipPS);
        
        bool intersect = traceScreenSpaceRay(vsRayOrigin,
                                             vsRayDirection,
                                             jitter,
                                             maxDistance,
                                             pixelStrideZCuttoff,
                                             stride,
                                             numberIterations,
                                             hitPixel,
                                             hitPoint);

        //float2 oneDividedByRenderBufferSize = 1.0 /cRenderBufferSize;
        //bool intersect = traceScreenSpaceRay( vsRayOrigin,
        //                                       vsRayDirection,
        //                                       maxDistance,
        //                                       stride,
        //                                       pixelStrideZCuttoff,
        //                                       jitter,
        //                                       numberIterations,
        //                                       oneDividedByRenderBufferSize,
        //                                       hitPixel,
        //                                       hitPoint,
        //                                       iterationCount,
        //                                       i.uv.x > 0.5);
        
        //bool intersect = traceScreenSpaceRay1(vsRayOrigin,
        //                                      vsRayDirection,
        //                                      zThickness,
        //                                      stride,
        //                                      jitter,
        //                                      numberIterations,
        //                                      pixelStrideZCuttoff,
        //                                      hitPixel,
        //                                      hitPoint);
        float2 reflectUV = (hitPixel / 2.0  * cGBufferInvSize) + float2(0.5,0.0);
        
        if(reflectUV.x > 1.0 || reflectUV.x < 0.0 || reflectUV.y > 1.0 || reflectUV.y < 0.0)
        {
            intersect = false;
        }
        
        //if(intersect)
        //{
        //    
        //    //reflectColor = lerp(Sample2D(EnvMap, reflectUV).rgb , SampleCube(DiffCubeMap, reflectDir).rgb, hitPoint.z > vsRayOrigin.z);
        //    //float alpha = calculateAlphaForIntersection( intersect, iterationCount, specularStrength, hitPixel, hitPoint, vsRayOrigin, vsRayDirection);
        //    //reflectColor = float3(1.0,0.0,0.0);
        //    //reflectColor = Sample2D(EnvMap, reflectUV).rgb;
        //    float3 ssrReflectColor = Sample2D(EnvMap, reflectUV).rgb;
        //    //reflectColor = SampleCube(DiffCubeMap, reflectDir);
        //    
        //    float3 cubemapReflectColor = SampleCube(ZoneCubeMap, ReflDirectionWS);
        //    
        //    reflectColor = lerp(ssrReflectColor, cubemapReflectColor, 0.5f);
        //}
        //else
        {
            //reflectColor = SampleCube(DiffCubeMap, reflectDir);
            reflectColor = SampleCube(ZoneCubeMap, ReflDirectionWS);
            //reflectColor = SampleCube(ZoneCubeMap, reflectDir);
        }
    #else
        //reflectColor = SampleCube(DiffCubeMap, reflectDir);
        reflectColor = SampleCube(ZoneCubeMap, ReflDirectionWS);
        //reflectColor = SampleCube(ZoneCubeMap, reflectDir);
    #endif
    
    float3 waterColor = lerp(cShallowColor, cDeepColor, clamp(waterDepth * cDepthScale, 0.0, 1.0));
    
    refractColor *= waterColor;
    
    float3 finalColor = lerp(refractColor, reflectColor, fresnel);
    
    finalColor = lerp(finalColor, cFoamColor, saturate(In.WorldPos.w / cFoamTreshold));
    finalColor = lerp(cFoamColor, finalColor, saturate((originalWaterDepth + (noise.x * 0.1)) / cFoamTreshold) + steepness);
   
    Out.Color = float4(GetFog(finalColor, GetFogFactor(In.EyeVec.w)), GetSoftParticleAlpha(originalWaterDepth * cDepthScale, 1.0 ));
    //Out.Color = float4(GetFog(reflectColor, GetFogFactor(In.EyeVec.w)), 1.0 );
#endif
}