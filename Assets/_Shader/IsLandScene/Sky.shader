Shader "roadtoshaderdog/island/Sky"
{
    Properties
    {
        _LightColor("Light Color", Color) = (1, 1, 1, 1)
        _LightestColor ("Lightest Color", Color) = (1, 1, 1, 1)
        
        _DarkColor("Drak Color", Color) = (1, 1, 1, 1)
        _DarkestColor("Drakest Color", Color) = (1, 1 , 1, 1)
        
        _LightestColorStrength("Lightest Color Strength", Float) = 6
        _DarkestColorStrength("Darkest Color Strenght", Float) = 6
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
                float4 vertex : SV_POSITION;
            };

            float4 _DarkColor;
            float4 _DarkestColor;
            float4 _LightestColor;
            float4 _LightColor;
            float _LightestColorStrength;
            float _DarkestColorStrength;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float y = i.uv.y;
                float3 lerpwithdrak = lerp(_DarkColor, _LightColor, y);
                float lf = pow(y, _LightestColorStrength);
                lerpwithdrak = lerp(lerpwithdrak, _LightestColor, lf);
                
                float df = pow(1 - y, _DarkestColorStrength);
                lerpwithdrak = lerp(lerpwithdrak, _DarkestColor, df);
                return fixed4(lerpwithdrak, 1.0);
            }
            ENDCG
        }
    }
}