#ifndef CUSTOM_LIGHT_CORE
#define CUSTOM_LIGHT_CORE

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"
#include "UnityCG.cginc"
#include "UnityGlobalIllumination.cginc"

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
    float2 uv1 : TEXCOORD1;
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
    float3 eyeDir : TEXCOORD5;
    half4 ambientOrLightmapUV : TEXCOORD6;    // SH or Lightmap UV
    SHADOW_COORDS(7)
    // per-vertex color calculate
    // #if defined(VERTEX_LIGHT_ON)
    // float3 vertexLightColor : TEXCOORD7;
    // #endif
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

half3 GetAlbedo(VertexToFragmentData i)
{
    half3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color;
    #ifndef _DETAIL_MULX2
        fixed3 details = tex2D(_DetailAlbedoMap, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

half4 GetSpecularGloss(VertexToFragmentData i)
{
    half4 sg;
    #ifdef _SPECGLOSSMAP
        #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
            sg.rgb = tex2D(_SpecGlossMap, i.uv.xy).rgb;
            sg.a = tex2D(_MainTex, i.uv.xy).a;
        #else
            sg = tex2D(_SpecGlossMap, i.uv.xy);
        #endif
        sg.a *= _GlossMapScale;
    #else
        sg.rgb = _SpecColor.rgb;
        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            sg.a = tex2D(_MainTex, i.uv.xy).a * _GlossMapScale;
        #else
            sg.a = _Glossiness;
        #endif
    #endif
    return sg;
}

half GetAlpha(VertexToFragmentData i)
{
    half alpha = _Color.a;
    #if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
        alpha *= tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
}

half GetOcclusion(VertexToFragmentData i)
{
    #if (SHADER_TARGET < 30)
        // SM20: instruction count limitation
        // SM20: simpler occlusion
        return tex2D(_OcclusionMap, i.uv.xy).g;
    #else
        half occ = tex2D(_OcclusionMap, i.uv.xy).g;
        return LerpOneTo (occ, _OcclusionStrength);
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

half3 GetEmission(VertexToFragmentData i)
{
    #ifndef _EMISSION_MAP
        return 0;
    #else
        return tex2D(_EmissionMap, i.uv.xy).rgb * _EmissionColor.rgb;
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

half3 GetLightDir(float3 worldPos)
{
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        return normalize(_WorldSpaceLightPos0.xyz - worldPos);
    #else
        return _WorldSpaceLightPos0.xyz;
    #endif
}

UnityLight MainLight(VertexToFragmentData i)
{
    UnityLight l;
    l.color = _LightColor0.rgb;
    l.dir = GetLightDir(i.worldPosition);
    return l;
}

UnityLight AdditiveLight(half3 lightdir, half atten)
{
    UnityLight l;
    l.color = _LightColor0.rgb;
    l.dir = lightdir;
    l.color *= atten;
    return l;
}

UnityIndirect ZeroIndirect ()
{
    UnityIndirect ind;
    ind.diffuse = 0;
    ind.specular = 0;
    return ind;
}

float3 NormalizedPerPixelNormal(float3 n)
{
    return normalize((float3)n);
}

// convert tangent space normal to world space normal
// use TBN Matrix
half3 PerPixelWorldNormal(VertexToFragmentData i)
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
    
    return worldNormal;
}

struct FragmentCommonData
{
    half3 diffColor;
    half3 specuColor;
    half oneMinusReflectivity;
    float3 normalWorld;
    float3 eyeVec;
    half alpha;
    half smoothness;
    float3 posWorld;
};

inline half4 VertexGIForward(VertexInputData data, float3 posWorld, half3 normalWorld)
{
    half4 ambientOrLightmapUV = 0;
    // Static lightmaps
    #ifdef LIGHTMAP_ON
        ambientOrLightmapUV.xy = data.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
        ambientOrLightmapUV.zw = 0;
        // Sample light probe for Dynamic objects only (no static or dynamic lightmaps)
    #elif UNITY_SHOULD_SAMPLE_SH
        #ifdef VERTEXLIGHT_ON
        // Approximated illumination from non-important point lights
        ambientOrLightmapUV.rgb = Shade4PointLights (
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, posWorld, normalWorld);
        #endif
    ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, ambientOrLightmapUV.rgb);
    #endif
    
    #ifdef DYNAMICLIGHTMAP_ON
    ambientOrLightmapUV.zw = data.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    return ambientOrLightmapUV;
}


// Diffuse/Spec Energy conservation
// Unity has a utility function to take care of the energy conservation
// StandardUtils.cginc
// inline half3 EnergyConservationBetweenDiffuseAndSpecular(half3 albedo, half3 specColor)
// {
// }

inline FragmentCommonData SpecularSetUp(VertexToFragmentData i)
{
    half4 specGloss = GetSpecularGloss(i);
    half3 specColor = specGloss.rgb;
    half smoothness = specGloss.a;

    half oneMinusReflectivity;
    half3 diffColor = EnergyConservationBetweenDiffuseAndSpecular(GetAlbedo(i), specColor, oneMinusReflectivity);
    
    FragmentCommonData o = (FragmentCommonData)0;
    o.diffColor = diffColor;
    o.specuColor = specColor;
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.smoothness = smoothness;
    return o;
}

inline FragmentCommonData FragmentSetUp(VertexToFragmentData i)
{
    half alpha = GetAlpha(i);
    #if defined(_ALPHATEST_ON)
        clip(alpha - _Cutoff);
    #endif
    FragmentCommonData o = SpecularSetUp(i);
    o.normalWorld  = PerPixelWorldNormal(i);
    o.posWorld = i.worldPosition;
    o.eyeVec = i.eyeDir;
    o.diffColor = PreMultiplyAlpha(o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
    return o;
}

/*
 * Unity3D standard shading sytem (foward-rendering path)
 * https://docs.unity3d.com/Manual/RenderTech-ForwardRendering.html
 */

// Used in ForwardBase pass: Calculates diffuse lighting from 4 point lights, with data packed in a special way.
// Shade4PointLights
// Used in Vertex pass: Calculates diffuse lighting from lightCount lights. Specifying true to spotLight is more expensive
// to calculate but lights are treated as spot lights otherwise they are treated as point lights.
// ShadeVertexLightsFull

// How to Structure Shader Code for different setup
// ------------------------------------------------------------------
//  Base forward pass (directional light, emission, lightmaps, ...)
//  forward-base pass

inline UnityGI FragmentGI(FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light, bool reflections)
{
    UnityGIInput d;
    d.light = light;
    d.worldPos = s.posWorld;
    d.worldViewDir = -s.eyeVec;
    d.atten = atten;

    #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        d.ambient = 0;
        d.lightmapUV = i_ambientOrLightmapUV;
    #else
        d.ambient = i_ambientOrLightmapUV.rgb;
        d.lightmapUV = 0;
    #endif

    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.probeHDR[1] = unity_SpecCube1_HDR;

    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
    d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
    #endif

    // https://docs.unity3d.com/ScriptReference/Rendering.BuiltinShaderDefine.UNITY_SPECCUBE_BOX_PROJECTION.html
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
        d.boxMax[0] = unity_SpecCube0_BoxMax;
        d.probePosition[0] = unity_SpecCube0_ProbePosition;
        d.boxMax[1] = unity_SpecCube1_BoxMax;
        d.boxMin[1] = unity_SpecCube1_BoxMin;
        d.probePosition[1] = unity_SpecCube1_ProbePosition;
    #endif

    // if reflections
    if(reflections)
    {
        // env data
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.smoothness, -s.eyeVec, s.normalWorld, s.specuColor);

        // Replace the reflUVW if it has been compute in Vertex shader. Note: the compiler will optimize the calcul in UnityGlossyEnvironmentSetup itself
        #if UNITY_STANDARD_SIMPLE
            g.reflUVW = s.reflUVW;
        #endif
        
        return UnityGlobalIllumination(d, occlusion, s.normalWorld, g);
    }
    else
    {
        return UnityGlobalIllumination (d, occlusion, s.normalWorld);
    }
}

inline UnityGI FragmentGI(FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light)
{
    return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, true);
}

half4 OutputForward(half4 output, half alphaFromSurface)
{
    #if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
        output.a = alphaFromSurface;
    #else
        UNITY_OPAQUE_ALPHA(output.a);
    #endif
    return output;
}

// vertex shading function
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
    // input vertex color or lightmap uv
    o.ambientOrLightmapUV = VertexGIForward(v, o.worldPosition, o.normal);
    // camera  point to vertex world position
    o.eyeDir.xyz = normalize(o.worldPosition - _WorldSpaceCameraPos);

    TRANSFER_SHADOW(o);
    return o;
}

half4 fragForward_BasePass_Internal(VertexToFragmentData i)
{
    FragmentCommonData s = FragmentSetUp(i);
    
    UnityLight mainLight = MainLight(i);
    // output light fall-off
    // Light Attenuation (POINT, SPOT, DIRECTIONAL) with different light type
    // https://docs.unity3d.com/Manual/ProgressiveLightmapper-CustomFallOff.html
    // https://en.wikipedia.org/wiki/Inverse-square_law
    // https://www.sciencedirect.com/topics/engineering/inverse-square-law
    // https://learnopengl.com/Lighting/Light-casters
    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);
    half occlusion = GetOcclusion(i);

    ///////////////////// or debug output informations
    // atten
    // return fixed4(atten, 0.0, 0.0, 1.0);

    // diffuse
    // return fixed4(s.diffColor, 1.0);
    // 
    // smoothness
    // return fixed4(s.smoothness.rrr, 1.0);
    // 
    // oneMinusReflectivity
    // return fixed4(s.oneMinusReflectivity.rrr, 1.0);
    // 
    // specular
    // return fixed4(s.specuColor, 1.0);
    // 
    // occlusion
    // return fixed4(occlusion.rrr, 1.0);
    ///////////////////// for debug output informations
    // main light
    // return fixed4(mainLight.color, 1.0);

    UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
    
    half4 c = UNITY_BRDF_PBS(
        s.diffColor,
        s.specuColor,
        s.oneMinusReflectivity,
        s.smoothness,
        s.normalWorld,
        -s.eyeVec,
        gi.light,
        gi.indirect);

    c.rgb += GetEmission(i);
    return OutputForward(c, s.alpha);
}

// fragment shading function
fixed4 custom_fragBase(VertexToFragmentData i) : SV_Target
{
    return fragForward_BasePass_Internal(i);
}

// ------------------------------------------------------------------
//  Additive forward pass (one light per pass)
//  forward-add pass
half4 fragForward_AddPass_Internal(VertexToFragmentData i)
{
    FragmentCommonData s = FragmentSetUp(i);
    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

    // Get light dir with different light type
    half3 lightdir = GetLightDir(i.worldPosition);
    
    UnityLight light  = AdditiveLight(lightdir, atten);
    UnityIndirect noIndirect = ZeroIndirect();
    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specuColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);
    return OutputForward(c, s.alpha);
}

VertexToFragmentData custom_vert_AddPass(VertexInputData v)
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

    // camera  point to vertex world position
    o.eyeDir.xyz = normalize(o.worldPosition - _WorldSpaceCameraPos);

    TRANSFER_SHADOW(o);
    return o;
}

fixed4 custom_frag_AddPass(VertexToFragmentData i) : SV_Target
{
     return fragForward_AddPass_Internal(i);
}

#endif