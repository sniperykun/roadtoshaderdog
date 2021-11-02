Shader "roadtoshaderdog/Custom-Lighting-Specular"
{
    //
    // Specular - Work - Flow - Shading
    // 
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
    
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Factor", Range(0.0, 1.0)) = 1.0
        [Enum(Specular Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        _SpecColor("Specular", Color) = (0.2,0.2,0.2)
        _SpecGlossMap("Specular", 2D) = "white" {}
        
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0

        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }
    
    CGINCLUDE
        // define something here
        // #define UNITY_SETUP_BRDF_INPUT SpecularSetup
    ENDCG

    SubShader
    {
        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "Custom-Lighting-FORWARD-Base"
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            
            CGPROGRAM

            // shader3.0 here
            #pragma target 3.0
            // shader keywords
            // use _local shader
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _NORMAL_MAP
            #pragma shader_feature _EMISSION_MAP
            #pragma shader_feature_local _DETAIL_MULX2
            // if smoothness saved in albedo's alpha
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            
            // specular workflow
            #pragma shader_feature_local _SPECGLOSSMAP
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF
            
            // #pragma multi_compile POINT SPOT DIRECTIONAL LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SCREEN SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING LIGHTPROBE_SH
            #pragma multi_compile_fwdbase
            //  DIRECTIONAL LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON SHADOWS_SCREEN SHADOWS_SHADOWMASK LIGHTMAP_SHADOW_MIXING LIGHTPROBE_SH
            #pragma vertex custom_vertexBase
            #pragma fragment custom_fragBase
            
            // #include "UnityCG.cginc"
            #include "Custom-Light-Core.cginc"
            
            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "Custom-Lighting-FORWARD-Add"
            Tags 
            {
                "LightMode" = "ForwardAdd"
            }
            Blend [_SrcBlend] One

            ZWrite Off
            ZTest LEqual
            
            CGPROGRAM
            #pragma target 3.0

            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _NORMAL_MAP
            #pragma shader_feature _EMISSION_MAP
            #pragma shader_feature_local _DETAIL_MULX2
            // if smoothness saved in albedo's alpha
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            
            // specular workflow
            #pragma shader_feature_local _SPECGLOSSMAP
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF
            // #pragma multi_compile DIRECTIONAL POINT SPOT
            #pragma multi_compile_fwdadd_fullshadows

            #pragma vertex custom_vertAdd
            #pragma fragment custom_fragAdd
            
            // #include "UnityCG.cginc"
            #include "Custom-Light-Core.cginc"
            ENDCG
        }
        
         // pass for shadow caster
        Pass
        {
            Name "Make-Shadow-Happen"
            Tags{"LightMode" = "ShadowCaster"}
            CGPROGRAM
            #pragma vertex vert
			#pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
	            float4 position : POSITION;
            };

            float4 vert (appdata v) : SV_POSITION
            {
	            float4 position = UnityObjectToClipPos(v.position);
                // return position;
                // need apply shadow bias offset
                return UnityApplyLinearShadowBias(position);
            }
            half4 frag () : SV_TARGET
            {
	            return 0;
            }
            ENDCG
        }
    }
    // FallBack "VertexLit"
    CustomEditor "CustomLightingInspector"
}
