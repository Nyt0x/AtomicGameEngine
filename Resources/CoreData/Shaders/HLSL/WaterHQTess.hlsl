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
#if defined(COMPILEVS) || defined(COMPILEGS) || defined(COMPILEDS)
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

struct HullIn
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
    float TessAmount : TEXCOORD1;
};

struct DomainIn
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

struct ConstantOutputType
{
    float edges[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
    
    float3 B210: POSITION3;
    float3 B120: POSITION4;
    float3 B021: POSITION5;
    float3 B012: POSITION6;
    float3 B102: POSITION7;
    float3 B201: POSITION8;
    float3 B111: CENTER;
    
    float3 N200: NORMAL0;
    float3 N020: NORMAL1;
    float3 N002: NORMAL2;

    float3 N110: NORMAL3;      
    float3 N011: NORMAL4;
    float3 N101: NORMAL5;
};

// // Simple displacement calculation from displacement map
// // If no displacement texture is provided, or DisplaceScale is 0 no displacement takes place
// // The float3 result should be added to the vertex position
// float3 CalculateDisplacement(float2 UV, float3 worldNormal)
// {
    // // Skip displacement sampling if 0 multiplier
    // if (DisplaceScale == 0)
        // return 0;

    // // Choose the most detailed mipmap level
	// const float mipLevel = 1.0f;
	
	// // Sample height map - using R channel
	// float height = DisplacementMap.SampleLevel(Sampler, UV, mipLevel).r;
    
    // // remap height from 0 to 1, to -1 to 1 (with midlevel offset)
    // //height = (2 * height) - 1;
    // float midLevel = max(DisplaceMidLevel, 0.0001f);
    // if (height > midLevel)
        // // Remap the range between midLevel and 1 to 0 and 1
        // height = (height-midLevel) / (1 - midLevel);
    // else
        // // Remap the range between 0 and midLevel to -1 and 0
        // height = height / midLevel - 1;

    // // Return offset along normal.
	// return height * DisplaceScale * worldNormal;
// }

#ifdef COMPILEVS
void VS(VertexIn In, out HullIn Out)
{

    //float4x3 modelMatrix = ModelMatrix;
    //float3 worldPos = GetWorldPos(modelMatrix);
    //Out.Pos = GetClipPos(worldPos);
    //
    //Out.Normal = normalize(GetWorldNormal(modelMatrix));
    
    Out.Pos = In.Pos;
    Out.Normal = In.Normal;

#if LIGHTING
    Out.Tangent = In.Tangent;
#endif

    Out.TexCoord = In.TexCoord;

#ifdef INSTANCED
    Out.ModelInstance = In.ModelInstance;
#endif

    ////float4x3 modelMatrix = ModelMatrix;
    ////float3 worldPos = GetWorldPos(modelMatrix);
    //float d = distance(cCameraPos, In.Pos);
    //
    //// Normalized tessellation factor. 
    //// The tessellation is 
    ////   0 if d >= gMinTessDistance and
    ////   1 if d <= gMaxTessDistance.
    //float gMinTessDistance = 100;
    //float gMaxTessDistance = 1;
    //float gMinTessFactor = 3;
    //float gMaxTessFactor = 8;
    //float tess = saturate( (gMinTessDistance - d) / (gMinTessDistance - gMaxTessDistance) );
    //
    //// Rescale [0,1] --> [gMinTessFactor, gMaxTessFactor].
    //Out.TessAmount = gMinTessFactor + tess*(gMaxTessFactor-gMinTessFactor);
    
    Out.TessAmount = 8;
    
    //Out.TessAmount = 10;

}
#endif

#ifdef COMPILEHS
ConstantOutputType PatchConstantFunction(InputPatch<HullIn, 3> inputPatch, uint patchId : SV_PrimitiveID)
{    
    ConstantOutputType output;


    //// Set the tessellation factors for the three edges of the triangle.
    //output.edges[0] = cTessellationAmount;
    //output.edges[1] = cTessellationAmount;
    //output.edges[2] = cTessellationAmount;
    //
    //// Set the tessellation factor for tessallating inside the triangle.
    //output.inside = cTessellationAmount;
    
    float3 roundedEdgeTessFactor; float roundedInsideTessFactor, insideTessFactor;
    ProcessTriTessFactorsMax((float3)inputPatch[0].TessAmount, 1.0, roundedEdgeTessFactor, roundedInsideTessFactor, insideTessFactor);

    // Apply the edge and inside tessellation factors
    output.edges[0] = roundedEdgeTessFactor.x;
    output.edges[1] = roundedEdgeTessFactor.y;
    output.edges[2] = roundedEdgeTessFactor.z;
    output.inside = roundedInsideTessFactor;

    return output;
}

ConstantOutputType HS_PNTrianglesConstant(InputPatch<HullIn, 3> patch)
{
    ConstantOutputType result = (ConstantOutputType)0;

    //// Backface culling - using face normal
    //// Calculate face normal
    //float3 edge0 = patch[1].Pos - patch[0].Pos;
    //float3 edge2 = patch[2].Pos - patch[0].Pos;
    //float3 faceNormal = normalize(cross(edge2, edge0));
    //float3 view = normalize(patch[0].Pos - CameraPosition);

    //if (dot(view, faceNormal) < -0.25) {
    //    result.edges[0] = 0;
    //    result.edges[1] = 0;
    //    result.edges[2] = 0;
    //    result.inside = 0;
    //    return result; // culled, so no further processing
    //}
    //// end: backface culling

    //// Backface culling - using Vertex normals
    //bool backFacing = true;
    ////float insideMultiplier = 0.125; // default inside multiplier
    //[unroll]
    //for (uint j = 0; j < 3; j++)
    //{
    //    float3 view = normalize(CameraPosition - patch[j].Pos);
    //    float a = dot(view, patch[j].Normal);
    //    if (a >= -0.125) {
    //        backFacing = false;
    //        //if (a <= 0.125)
    //        //{
    //        //    // Is near to silhouette so keep full tessellation
    //        //    insideMultiplier = 1.0;
    //        //}
    //    }
    //}
    //if (backFacing) {
    //    result.edges[0] = 0;
    //    result.edges[1] = 0;
    //    result.edges[2] = 0;
    //    result.inside = 0;
    //    return result; // culled, so no further processing
    //}
    //// end: backface culling

    //float3 roundedEdgeTessFactor; float roundedInsideTessFactor, insideTessFactor;
    //ProcessTriTessFactorsMax((float3)patch[0].TessAmount, 1.0, roundedEdgeTessFactor, roundedInsideTessFactor, insideTessFactor);
    //
    //// Apply the edge and inside tessellation factors
    //result.edges[0] = roundedEdgeTessFactor.x;
    //result.edges[1] = roundedEdgeTessFactor.y;
    //result.edges[2] = roundedEdgeTessFactor.z;
    //result.inside = roundedInsideTessFactor;
    ////result.inside = roundedInsideTessFactor * insideMultiplier;
    
    static const float MODIFIER = 0.1f;

    float fDistance;
    float3 f3MidPoint;
    // Edge 0
    f3MidPoint = ( patch[2].Pos + patch[0].Pos ) / 2.0f;
    fDistance = distance(cCameraPos.xyz, f3MidPoint)*MODIFIER - patch[0].TessAmount;
    result.edges[0] = patch[0].TessAmount * ( 1.0f - clamp( ( fDistance / patch[0].TessAmount ), 0.0f, 1.0f - ( 1.0f / patch[0].TessAmount ) ) );
    // Edge 1
    f3MidPoint = ( patch[0].Pos + patch[1].Pos ) / 2.0f;
    fDistance = distance(cCameraPos.xyz, f3MidPoint)*MODIFIER - patch[0].TessAmount;
    result.edges[1] = patch[0].TessAmount * ( 1.0f - clamp( ( fDistance / patch[0].TessAmount ), 0.0f, 1.0f - ( 1.0f / patch[0].TessAmount ) ) );
    // Edge 2
    f3MidPoint = ( patch[1].Pos + patch[2].Pos ) / 2.0f;
    fDistance = distance(cCameraPos.xyz, f3MidPoint)*MODIFIER - patch[0].TessAmount;
    result.edges[2] = patch[0].TessAmount * ( 1.0f - clamp( ( fDistance / patch[0].TessAmount ), 0.0f, 1.0f - ( 1.0f / patch[0].TessAmount ) ) );
    // Inside
    result.inside = ( result.edges[0] + result.edges[1] + result.edges[2] ) / 3.0f;


    //************************************************************
    // Calculate PN-Triangle coefficients
    // Refer to Vlachos 2001 for the original formula
    float3 p1 = patch[0].Pos;
    float3 p2 = patch[1].Pos;
    float3 p3 = patch[2].Pos;

    //B300 = p1;
    //B030 = p2;
    //float3 b003 = p3;
    
    float3 n1 = patch[0].Normal;
    float3 n2 = patch[1].Normal;
    float3 n3 = patch[2].Normal;
    
    //N200 = n1;
    //N020 = n2;
    //N002 = n3;

    // Calculate control points
    float w12 = dot ((p2 - p1), n1);
    result.B210 = (2.0f * p1 + p2 - w12 * n1) / 3.0f;

    float w21 = dot ((p1 - p2), n2);
    result.B120 = (2.0f * p2 + p1 - w21 * n2) / 3.0f;

    float w23 = dot ((p3 - p2), n2);
    result.B021 = (2.0f * p2 + p3 - w23 * n2) / 3.0f;
    
    float w32 = dot ((p2 - p3), n3);
    result.B012 = (2.0f * p3 + p2 - w32 * n3) / 3.0f;

    float w31 = dot ((p1 - p3), n3);
    result.B102 = (2.0f * p3 + p1 - w31 * n3) / 3.0f;
    
    float w13 = dot ((p3 - p1), n1);
    result.B201 = (2.0f * p1 + p3 - w13 * n1) / 3.0f;
    
    float3 e = (result.B210 + result.B120 + result.B021 + 
                result.B012 + result.B102 + result.B201) / 6.0f;
    float3 v = (p1 + p2 + p3) / 3.0f;
    result.B111 = e + ((e - v) / 2.0f);
    
    // Calculate normals
    float v12 = 2.0f * dot ((p2 - p1), (n1 + n2)) / 
                          dot ((p2 - p1), (p2 - p1));
    result.N110 = normalize ((n1 + n2 - v12 * (p2 - p1)));

    float v23 = 2.0f * dot ((p3 - p2), (n2 + n3)) /
                          dot ((p3 - p2), (p3 - p2));
    result.N011 = normalize ((n2 + n3 - v23 * (p3 - p2)));

    float v31 = 2.0f * dot ((p1 - p3), (n3 + n1)) /
                          dot ((p1 - p3), (p1 - p3));
    result.N101 = normalize ((n3 + n1 - v31 * (p1 - p3)));

    return result;
}

[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("HS_PNTrianglesConstant")]
//[patchconstantfunc("PatchConstantFunction")]
DomainIn HS(InputPatch<HullIn, 3> patch, uint pointId : SV_OutputControlPointID, uint patchId : SV_PrimitiveID)
{
    DomainIn Out;

    Out.Pos = patch[pointId].Pos;
    Out.Normal = patch[pointId].Normal;

#if LIGHTING
    Out.Tangent = patch[pointId].Tangent;
#endif

    Out.TexCoord = patch[pointId].TexCoord;

#ifdef INSTANCED
    Out.ModelInstance = patch[pointId].ModelInstance;
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
    
    // Prepare barycentric ops (xyz=uvw,   w=1-u-v,   u,v,w>=0)
    float u = uvwCoord.x;
    float v = uvwCoord.y;
    float w = uvwCoord.z;
    float uu = u * u;
    float vv = v * v;
    float ww = w * w;
    float uu3 = 3.0 * uu;
    float vv3 = 3.0 * vv;
    float ww3 = 3.0 * ww;
    
    // Interpolate using barycentric coordinates and PN Triangle control points
    In.Pos = 
    patch[0].Pos * w * ww + //B300
    patch[1].Pos * u * uu + //B030
    patch[2].Pos * v * vv + //B003
    float4(input.B210, 1.0) * ww3 * u +
    float4(input.B120, 1.0) * uu3 * w +
    float4(input.B201, 1.0) * ww3 * v +
    float4(input.B021, 1.0) * uu3 * v +
    float4(input.B102, 1.0) * vv3 * w +
    float4(input.B012, 1.0) * vv3 * u +
    float4(input.B111, 1.0) * 6.0 * w * u * v;

    In.Normal = 
    patch[0].Normal * ww + //N200
    patch[1].Normal * uu + //N020
    patch[2].Normal * vv + //N002
    input.N110 * w * u +
    input.N011 * u * v +
    input.N101 * w * v;
    
    In.TexCoord = uvwCoord.x * patch[0].TexCoord + uvwCoord.y * patch[1].TexCoord + uvwCoord.z * patch[2].TexCoord;

    //In.Pos = uvwCoord.x * patch[0].Pos + uvwCoord.y * patch[1].Pos + uvwCoord.z * patch[2].Pos;

    //In.Normal = uvwCoord.x * patch[0].Normal + uvwCoord.y * patch[1].Normal + uvwCoord.z * patch[2].Normal;

    // Perform displacement
    In.Normal = normalize(In.Normal);
    //In.Pos += CalculateDisplacement(In.TexCoord, In.Normal);
    In.Pos += 0.2 * float4(In.Normal,1.0); //DisplaceScale * worldNormal

#if LIGHTING
    In.Tangent = uvwCoord.x * patch[0].Tangent + uvwCoord.y * patch[1].Tangent + uvwCoord.z * patch[2].Tangent;
#endif

#ifdef INSTANCED
    In.ModelInstance = patch[0].ModelInstance;
#endif

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

    return Out;
}
#endif

#ifdef COMPILEPS
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
        // // Following is the parallax-correction code
        // // Find the ray intersection with box plane
        // float3 FirstPlaneIntersect = (cZoneMax - In.WorldPos) / ReflDirectionWS;
        // float3 SecondPlaneIntersect = (cZoneMin - In.WorldPos) / ReflDirectionWS;
        // // Get the furthest of these intersections along the ray
        // // (Ok because x/0 give +inf and -x/0 give –inf )
        // float3 FurthestPlane = max(FirstPlaneIntersect, SecondPlaneIntersect);
        // // Find the closest far intersection
        // float Distance = min(min(FurthestPlane.x, FurthestPlane.y), FurthestPlane.z);
        // 
        // // Get the intersection position
        // float3 IntersectPositionWS = In.WorldPos + ReflDirectionWS * Distance;
        // // Get corrected reflection
        // ReflDirectionWS = IntersectPositionWS - cZonePositionWS;
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
                                             reflectDir,
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
        
        if(intersect)
        {
            
            //reflectColor = lerp(Sample2D(EnvMap, reflectUV).rgb , SampleCube(DiffCubeMap, reflectDir).rgb, hitPoint.z > vsRayOrigin.z);
            //float alpha = calculateAlphaForIntersection( intersect, iterationCount, specularStrength, hitPixel, hitPoint, vsRayOrigin, vsRayDirection);
            //reflectColor = float3(1.0,0.0,0.0);
            //reflectColor = Sample2D(EnvMap, reflectUV).rgb;
            float3 ssrReflectColor = Sample2D(EnvMap, reflectUV).rgb;
            //reflectColor = SampleCube(DiffCubeMap, reflectDir);
            
            float3 cubemapReflectColor = SampleCube(ZoneCubeMap, ReflDirectionWS);
            
            reflectColor = lerp(ssrReflectColor, cubemapReflectColor, 0.5f);
            //reflectColor = ssrReflectColor;
        }
        else
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
    //reflectColor = float4(1.0,0.0,0.0,0.0);
    float3 waterColor = lerp(cShallowColor, cDeepColor, clamp(waterDepth * cDepthScale, 0.0, 1.0));
    
    refractColor *= waterColor;
    
    float3 finalColor = lerp(refractColor, reflectColor, fresnel);
    
    //finalColor = lerp(finalColor, cFoamColor, saturate(In.WorldPos.w / cFoamTreshold));
    finalColor = lerp(cFoamColor, finalColor, saturate((originalWaterDepth + (noise.x * 0.1)) / cFoamTreshold) + steepness);
   
    Out.Color = float4(GetFog(finalColor, GetFogFactor(In.EyeVec.w)), GetSoftParticleAlpha(originalWaterDepth * cDepthScale, 1.0 ));
    //Out.Color = float4(GetFog(reflectColor, GetFogFactor(In.EyeVec.w)), 1.0 );
#endif
}
#endif