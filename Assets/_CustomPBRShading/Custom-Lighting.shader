Shader "roadtoshaderdog/Custom-Lighting"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
    
        _CutOff("Alpha CutOff", Range(0.0, 1.0)) = 0.5
        
        [Normal][NoScaleOffset]_NormalMap("Normal", 2D) = "bump" {}
        _BumpScale("Bump Scale", Float) = 1
        
        [NoScaleOffset] _MetallicMap("Metallic", 2D) = "white" {}
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.1

        [NoScaleOffset]_OcclusionMap("Occlusion", 2D) = "white" {}
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        
        [NoScaleOffset] _EmissionMap("Emission", 2D) = "black"{}
        _EmissionColor("Color", Color) = (0, 0, 0)
        
        [NoScaleOffset] _DetailMask("Detail Mask", 2D) = "white" {}
		_DetailTex ("Detail Albedo", 2D) = "gray" {}
        [NoScaleOffset][Normal] _DetailNormalMap("Detail Normal", 2D) = "bump" {}
        _DetailBumpScale("Detail Bump Scale", Float) = 1
        
        // Blend State
        [HideInInspector] _SrcBlend("__src", Float) = 0.0
        [HideInInspector] _DstBlend("__dst", Float) = 1.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
    }
    
    CGINCLUDE
    ENDCG

    SubShader
    {
        Pass
        {
            Name "Custom-Lighting-FORWARD"
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            // blend command
            Blend [_SrcBlend] [_DstBlend]
            // zwrite command
            ZWrite [_ZWrite]
            
            CGPROGRAM

            // shader3.0 here
            #pragma target 3.0
            // shader keywords
            #pragma shader_feature _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _OCCLUSION_MAP
            #pragma shader_feature _EMISSION_MAP
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            #pragma shader_feature _DETAIL_NORMAL_MAP
            
            #pragma vertex vertexBase
            #pragma fragment fragBase 

            #define CUSTOM_FORWARD_BASE_PASS
            #define VERTEX_LIGHT_ON
            #define _NORMAL_MAP
            #define _DETAIL_NORMAL_MAP

            #include "UnityCG.cginc"
            #include "Custom-Light-Core.cginc"
            ENDCG
        }
    }
}
