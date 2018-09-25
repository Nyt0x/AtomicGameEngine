#ifdef COMPILEPS
    #ifdef SSR

    inline float linearizeDepth(float z)
    {
        return z / (cFarClipPS - z * (cFarClipPS - cNearClipPS));
    }
    
    inline float3 ScreenSpaceToViewSpace( float3 cameraRay, float depth)
    {
        return (cameraRay * linearizeDepth(depth));
    }

    inline float distanceSquared( float2 a, float2 b) 
    { 
        a -= b;
        return dot(a, a); 
    }
    
    inline void swapIfBigger( inout float aa, inout float bb)
    {
        if( aa > bb)
        {
            float tmp = aa;
            aa = bb;
            bb = tmp;
        }
    }
    
    // By Morgan McGuire and Michael Mara at Williams College 2014
    // Released as open source under the BSD 2-Clause License
    // http://opensource.org/licenses/BSD-2-Clause
    //
    // Copyright (c) 2014, Morgan McGuire and Michael Mara
    // All rights reserved.
    //
    // From McGuire and Mara, Efficient GPU Screen-Space Ray Tracing,
    // Journal of Computer Graphics Techniques, 2014
    //
    // This software is open source under the "BSD 2-clause license":
    //
    // Redistribution and use in source and binary forms, with or
    // without modification, are permitted provided that the following
    // conditions are met:
    //
    // 1. Redistributions of source code must retain the above
    // copyright notice, this list of conditions and the following
    // disclaimer.
    //
    // 2. Redistributions in binary form must reproduce the above
    // copyright notice, this list of conditions and the following
    // disclaimer in the documentation and/or other materials provided
    // with the distribution.
    //
    // THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
    // CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
    // INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
    // MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    // DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
    // CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    // SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    // LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
    // USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
    // AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    // LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
    // IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
    // THE POSSIBILITY OF SUCH DAMAGE.
    /**
     * The ray tracing step of the SSLR implementation.
     * Modified version of the work stated above.
     */
    //#include "SSLRConstantBuffer.hlsli"
    //#include "../../ConstantBuffers/PerFrame.hlsli"
    //#include "../../Utils/DepthUtils.hlsli"
     
    bool intersectsDepthBuffer(float z, float minZ, float maxZ)
    {
     /*
     * Based on how far away from the camera the depth is,
     * adding a bit of extra thickness can help improve some
     * artifacts. Driving this value up too high can cause
     * artifacts of its own.
     */
     //TMP HACK 
     float cb_strideZCutoff = (cFarClipPS - cNearClipPS) * 0.5;
     float cb_zThickness = cFarClipPS - cNearClipPS;
     //end
     float depthScale = min(1.0f, z * cb_strideZCutoff);
     z += cb_zThickness + lerp(0.0f, 2.0f, depthScale);
     return (maxZ >= z) && (minZ - cb_zThickness <= z);
    }
     
    void swap(inout float a, inout float b)
    {
     float t = a;
     a = b;
     b = t;
    }
     
    // Returns true if the ray hit something
    bool traceScreenSpaceRay(
     // Camera-space ray origin, which must be within the view volume
     float3 csOrig,
     // Unit length camera-space ray direction
     float3 csDir,
     // Number between 0 and 1 for how far to bump the ray in stride units
     // to conceal banding artifacts. Not needed if stride == 1.
     float jitter,
     float maxDistance,
     float pixelStrideZCuttoff,
     float stride,
     float maxSteps,
     // Pixel coordinates of the first intersection with the scene
     out float2 hitPixel,
     // Camera space location of the ray hit
     out float3 hitPoint)
    {
     // Clip to the near plane
     float rayLength = ((csOrig.z + csDir.z * maxDistance) < cNearClipPS) ?
     (cNearClipPS - csOrig.z) / csDir.z : maxDistance;
     float3 csEndPoint = csOrig + csDir * rayLength;
     
     // Project into homogeneous clip space
     float4 H0 = mul(float4(csOrig, 1.0f), cProjPS);
     H0.xy *= cRenderBufferSize;
     float4 H1 = mul(float4(csEndPoint, 1.0f), cProjPS);
     H1.xy *= cRenderBufferSize;
     float k0 = 1.0f / H0.w;
     float k1 = 1.0f / H1.w;
     
     // The interpolated homogeneous version of the camera-space points
     float3 Q0 = csOrig * k0;
     float3 Q1 = csEndPoint * k1;
     
     // Screen-space endpoints
     float2 P0 = H0.xy * k0;
     float2 P1 = H1.xy * k1;
     
     // If the line is degenerate, make it cover at least one pixel
     // to avoid handling zero-pixel extent as a special case later
     P1 += (distanceSquared(P0, P1) < 0.0001f) ? float2(0.01f, 0.01f) : 0.0f;
     float2 delta = P1 - P0;
     
     // Permute so that the primary iteration is in x to collapse
     // all quadrant-specific DDA cases later
     bool permute = false;
     if(abs(delta.x) < abs(delta.y))
     {
     // This is a more-vertical line
     permute = true;
     delta = delta.yx;
     P0 = P0.yx;
     P1 = P1.yx;
     }
     
     float stepDir = sign(delta.x);
     float invdx = stepDir / delta.x;
     
     // Track the derivatives of Q and k
     float3 dQ = (Q1 - Q0) * invdx;
     float dk = (k1 - k0) * invdx;
     float2 dP = float2(stepDir, delta.y * invdx);
     
     // Scale derivatives by the desired pixel stride and then
     // offset the starting values by the jitter fraction
     float strideScale = 1.0f - min(1.0f, csOrig.z * pixelStrideZCuttoff);
     stride = 1.0f + strideScale * stride;
     dP *= stride;
     dQ *= stride;
     dk *= stride;
     
     P0 += dP * jitter;
     Q0 += dQ * jitter;
     k0 += dk * jitter;
     
     // Slide P from P0 to P1, (now-homogeneous) Q from Q0 to Q1, k from k0 to k1
     float4 PQk = float4(P0, Q0.z, k0);
     float4 dPQk = float4(dP, dQ.z, dk);
     float3 Q = Q0; 
     
     // Adjust end condition for iteration direction
     float end = P1.x * stepDir;
     
     float stepCount = 0.0f;
     float prevZMaxEstimate = csOrig.z;
     float rayZMin = prevZMaxEstimate;
     float rayZMax = prevZMaxEstimate;
     float sceneZMax = rayZMax + 100.0f;
     for(;
     ((PQk.x * stepDir) <= end) && (stepCount < maxSteps) &&
     !intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax) &&
     (sceneZMax != 0.0f);
     ++stepCount)
     {
     rayZMin = prevZMaxEstimate;
     rayZMax = (dPQk.z * 0.5f + PQk.z) / (dPQk.w * 0.5f + PQk.w);
     prevZMaxEstimate = rayZMax;
     
     if(rayZMin > rayZMax)
     {
        swap(rayZMin, rayZMax);
     }
     
     hitPixel = permute ? PQk.yx : PQk.xy;
     // You may need hitPixel.y = depthBufferSize.y - hitPixel.y; here if your vertical axis
     // is different than ours in screen space
     hitPixel.y = cRenderBufferSize.y - hitPixel.y;
     sceneZMax = linearizeDepth(Sample2DLod0(DepthBuffer, hitPixel * cGBufferInvSize).r);
     
     PQk += dPQk;
     }
     
     // Advance Q based on the number of steps
     Q.xy += dQ.xy * stepCount;
     hitPoint = Q * (1.0f / PQk.w);
     return intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax);
    }
     
    //float4 main(VertexOut pIn) : SV_TARGET
    //{
    // int3 loadIndices = int3(pIn.posH.xy, 0);
    // float3 normalVS = normalBuffer.Load(loadIndices).xyz;
    // if(!any(normalVS))
    // {
    // return 0.0f;
    // }
    // 
    // float depth = depthBuffer.Load(loadIndices).r;
    // float3 rayOriginVS = pIn.viewRay * linearizeDepth(depth);
    // 
    // /*
    // * Since position is reconstructed in view space, just normalize it to get the
    // * vector from the eye to the position and then reflect that around the normal to
    // * get the ray direction to trace.
    // */
    // float3 toPositionVS = normalize(rayOriginVS);
    // float3 rayDirectionVS = normalize(reflect(toPositionVS, normalVS));
    // 
    // // output rDotV to the alpha channel for use in determining how much to fade the ray
    // float rDotV = dot(rayDirectionVS, toPositionVS);
    // 
    // // out parameters
    // float2 hitPixel = float2(0.0f, 0.0f);
    // float3 hitPoint = float3(0.0f, 0.0f, 0.0f);
    // 
    // float jitter = cb_stride > 1.0f ? float(int(pIn.posH.x + pIn.posH.y) & 1) * 0.5f : 0.0f;
    // 
    // // perform ray tracing - true if hit found, false otherwise
    // bool intersection = traceScreenSpaceRay(rayOriginVS, rayDirectionVS, jitter, hitPixel, hitPoint);
    // 
    // depth = depthBuffer.Load(int3(hitPixel, 0)).r;
    // 
    // // move hit pixel from pixel position to UVs
    // hitPixel *= float2(texelWidth, texelHeight);
    // if(hitPixel.x > 1.0f || hitPixel.x < 0.0f || hitPixel.y > 1.0f || hitPixel.y < 0.0f)
    // {
    // intersection = false;
    // }
    // 
    // return float4(hitPixel, depth, rDotV) * (intersection ? 1.0f : 0.0f);
    //}    
    
    //inline bool rayIntersectsDepthBF( float zA, float zB, float2 uv)
    //{
    //
    //    #ifdef HWDEPTH
    //    #endif
    //    float cameraZ = Linear01Depth( Sample2D( DepthBuffer, uv).r) * -cFarClipPS;	
    //    float backZ = Sample2D( BackFaceepthBuffer, uv).r * -cFarClipPS;
    //    
    //    return zB <= cameraZ && zA >= backZ - _PixelZSize;
    //}
    //
    //// Trace a ray in screenspace from rayOrigin (in camera space) pointing in rayDirection (in camera space)
    //// using jitter to offset the ray based on (jitter * _PixelStride).
    ////
    //// Returns true if the ray hits a pixel in the depth buffer
    //// and outputs the hitPixel (in UV space), the hitPoint (in camera space) and the number
    //// of iterations it took to get there.
    ////
    //// Based on Morgan McGuire & Mike Mara's GLSL implementation:
    //// http://casual-effects.blogspot.com/2014/08/screen-space-ray-tracing.html
    //inline bool traceScreenSpaceRay( float3 rayOrigin, 
    //                                float3 rayDirection,
    //                                float maxRayDistance,
    //                                float maxPixelStride,
    //                                float pixelStrideZCuttoff,
    //                                float jitter,
    //                                float numberIterations,
    //                                float2 oneDividedByRenderBufferSize,
    //                                out float2 hitPixel, 
    //                                out float3 hitPoint, 
    //                                out float iterationCount,
    //                                bool debugHalf) 
    //{
    //    // Clip to the near plane    
    //    float rayLength = ((rayOrigin.z + rayDirection.z * maxRayDistance) > -cNearClipPS) ?
    //                    (-cNearClipPS - rayOrigin.z) / rayDirection.z : maxRayDistance;
    //    float3 rayEnd = rayOrigin + rayDirection * rayLength;
    //
    //    // Project into homogeneous clip space
    //    float4 H0 = mul( cViewProjPS, float4( rayOrigin, 1.0));
    //    float4 H1 = mul( cViewProjPS, float4( rayEnd, 1.0));
    //    
    //    float k0 = 1.0 / H0.w, k1 = 1.0 / H1.w;
    //
    //    // The interpolated homogeneous version of the camera-space points  
    //    float3 Q0 = rayOrigin * k0, Q1 = rayEnd * k1;
    //    
    //    // Screen-space endpoints
    //    float2 P0 = H0.xy * k0, P1 = H1.xy * k1;
    //    
    //    // If the line is degenerate, make it cover at least one pixel
    //    // to avoid handling zero-pixel extent as a special case later
    //    P1 += (distanceSquared(P0, P1) < 0.0001) ? 0.01 : 0.0;
    //    
    //    float2 delta = P1 - P0;
    //
    //    // Permute so that the primary iteration is in x to collapse
    //    // all quadrant-specific DDA cases later
    //    bool permute = false;
    //    if (abs(delta.x) < abs(delta.y)) { 
    //        // This is a more-vertical line
    //        permute = true; delta = delta.yx; P0 = P0.yx; P1 = P1.yx; 
    //    }
    //
    //    float stepDir = sign(delta.x);
    //    float invdx = stepDir / delta.x;
    //
    //    // Track the derivatives of Q and k
    //    float3  dQ = (Q1 - Q0) * invdx;
    //    float dk = (k1 - k0) * invdx;
    //    float2  dP = float2(stepDir, delta.y * invdx);
    //
    //    // Calculate pixel stride based on distance of ray origin from camera.
    //    // Since perspective means distant objects will be smaller in screen space
    //    // we can use this to have higher quality reflections for far away objects
    //    // while still using a large pixel stride for near objects (and increase performance)
    //    // this also helps mitigate artifacts on distant reflections when we use a large
    //    // pixel stride.
    //    float strideScaler = 1.0 - min( 1.0, -rayOrigin.z / pixelStrideZCuttoff);
    //    float pixelStride = 1.0 + strideScaler * maxPixelStride;
    //    
    //    // Scale derivatives by the desired pixel stride and then
    //    // offset the starting values by the jitter fraction
    //    dP *= pixelStride; dQ *= pixelStride; dk *= pixelStride;
    //    P0 += dP * jitter; Q0 += dQ * jitter; k0 += dk * jitter;
    //
    //    float i, zA = 0.0, zB = 0.0;
    //    
    //    // Track ray step and derivatives in a float4 to parallelize
    //    float4 pqk = float4( P0, Q0.z, k0);
    //    float4 dPQK = float4( dP, dQ.z, dk);
    //    bool intersect = false;
    //    
    //    for( i=0; i<numberIterations && intersect == false; i++)
    //    {
    //        pqk += dPQK;
    //        
    //        zA = zB;
    //        zB = (dPQK.z * 0.5 + pqk.z) / (dPQK.w * 0.5 + pqk.w);
    //        swapIfBigger( zB, zA);
    //        
    //        hitPixel = permute ? pqk.yx : pqk.xy;
    //        hitPixel *= oneDividedByRenderBufferSize;
    //        
    //        intersect = rayIntersectsDepthBF( zA, zB, hitPixel);
    //    }
    //    
    //    // Binary search refinement
    //    if( pixelStride > 1.0 && intersect)
    //    {
    //        pqk -= dPQK;
    //        dPQK /= pixelStride;
    //        
    //        float originalStride = pixelStride * 0.5;
    //        float stride = originalStride;
    //        
    //        zA = pqk.z / pqk.w;
    //        zB = zA;
    //        
    //        for( float j=0; j<_BinarySearchIterations; j++)
    //        {
    //            pqk += dPQK * stride;
    //            
    //            zA = zB;
    //            zB = (dPQK.z * -0.5 + pqk.z) / (dPQK.w * -0.5 + pqk.w);
    //            swapIfBigger( zB, zA);
    //            
    //            hitPixel = permute ? pqk.yx : pqk.xy;
    //            hitPixel *= oneDividedByRenderBufferSize;
    //            
    //            originalStride *= 0.5;
    //            stride = rayIntersectsDepthBF( zA, zB, hitPixel) ? -originalStride : originalStride;
    //        }
    //    }
    //
    //    
    //    Q0.xy += dQ.xy * i;
    //    Q0.z = pqk.z;
    //    hitPoint = Q0 / pqk.w;
    //    iterationCount = i;
    //            
    //    return intersect;
    //}

    //// By Morgan McGuire and Michael Mara at Williams College 2014
    //// Released as open source under the BSD 2-Clause License
    //// http://opensource.org/licenses/BSD-2-Clause
    //
    //// Ported to hlsl by Nyt0x
    //
    //// Returns true if the ray hit something
    //bool traceScreenSpaceRay1(
    // // Camera-space ray origin, which must be within the view volume
    // float3 csOrig, 
    // 
    // // Unit length camera-space ray direction
    // float3 csDir,
    // 
    // // Camera space thickness to ascribe to each pixel in the depth buffer
    // float zThickness, 
    // 
    // // Step in horizontal or vertical pixels between samples. This is a float
    // // because integer math is slow on GPUs, but should be set to an integer >= 1
    // float stride,
    // 
    // // Number between 0 and 1 for how far to bump the ray in stride units
    // // to conceal banding artifacts
    // float jitter,
    // 
    // // Maximum number of iterations. Higher gives better images but may be slow
    // const float maxSteps, 
    // 
    // // Maximum camera-space distance to trace before returning a miss
    // float maxDistance, 
    // 
    // // Pixel coordinates of the first intersection with the scene
    // out float2 hitPixel, 
    // 
    // // Camera space location of the ray hit
    // out float3 hitPoint) 
    // {
    // 
    //    // Clip to the near plane    
    //    float rayLength = ((csOrig.z + csDir.z * maxDistance) > cNearClipPS) ?
    //        (cNearClipPS - csOrig.z) / csDir.z : maxDistance;
    //    float3 csEndPoint = csOrig + csDir * rayLength;
    // 
    //    // Project into homogeneous clip space
    //    float4 H0 = mul(float4( csOrig, 1.0), cViewProjPS);
    //    float4 H1 = mul(float4( csEndPoint, 1.0), cViewProjPS);
    //    float k0 = 1.0 / H0.w, k1 = 1.0 / H1.w;
    // 
    //    // The interpolated homogeneous version of the camera-space points  
    //    float3 Q0 = csOrig * k0;
    //    float3 Q1 = csEndPoint * k1;
    // 
    //    // Screen-space endpoints
    //    float2 P0 = H0.xy * k0;
    //    float2 P1 = H1.xy * k1;
    // 
    //    // If the line is degenerate, make it cover at least one pixel
    //    // to avoid handling zero-pixel extent as a special case later
    //    P1 += (distanceSquared(P0, P1) < 0.0001) ? 0.01 : 0.0;
    //    float2 delta = P1 - P0;
    // 
    //    // Permute so that the primary iteration is in x to collapse
    //    // all quadrant-specific DDA cases later
    //    bool permute = false;
    //    if (abs(delta.x) < abs(delta.y)) 
    //    { 
    //        // This is a more-vertical line
    //        permute = true; delta = delta.yx; P0 = P0.yx; P1 = P1.yx; 
    //    }
    // 
    //    float stepDir = sign(delta.x);
    //    float invdx = stepDir / delta.x;
    // 
    //    // Track the derivatives of Q and k
    //    float3  dQ = (Q1 - Q0) * invdx;
    //    float dk = (k1 - k0) * invdx;
    //    float2  dP = float2(stepDir, delta.y * invdx);
    // 
    //    // Scale derivatives by the desired pixel stride and then
    //    // offset the starting values by the jitter fraction
    //    dP *= stride; dQ *= stride; dk *= stride;
    //    P0 += dP * jitter; Q0 += dQ * jitter; k0 += dk * jitter;
    // 
    //    // Slide P from P0 to P1, (now-homogeneous) Q from Q0 to Q1, k from k0 to k1
    //    float3 Q = Q0; 
    // 
    //    // Adjust end condition for iteration direction
    //    float  end = P1.x * stepDir;
    // 
    //    float k = k0, stepCount = 0.0, prevZMaxEstimate = csOrig.z;
    //    float rayZMin = prevZMaxEstimate, rayZMax = prevZMaxEstimate;
    //    float sceneZMax = rayZMax + 100;
    //    for (float2 P = P0; 
    //        ((P.x * stepDir) <= end) && (stepCount < maxSteps) &&
    //        ((rayZMax < sceneZMax - zThickness) || (rayZMin > sceneZMax)) &&
    //        (sceneZMax != 0); 
    //        P += dP, Q.z += dQ.z, k += dk, ++stepCount) 
    //        {
    //            rayZMin = prevZMaxEstimate;
    //            rayZMax = (dQ.z * 0.5 + Q.z) / (dk * 0.5 + k);
    //            prevZMaxEstimate = rayZMax;
    //            
    //            if (rayZMin > rayZMax) 
    //            { 
    //               float t = rayZMin; rayZMin = rayZMax; rayZMax = t;
    //            }
    //     
    //            hitPixel = permute ? P.yx : P;
    //            // You may need hitPixel.y = cRenderBufferSize.y - hitPixel.y; here if your vertical axis
    //            // is different than ours in screen space
    //            sceneZMax = Sample2DLod0(DepthBuffer, hitPixel / cRenderBufferSize);
    //            }
    //     
    //    // Advance Q based on the number of steps
    //    Q.xy += dQ.xy * stepCount;
    //    hitPoint = Q * (1.0 / k);
    //    return (rayZMax >= sceneZMax - zThickness) && (rayZMin < sceneZMax);
    //}

    #endif
#endif
