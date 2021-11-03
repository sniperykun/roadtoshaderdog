Shader "roadtoshaderdog/effect/ObjectCutOut"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _EdgeFactor("Edge Factor", Range(-2,2)) = 0.5
        _EdgeSpreadFactor("Spread Factor",Range(-2,2)) = 1
        _EdgeColor("Edge Color", Color) = (1, 0, 0, 1)
    }
    SubShader
    {
        Tags 
        { 
            "Queue" = "Geometry"
        }
        LOD 100
        Cull Off
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
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 objectPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _EdgeColor;
            float _EdgeFactor;
            float _EdgeSpreadFactor;

            v2f vert (appdata v)
            {
                v2f o;
                o.objectPos = v.vertex.xyz;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            void Unity_Remap_float(float In, float2 InMinMax, float2 OutMinMax, out float Out)
            {
                Out = OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                float f = step(_EdgeFactor, i.objectPos.x);

                float fvalue = 0;
                Unity_Remap_float(_EdgeSpreadFactor, float2(0, 1), float2(0, -0.5), fvalue);
                fvalue += _EdgeFactor;
                
                float fff = smoothstep(i.objectPos.x, _EdgeFactor, fvalue);
                fff = 1 - fff;
                clip(f - 0.01);
                return fff * _EdgeColor + col;
            }
            ENDCG
        }
    }
}
