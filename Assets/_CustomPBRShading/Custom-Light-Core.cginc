#ifndef CUSTOM_LIGHT_CORE
#define CUSTOM_LIGHT_CORE

#include "UnityLightingCommon.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;
float4 _Color;

sampler2D _DetailTex;
float4 _DetailTex_ST;
sampler2D _DetailMask;

sampler2D _DetailNormalMap;
float _DetailBumpScale;

sampler2D _NormalMap;
float _BumpScale;

sampler2D _MetallicMap;
fixed _Metallic;
fixed _Smoothness;

sampler2D _OcclusionMap;
float _OcclusionStrength;

sampler2D _EmissionMap;
fixed3 _EmissionColor;

float _AlphaCutoff;

struct VertexInputData
{
    float4 vertex : POSITION;
    float4 tangent : TANGENT;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

// Interpolators
struct VertexToFragmentData
{
    float4 uv : TEXCOORD0;
    float4 pos : SV_POSITION;
    float3 normal : TEXCOORD1;
    float3 tangent : TEXCOORD2;
    float3 binormal : TEXCOORD3;
    float3 worldPosition : TEXCOORD4;

    // per-vertex color calculate
    #if defined(VERTEX_LIGHT_ON)
        float3 vertexLightColor : TEXCOORD5;
    #endif
};

// detail mask in alpha
float GetDetailMask(VertexToFragmentData i)
{
    #if defined(_DETAIL_MASK)
        return tex2D(_DetailMask, i.uv.xy).a;
    #else
        return 1;
    #endif
}

// in UnityStandardUtils.cginc
half3 BlendNormals(half3 n1, half3 n2)
{
    return normalize(half3(n1.xy + n2.xy, n1.z*n2.z));
}

float3 GetAlbedo(VertexToFragmentData i)
{
    
}

float GetAlpha(VertexToFragmentData i)
{
    
}

float3 GetTangentSpaceNormal(VertexToFragmentData i)
{
    float3 normal = float3(0, 0, 1);
    #ifdef _NORMAL_MAP
        normal = UnpackNormalWithScale(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    #endif
    
    #ifdef _DETAIL_NORMAL_MAP
        float3 detailNormal = UnpackNormalWithScale(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
        detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
        normal = BlendNormals(normal, detailNormal);
    #endif
    return normal;
}

// Save in R channel
float GetMetallic(VertexToFragmentData i)
{
    #ifdef _METALLIC_MAP
        return tex2D(_MetallicMap, i.uv.xy).r;
    #else
        return _Metallic;
    #endif
}

float GetSmoothness(VertexToFragmentData i)
{
    
}

float GetOcclusion(VertexToFragmentData i)
{
    
}

float3 GetEmission(VertexToFragmentData i)
{
    #ifdef CUSTOM_FORWARD_BASE_PASS
        #ifdef _EMISSION_MAP
            return tex2D(_EmissionMap, i.uv.xy) * _EmissionColor;
        #else
            return _EmissionColor;
        #endif
    #else
        return 0;
    #endif
}

/*
* The inout declaration combines both. The parameter's value will be initialized by the value supplied by the user,
* and its final value will be output
  The default if no qualifier is specific is in. 
 */

// Calculate lights in Single Pass
// https://en.wikibooks.org/wiki/GLSL_Programming/Unity/Multiple_Lights
// Used in ForwardBase pass: Calculates diffuse lighting from 4 point lights, with data packed in a special way.
void ComputeVertexLightColor(inout VertexToFragmentData i)
{
    #ifdef VERTEX_LIGHT_ON
    i.vertexLightColor = Shade4PointLights(
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb,
        unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, i.worldPosition, i.normal
        );
    #endif
}

// why here to get binormal(per-vertex)
float3 CreatePerVertexBinormal(float3 normal, float3 tangent, float binormalSign)
{
    // w is usually 1.0, or -1.0 for odd-negative scale transforms
    return cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);
}

// Simple Create UnityLight Struct
/*
*
*struct UnityLight
{
    half3 color;
    half3 dir;
    half  ndotl; // Deprecated: Ndotl is now calculated on the fly and is no longer stored. Do not used it.
}; 
 */

/*
*
* define in UnityStandardCore.cginc
UnityLight MainLight ()
{
    UnityLight l;
    l.color = _LightColor0.rgb;
    l.dir = _WorldSpaceLightPos0.xyz;
    return l;
}

how to check if Directional Light?


_WorldSpaceLightPos0---> Directional lights: (world space direction, 0). Other lights: (world space position, 1).

UnityWorldSpaceLightDir();

if (0.0 == _WorldSpaceLightPos0.w) // directional light??? old unity version???
{
} 
else // point or spot light
{
}
*/
UnityLight CreateLight(VertexToFragmentData i)
{
    // we can just return MainLight()
    // return MainLight();
    UnityLight light;
    // need to get UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
    light.color = _LightColor0.rgb; // * attenuation;
    light.dir = UnityObjectToWorldDir(i.worldPosition);
    // light.ndotl = DotClamped(light.dir, i.normal);
    return light;
}

// for reflection
float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{
    
}

// for indirect light
// UNITY_BRDF_PBS need use indirect light
UnityIndirect CreateIndirectLight(VertexToFragmentData i, float3 viewDir)
{
    
}

// convert tangent space normal to world space normal
void CalculateFragmentNormal(inout VertexToFragmentData i)
{
    float3 tangentSpaceNormal = GetTangentSpaceNormal(i);
    float3 binormal = i.binormal;
    i.normal = normalize(
        tangentSpaceNormal.x * i.tangent +
        tangentSpaceNormal.y * binormal +
        tangentSpaceNormal.z * i.normal
    );
}

// vertex function
VertexToFragmentData vertexBase (VertexInputData v)
{
    VertexToFragmentData o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    return o;
}

// fragment shading
fixed4 fragBase (VertexToFragmentData i) : SV_Target
{
    // sample the texture
    fixed4 col = tex2D(_MainTex, i.uv);
    return col;
}

#endif
