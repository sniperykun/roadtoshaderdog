// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Snow"
{
    Properties
    {
        _Color ("Main Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _SpecularPower("Specular Power", Range(0,1)) = 0
        _SpecularRange("Specular Gloss", Range(1,10)) = 0
        _Normal ("Normal Map", 2D) = "bump" {}
        _NormalStrength("NormalStrength", Range(0,1)) = 0

        _ColorSnow("Snow Ambient Color", Color) = (0.05,0.5,0.05,1)
        _SpecularPower2 ("Snow Specular Power", Range(0.0, 1.0)) = 10
        _SpecularRange2 ("Snow Specular Range", Range(1.0, 50.0)) = 10
        _SpecularColor2("Snow Specular Color", Color) = (1,1,1,1)
        _normalMap2("Snow Normal / Spec (A)", 2D) = "bump" {}
        _NormalStrength2("NormalStrength2", Range(0,1)) = 0
        _blendPower ("Snow Blend Sharpness", Range(1.0, 10.0)) = 5
        _blendOffset ("Snow Blend Offset", Range(-1.0, 1.0)) = 0.5
        _blendMap("Blend Mask", 2D) = "black" {}
        _blendMapPower ("Snow Blend Map Power", Range(0.0, 1.0)) = 5
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "Queue"="Geometry"
        }
        Pass
        {
            Name "FORWARD"
            Tags
            {
                "LightMode"="ForwardBase"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile_fog
            #pragma target 3.0

            float4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _SpecularColor;
            float _SpecularPower;
            float _SpecularRange;
            sampler2D _Normal;
            float4 _Normal_ST;
            float _NormalStrength;


            float4 _ColorSnow;
            float _SpecularPower2;
            float _SpecularRange2;
            float3 _SpecularColor2;
            sampler2D _normalMap2;
            float4 _normalMap2_ST;
            float _NormalStrength2;
            float _blendPower;
            float _blendOffset;
            sampler2D _blendMap;
            float4 _blendMap_ST;
            float _blendMapPower;

            struct VertexInput
            {
                float4 vertex : POSITION; //local vertex position
                float3 normal : NORMAL; //normal direction
                float4 tangent : TANGENT; //tangent direction    
                float2 texcoord0 : TEXCOORD0; //uv coordinates
                float2 texcoord1 : TEXCOORD1; //lightmap uv coordinates
                fixed4 color : COLOR;
            };

            struct VertexOutput
            {
                float4 pos : SV_POSITION; //screen clip space position and depth
                float2 uv0 : TEXCOORD0; //uv coordinates
                float2 uv1 : TEXCOORD1; //lightmap uv coordinates

                //below we create our own variables with the texcoord semantic. 
                float3 normalDir : TEXCOORD2; //normal direction   
                float3 posWorld : TEXCOORD3; //normal direction   
                float4 color : TEXCOORD4;
                half3 tangentDir : TEXCOORD5;
                half3 bitangentDir : TEXCOORD6;
                LIGHTING_COORDS(7, 8) //this initializes the unity lighting and shadow
                UNITY_FOG_COORDS(9) //this initializes the unity fog
            };

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                o.uv0 = v.texcoord0;
                o.uv1 = v.texcoord1;
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.tangentDir = normalize(mul(unity_ObjectToWorld, half4(v.tangent.xyz, 0.0)).xyz);
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.color = v.color;
                UNITY_TRANSFER_FOG(o, o.pos);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }


            float4 frag(VertexOutput i) : COLOR
            {
                //SnowSetup-------------------------------
                float4 blendMask = -i.color * .5 + .5;
                float upMask = dot(fixed3(0, 1, 0), i.normalDir);
                float4 blendSample = tex2D(_blendMap, TRANSFORM_TEX(i.uv0, _blendMap));
                float upMaskMod = (upMask * lerp(0, blendSample.r, _blendMapPower)) + upMask;

                blendMask.r += ((upMaskMod + _blendOffset) * blendMask.r) * 2;

                upMask = (upMaskMod + _blendOffset) - blendMask.r;

                upMask = saturate(upMask);
                upMask = saturate(pow(upMask, _blendPower));


                //normal direction calculations
                float3 normalDir = normalize(i.normalDir);
                float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, normalDir);
                float3 normalMap = UnpackNormal(tex2D(_Normal,TRANSFORM_TEX(i.uv0, _Normal)));
                float3 normalDirection = lerp(float3(0.0h, 0.0h, 1.0h), normalMap, _NormalStrength);
                normalDirection = normalize(mul(normalDirection.rgb, tangentTransform));

                // snow normal direction
                float3 normalDirectionSnow = UnpackNormal(tex2D(_normalMap2, TRANSFORM_TEX(i.uv0, _normalMap2)));
                normalDirectionSnow = lerp(float3(0.0h, 0.0h, 1.0h), normalDirectionSnow, _NormalStrength2);
                normalDirectionSnow = normalize(mul(normalDirectionSnow.rgb, tangentTransform));

                // blend normal direction
                normalDirection = lerp(normalDirection, normalDirectionSnow, upMask);

                // diffuse color calculations lerped between snow and surface
                float3 mainTexColor = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));
                float3 diffuseColor = lerp(_Color.rgb * mainTexColor.rgb, _ColorSnow.rgb, upMask);

                //light calculations
                float3 lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz,
                                                       _WorldSpaceLightPos0.xyz - i.posWorld.xyz,
                                                       _WorldSpaceLightPos0.w));

                float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
                float3 halfDirection = normalize(viewDirection + lightDirection);
                float NdotL = max(0, dot(normalDirection, lightDirection));
                float NdotV = max(0, dot(normalDirection, halfDirection));

                // Specular calculations lerped between snow and surface
                float specularPowerTotal = lerp(_SpecularPower, _SpecularPower2, upMask);
                float specularRangeTotal = lerp(_SpecularRange, _SpecularRange2, upMask);
                float3 specularColorTotal = lerp(_SpecularColor, _SpecularColor2, upMask);
                float gloss = pow(NdotV, exp(specularRangeTotal)) * specularPowerTotal;
                float3 specularity = gloss * specularColorTotal.rgb;

                float3 lightingModel = NdotL * diffuseColor + specularity;
                float attenuation = LIGHT_ATTENUATION(i);
                float3 attenColor = attenuation * _LightColor0.rgb;

                float4 finalDiffuse = float4(lightingModel * attenColor, 1);
                UNITY_APPLY_FOG(i.fogCoord, finalDiffuse);
                return finalDiffuse;
            }
            ENDCG
        }
    }
    FallBack "Legacy Shaders/Diffuse"
}