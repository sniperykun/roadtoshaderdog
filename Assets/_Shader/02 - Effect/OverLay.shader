Shader "roadtoshaderdog/effect/OverLay"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OverLayTex("OverLay" , 2D) = "white" {}
        _LerpFactor("Lerp Factor", Range(0, 1)) = 0.5
        _Speed("Over Speed", Float) = 1.2
        _EdgeColor("Edge Color", Color) = (1, 0, 0, 1)

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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _OverLayTex;
            float _LerpFactor;
            float _Speed;
            float4 _MainTex_ST;
            float4 _EdgeColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                float2 uv2 = v.uv * float2(1.0, 1.0) + float2(0.0, _Time.y * _Speed);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv2 = uv2;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 overlay = tex2D(_OverLayTex, i.uv2);

                // if return lerp
                // return lerp(col, overlay, _LerpFactor);

                // just add lighting
                float f = smoothstep(0.1, 1, overlay.r);
                return _EdgeColor * f + col;
            }
            ENDCG
        }
    }
}
