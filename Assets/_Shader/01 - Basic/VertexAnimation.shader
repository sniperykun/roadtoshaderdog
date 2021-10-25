Shader "roadtoshaderdog/vertexAnimation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        // wave movement frequency
        _Frequency("Wave Frequency", Range(1, 8)) = 2
        _Amplitude("Wave Amplitude", Range(0, 1)) = 0.5
        _Speed("Speed", Range(0, 5)) = 1
        _FresnelColor("Fresnel Color", Color) = (1, 1, 1, 1)
        // fresnel pow
        [PowerSlider(6)]_FresnelExponent("Fresnel Exponent", Range(0.25, 6)) = 1
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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 eyeDir   : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Frequency;
            float _Amplitude;
            float _Speed;
            float4 _FresnelColor;
            float _FresnelExponent;

            v2f vert (appdata v)
            {
                v2f o;
                // make vertex animation with sin(x+time)
                float4 pos = v.vertex;
                pos.y += sin(v.vertex.x * _Frequency + _Time.y * _Speed) * _Amplitude;
                o.vertex = UnityObjectToClipPos(pos);
                float4 worldPos = mul(unity_ObjectToWorld, pos);
                o.eyeDir.xyz = normalize(UnityWorldSpaceViewDir(worldPos));
                o.normal = normalize(mul(unity_ObjectToWorld, fixed4(v.normal, 0)).xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                float fresnel = dot(i.eyeDir, i.normal);
                fresnel =saturate( 1.0 - fresnel);
                fixed4 fresnelcolor = pow(fresnel, _FresnelExponent) * _FresnelColor;
                return col + fresnelcolor;
            }
            ENDCG
        }
    }
}
