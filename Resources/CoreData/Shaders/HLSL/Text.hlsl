#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float2 cShadowOffset;
uniform float4 cShadowColor;
uniform float4 cStrokeColor;

#else

#ifdef COMPILEPS
// D3D11 constant buffers
cbuffer CustomPS : register(b6)
{
    float2 cShadowOffset;
    float4 cShadowColor;
    float4 cStrokeColor;
}
#endif

#endif

struct VertexIn
{
    float4 Pos : POSITION;
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR0;
};

struct PixelIn
{
    float2 TexCoord : TEXCOORD0;
    float4 Color : COLOR0;
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
    Out.Color = In.Color;
    Out.TexCoord = In.TexCoord;
}

// See notes in GLSL shader
#if defined(COMPILEPS) && defined(SIGNED_DISTANCE_FIELD)
    float GetAlpha(float distance, float width)
    {
        return smoothstep(0.5 - width, 0.5 + width, distance);
    }

    // Comment this define to turn off supersampling
    #define SUPERSAMPLING
#endif


void PS(PixelIn In, out PixelOut Out)
{
#ifdef SIGNED_DISTANCE_FIELD
    Out.Color.rgb = In.Color.rgb;
    float distance = Sample2D(DiffMap, In.TexCoord).a;

    #ifdef TEXT_EFFECT_STROKE
        #ifdef SUPERSAMPLING
            float outlineFactor = smoothstep(0.5, 0.525, distance); // Border of glyph
            Out.Color.rgb = lerp(cStrokeColor.rgb, In.Color.rgb, outlineFactor);
        #else
            if (distance < 0.525)
                Out.Color.rgb = cStrokeColor.rgb;
        #endif
    #endif

    #ifdef TEXT_EFFECT_SHADOW
        if (Sample2D(DiffMap, In.TexCoord - cShadowOffset).a > 0.5 && distance <= 0.5)
            Out.Color = cShadowColor;
        #ifndef SUPERSAMPLING
        else if (distance <= 0.5)
            Out.Color.a = 0.0;
        #endif
        else
    #endif
        {
            float width = fwidth(distance);
            float alpha = GetAlpha(distance, width);

            #ifdef SUPERSAMPLING
                float2 deltaUV = 0.354 * fwidth(In.TexCoord); // (1.0 / sqrt(2.0)) / 2.0 = 0.354
                float4 square = float4(In.TexCoord - deltaUV, In.TexCoord + deltaUV);

                float distance2 = Sample2D(DiffMap, square.xy).a;
                float distance3 = Sample2D(DiffMap, square.zw).a;
                float distance4 = Sample2D(DiffMap, square.xw).a;
                float distance5 = Sample2D(DiffMap, square.zy).a;

                alpha += GetAlpha(distance2, width)
                       + GetAlpha(distance3, width)
                       + GetAlpha(distance4, width)
                       + GetAlpha(distance5, width);
            
                // For calculating of average correct would be dividing by 5.
                // But when text is blurred, its brightness is lost. Therefore divide by 4.
                alpha = alpha * 0.25;
            #endif

            Out.Color.a = alpha;
        }
#else
    #ifdef ALPHAMAP
        Out.Color.rgb = In.Color.rgb;
        Out.Color.a = In.Color.a * Sample2D(DiffMap, In.TexCoord).a;
    #else
        Out.Color = In.Color* Sample2D(DiffMap, In.TexCoord);
    #endif
#endif
}
