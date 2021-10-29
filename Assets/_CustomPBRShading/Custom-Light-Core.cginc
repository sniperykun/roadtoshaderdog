#ifndef CUSTOM_LIGHT_CORE
#define CUSTOM_LIGHT_CORE

#include "UnityLightingCommon.cginc"

// Custom Light Input
half4       _Color;
half        _Cutoff;

sampler2D   _MainTex;
float4      _MainTex_ST;

sampler2D   _DetailAlbedoMap;
float4      _DetailAlbedoMap_ST;

sampler2D   _BumpMap;
half        _BumpScale;

sampler2D   _DetailMask;
sampler2D   _DetailNormalMap;
half        _DetailNormalMapScale;

sampler2D   _SpecGlossMap;
sampler2D   _MetallicGlossMap;
half        _Metallic;
float       _Glossiness;
float       _GlossMapScale;

sampler2D   _OcclusionMap;
half        _OcclusionStrength;

sampler2D   _ParallaxMap;
half        _Parallax;
half        _UVSec;

half4       _EmissionColor;
sampler2D   _EmissionMap;

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
    float3 lightDir  : TEXCOORD5;
    // per-vertex color calculate
    #if defined(VERTEX_LIGHT_ON)
    float3 vertexLightColor : TEXCOORD6;
    #endif
};

// detail mask saved in alpha channel
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
    return normalize(half3(n1.xy + n2.xy, n1.z * n2.z));
}

fixed3 GetAlbedo(VertexToFragmentData i)
{
    fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color;
    #ifndef _DETAIL_ALBEDO_MAP
        fixed3 details = tex2D(_DetailAlbedoMap, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

float GetAlpha(VertexToFragmentData i)
{
    float alpha = _Color.a;
    #if !defined(_SMOOTHNESS_ALBEDO)
        alpha *= tex2D(_MainTex, i.uv.xy).a;
    #endif
}

// get tangent space normal(normal map sampler)
float3 GetTangentSpaceNormal(VertexToFragmentData i)
{
    float3 normal = float3(0, 0, 1);
    #ifdef _NORMAL_MAP
        normal = UnpackNormalWithScale(tex2D(_BumpMap, i.uv.xy), _BumpScale);
    #endif
    
    #ifdef _DETAIL_NORMAL_MAP
        float3 detailNormal = UnpackNormalWithScale(tex2D(_DetailNormalMap, i.uv.zw), _DetailNormalMapScale);
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
    float smoothness = 1;
    #if defined(_SMOOTHNESS_ALBEDO)
        smoothness = tex2D(_MainTex, i.uv.xy).a;
    #elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
        smoothness = tex2D(_METALLIC_MAP, i.uv.xy).a;
    #endif
    return 1.0;
    // return smoothness * _sm;
}

// save occ in AO's alpha
float GetOcclusion(VertexToFragmentData i)
{
    #if defined(_OCCLUSION_MAP)
        return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
    #else
        return 1;
    #endif
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
// use TBN Matrix
void CalculateFragmentWorldNormal(inout VertexToFragmentData i)
{
    float3 tangentSpaceNormal = GetTangentSpaceNormal(i);
    float3 binormal = i.binormal;
    half3 worldNormal;

    // method 1
    worldNormal = normalize(
        tangentSpaceNormal.x * i.tangent +
        tangentSpaceNormal.y * binormal +
        tangentSpaceNormal.z * i.normal
    );

    // method 2
    // TBN matrix
    // 按照行存储!!!!!!!ROW
    // https://developer.download.nvidia.com/cg/mul.html
    // first row : i.tangent
    // second row : i.binormal
    // third row : i.normal
    /*
    half3x3 transposeToWorld = half3x3(
        i.tangent,
        i.binormal,
        i.normal
    );
    worldNormal = normalize(mul(tangentSpaceNormal, transposeToWorld));
    worldNormal = normalize(mul(transpose(transposeToWorld), tangentSpaceNormal));
    */

    // method 3
    /*
    float3 vff01 = float3(i.tangent.x, i.binormal.x, i.normal.x);
    float3 vff02 = float3(i.tangent.y, i.binormal.y, i.normal.y);
    float3 vff03 = float3(i.tangent.z, i.binormal.z, i.normal.z);
                
    worldNormal.x = dot(vff01, tangentSpaceNormal);
    worldNormal.y = dot(vff02, tangentSpaceNormal);
    worldNormal.z = dot(vff03, tangentSpaceNormal);
    */
    
    i.normal = worldNormal;
}

// vertex function
VertexToFragmentData custom_vertexBase(VertexInputData v)
{
    VertexToFragmentData o;
    o.pos = UnityObjectToClipPos(v.vertex);
    
    o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    o.uv.zw = TRANSFORM_TEX(v.uv, _DetailAlbedoMap);

    o.tangent.xyz = UnityObjectToWorldDir(v.tangent.xyz);
    o.normal = UnityObjectToWorldNormal(v.normal);
    half binormalsign = v.tangent.w * unity_WorldTransformParams.w;
    o.binormal = normalize(cross( o.normal, o.tangent.xyz)) * binormalsign;
    o.worldPosition = mul(unity_ObjectToWorld, v.vertex);
    o.lightDir = normalize(UnityWorldSpaceLightDir(o.worldPosition));
    return o;
}

// fragment shading
fixed4 custom_fragBase(VertexToFragmentData i) : SV_Target
{
    fixed3 albedo = GetAlbedo(i);
    CalculateFragmentWorldNormal(i);
    float3 diffuse = _LightColor0.rgb * albedo * max(0, dot(i.normal, i.lightDir));
    return fixed4(diffuse, 1.0);
}

#endif
