Shader "roadtoshaderdog/lighting/BasicLightMode"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _AlbedoColor("Albedo Color", Color) = (1, 1, 1, 1)
        _NormalMap("Normal", 2D) = "bump" {}
        _SpecularTex("Specular", 2D) = "white" {}
        _Gloss("Gloss", Float) = 1.0
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex   : POSITION;
                float2 uv       : TEXCOORD0;
                float3 eyeDir   : TEXCOORD1;
                float3 lightDir : TEXCOORD2;
                float3 normal   : TEXCOORD3;
                float3 tangent  : TEXCOORD4;
                float3 binormal : TEXCOORD5;
                // half3 worldPos  : TEXCOORD6;
            };

            sampler2D _MainTex;
            sampler2D _NormalMap;
            sampler2D _SpecularTex;
            half3 _SpecularColor;
            half3 _AlbedoColor;
            half _Gloss;
            
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                o.normal = UnityObjectToWorldNormal(v.normal);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.eyeDir = normalize(UnityWorldSpaceViewDir(worldPos));
                // o.worldPos = worldPos;
                // Directional lights[_WorldSpaceLightPos0]
                o.lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
                
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                // we create binormal in vertex shader
                o.binormal = cross(o.normal, o.tangent.xyz) * tangentSign;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                half3 normalVec = UnpackNormal(tex2D(_NormalMap, i.uv));
                float3x3 tangentSpaceToWorldSpace = float3x3(
                    i.tangent,
                    i.binormal,
                    i.normal);
                
                // convert normal texture's normal rotate to world normal
                normalVec = normalize(mul(normalVec, tangentSpaceToWorldSpace));
                fixed3 diffuseColor = tex2D(_MainTex, i.uv);
                diffuseColor = _LightColor0.rgb
                    * diffuseColor
                    * max(0, dot(normalVec, i.lightDir))
                    * _AlbedoColor;

                // SKY_BOX_COLOR REFLECTION
                // Specular
                // No need to calculate viewdir and lightdir in fragment shader
                // calculate in vertex shader
                // half3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                // half3 lightDir= normalize(UnityWorldSpaceLightDir(i.worldPos));

                half3 viewDir = i.eyeDir;
                half3 lightDir = i.lightDir;

                fixed3 reflectdir = reflect(-lightDir, normalVec);
                float spevalue = pow(saturate(dot(viewDir, reflectdir)), _Gloss);
                half4 specularSamplercolor = tex2D(_SpecularTex, i.uv);
                // specular saved in alpha channel
                half3 specularcolor = half3(specularSamplercolor.a, specularSamplercolor.a, specularSamplercolor.a);
                // return fixed4(specularcolor, 1.0);
                specularcolor = specularcolor * _SpecularColor * spevalue;
                return fixed4(diffuseColor + specularcolor, 1.0);
                return fixed4(diffuseColor, 1.0);
            }
            ENDCG
        }
    }
}
