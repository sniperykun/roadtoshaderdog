Shader "roadtoshaderdog/island/PalmTree"
{
    Properties
    {
        _DarkColor("Drak Color", Color) = (1, 1, 1, 1)
        _LightColor("Light Color", Color) = (1, 1, 1, 1)
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
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            float4 _DarkColor;
            float4 _LightColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float lerpvalue = i.uv.y;
                fixed3 diffuse = lerp(_DarkColor, _LightColor, lerpvalue) * _LightColor.rgb;
                fixed4 col = fixed4(diffuse, 1.0);
                return col;
            }
            ENDCG
        }
    }
}
