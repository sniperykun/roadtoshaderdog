Shader "roadtoshaderdog/effect/Snow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SnowColor("Snow Color", Color) = (1,1,1,1)
        _SnowFactor("Snow Factor", Float) = 0.5
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
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _SnowColor;
            fixed _SnowFactor;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float3 up = float3(0.0, 1, 0);
                
                float f = dot(i.normal, up);
                f = step(_SnowFactor, f);

                return _SnowColor * f + col;
                return fixed4(f.xxx, 1.0);
                return col;
            }
            ENDCG
        }
    }
}
