Shader "roadtoshaderdog/island/PalmLeaf"
{
    Properties
    {
        _DarkColor("Drak Color", Color) = (1, 1, 1, 1)
        _LightColor("Light Color", Color) = (1, 1, 1, 1)
        _WindSpeed("Wind Speed", Vector) = (-0.2, -0.1, 0)
        _WindStrength("Wind Strength", Float) = 0.5
        _WindDensity("Wind Desity", Float) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Pass
        {
            Blend One Zero
            Cull Off
            ZTest LEqual
            ZWrite On

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            // leaf lerp color [dark color - light color]
            float4 _DarkColor;
            float4 _LightColor;
            float2 _WindSpeed;
            float _WindStrength;
            float _WindDensity;

            void Unity_TilingAndOffset_float(float2 UV, float2 Tiling, float2 Offset, out float2 Out)
            {
                Out = UV * Tiling + Offset;
            }

            float2 unity_gradientNoise_dir(float2 p)
            {
                // Permutation and hashing used in webgl-nosie goo.gl/pX7HtC
                p = p % 289;
                float x = (34 * p.x + 1) * p.x % 289 + p.y;
                x = (34 * x + 1) * x % 289;
                x = frac(x / 41) * 2 - 1;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }
            
            float unity_gradientNoise(float2 p)
            {
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(unity_gradientNoise_dir(ip), fp);
                float d01 = dot(unity_gradientNoise_dir(ip + float2(0, 1)), fp - float2(0, 1));
                float d10 = dot(unity_gradientNoise_dir(ip + float2(1, 0)), fp - float2(1, 0));
                float d11 = dot(unity_gradientNoise_dir(ip + float2(1, 1)), fp - float2(1, 1));
                fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                float2 ff = float2(worldPos.x, worldPos.y);
                float2 offset = _Time.y.xx * _WindSpeed;

                float2 outvalue;
                Unity_TilingAndOffset_float(ff, float2(1, 1), offset, outvalue);
                float fnoise = unity_gradientNoise(outvalue * _WindDensity);    
                fnoise *= _WindStrength;

                float xoffset = worldPos.x + fnoise;
                float3 finworldPos = float3(xoffset, worldPos.y, worldPos.z);
                float lerpvalue = 1.0 - v.uv.x;
                float3 position = lerp(worldPos, finworldPos, lerpvalue);
                
                o.vertex = UnityWorldToClipPos(float4(position, v.vertex.w));
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // get diffuse color for leaf
                float u = (1.0 - i.uv.x) * 0.2;
                float v = i.uv.y;
                float lerpvalue = u * v * 2;
                fixed3 diffuse = lerp(_DarkColor, _LightColor, lerpvalue);
                diffuse *= _LightColor0.rgb; 
                fixed4 col = fixed4(diffuse, 1.0);

                return col;
            }
            ENDCG
        }
    }
}
