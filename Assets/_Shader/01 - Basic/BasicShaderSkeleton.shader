/*
struct appdata_base {
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct appdata_tan {
    float4 vertex : POSITION;
    float4 tangent : TANGENT;
    float3 normal : NORMAL;
    float4 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct appdata_full {
    float4 vertex : POSITION;
    float4 tangent : TANGENT;
    float3 normal : NORMAL;
    float4 texcoord : TEXCOORD0;
    float4 texcoord1 : TEXCOORD1;
    float4 texcoord2 : TEXCOORD2;
    float4 texcoord3 : TEXCOORD3;
    fixed4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
*/

// DataTypesAndPrecision
// https://docs.unity3d.com/Manual/SL-DataTypesAndPrecision.html
// float 32bits
// half 16 bits
// fixed 11 bits

Shader "roadtoshaderdog/BasicShaderSkeleton"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "" {}
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
        _FresnelColor("Fresnel Color", Color) = (1, 1, 1, 1)
        // fresnel pow
        [PowerSlider(4)]_FresnelExponent("Fresnel Exponent", Range(0.25, 4)) = 1
    }
    SubShader
    {
        Tags
        { 
            "RenderType"="Opaque" 
            "LightMode" = "ForwardBase"
        }
        LOD 100
        Pass
        {
            Cull Back
            ZTest LEqual

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // include other cg shader files
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityCG.cginc"

            // Structure from vertex shader to fragment shader
            /*
                appdata_base: position, normal and one texture coordinate.
                appdata_tan: position, tangent, normal and one texture coordinate.
                appdata_full: position, tangent, normal, four texture coordinates and color.
            */
            struct v2f
            {
                float4 vertex   : POSITION;
                float2 uv       : TEXCOORD0;
                float3 eyeDir   : TEXCOORD1;
                float3 lightDir : TEXCOORD2;
                float3 normal   : TEXCOORD3;
                float3 tangent  : TEXCOORD4;
                float3 binormal : TEXCOORD5;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormalMap;
            fixed4 _Specular;
            float _Gloss; 
            float _FresnelExponent;
            fixed4 _FresnelColor;

            // Macro define
            #define float_t half
            #define float2_t half2
            #define float3_t half3
            #define float4_t half4
            #define float3x3_t half3x3

            // vertex shader
            v2f vert (appdata_tan v)
            {
                v2f o;
                // Transforms a point from object space to the camera’s clip space in homogeneous coordinates. 
                // This is the equivalent of mul(UNITY_MATRIX_MVP, float4(pos, 1.0)), and should be used in its place.
                o.vertex = UnityObjectToClipPos(v.vertex);

                // vertex program uses the TRANSFORM_TEX macro from UnityCG.cginc to make sure texture scale and offset is applied correctly, 
                // and fragment program just samples the texture and multiplies by the color property.
                // // #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)
                // ST.XY : tilling
                // ST:ZW : offset
                // get right uv with tilling and offset
                o.uv = TRANSFORM_TEX(v.texcoord.xy, _MainTex);

                // input world normal
                // Current model matrix.(unity_ObjectToWorld)
                o.normal = normalize(mul(unity_ObjectToWorld, float4_t(v.normal, 0)).xyz);
                // unity_WorldToObject
                // Inverse of current world matrix.

                // o.eyeDir.xyz = normalize(_WorldSpaceCameraPos.xyz - worldPos.xyz).xyz;
                // same as using UnityWorldSpaceViewDir();
                float4_t worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.eyeDir.xyz = normalize(UnityWorldSpaceViewDir(worldPos));

                // Computes world space direction (not normalized) to light, given object space vertex position.
                // (worldlightpos - vertexworldpos)
                // o.lightDir = WorldSpaceLightDir( v.vertex );
                o.lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

                // Binormal and tangent(for normal map)
                // world space tangent
                o.tangent = normalize(mul(unity_ObjectToWorld, float4_t(v.tangent.xyz, 0)).xyz);
                // world space binormal
                // w for the sign
                // when need to * w or / w
                o.binormal = normalize(cross(o.normal, o.tangent) * v.tangent.w * unity_WorldTransformParams.w);
                return o;
            }

            // fragment shader
            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 diffSamplerColor = tex2D(_MainTex, i.uv);
                // return diffSamplerColor;
                // color [0,1]
                // map need to [-1,1]
                // sample tangent space normal ([0,1]===>[-1,1])
                // float3_t normalVec = normalize(tex2D(_NormalMap, i.uv).xyz * 2.0 - 1.0);
                float3_t normalVec = UnpackNormal(tex2D(_NormalMap, i.uv));
                // return fixed4(normalVec, 1.0);
                // TBN Matrix : convert tangent space normal(map) to world space
                float3x3_t localToWorldTranspose = float3x3_t(
                    i.tangent,
                    i.binormal,
                    i.normal
                );
                
                normalVec = normalize(mul(normalVec, localToWorldTranspose));
                // return fixed4(normalVec, 1.0);
                float3_t ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * diffSamplerColor;
                // A - B = A point towards B vector
                // 
                // In World Space (lighting calculation)
                // 

                // diffuse 
                // dot(viewdir, normaldir)
                float3_t diffuse = _LightColor0.rgb
                    * diffSamplerColor
                    * max(0, dot(normalVec, i.lightDir));
                
                // Blinn-Phong(more smooth)
                // fixed3 halfDir = normalize(i.lightDir + i.eyeDir);
                // fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(normalVec, halfDir)), _Gloss);
                
                // Phong-Mode
                fixed3 reflectDir = reflect(-i.lightDir, normalVec);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(i.eyeDir, reflectDir)), _Gloss);

                // fresnel 
                // the dot product between the surface normal and the view direction.
                // 1 - dot(viewdir, normaldir)
                // saturate = > value -> [0,1]
                float fresnel = dot(normalVec, i.eyeDir);
                fresnel = saturate(1.0 - fresnel);
                fresnel = pow(fresnel, _FresnelExponent);
                fixed3 fresnelColor = fresnel * _FresnelColor;

                // (ambient + diffuse + specular + fresnelColor)
                return fixed4(ambient + diffuse + specular + fresnelColor, 1.0);
            }
            ENDCG
        }
    }
}
