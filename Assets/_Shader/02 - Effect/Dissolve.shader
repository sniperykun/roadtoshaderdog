Shader "roadtoshaderdog/effect/Dissolve"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DissolveColor("Dissolve Color", Color) = (1,1,1,1)
        _DissolveInput("Dissolve Input", 2D) = "white" {}
        _DissolveFactor("Dissolve Factor Value", Float) = 1.0
        _DissolveSpread("Dissolve Spread Value", Range(0, 0.5)) = 0.05
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
            fixed4 _DissolveColor;
            float _DissolveFactor;
            float _DissolveSpread;
            sampler2D _DissolveInput;

            v2f vert (appdata v)
            {
                v2f o;
                o.objectPos = v.vertex.xyz;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed a = tex2D(_DissolveInput, i.uv);
                fixed f = step(_DissolveFactor, a);
                fixed f2 = step(_DissolveFactor - _DissolveSpread, a);

                fixed f3 = f2 - f;
                // clip(f3 - 0.0001);
                clip(f2 - 0.0001);
                return fixed4(f3 * _DissolveColor + col);
                return col;
            }
            ENDCG
        }
    }
}
