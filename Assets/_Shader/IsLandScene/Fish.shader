Shader "roadtoshaderdog/island/Fish"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SineFrequency("Sine Frequency", Float) = 1.0
        _SineSpeed("Sine Speed", Float) = 4.0
        _SineAmplitude("Sine Amplitude", Float) = 1.0
        _WobbleMaskPower("Wobble Mask Power", Float) = 1.0
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
            #include "../CGMathLab.cginc"

            float _SineFrequency;
            float _SineSpeed;
            float _SineAmplitude;
            float _WobbleMaskPower;

            sampler2D _MainTex;
            float4 _MainTex_ST;

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
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                float3 objPos = v.vertex;

                // sine wave define in object space
                // https://en.wikipedia.org/wiki/Sine_wave
                // make local position sine wave care about the axis compare to Flag's shader
                // use UV's Mask gradient!!!

                // no-magic
                // float finput = objPos.z;
                // magic happened!!!
                float finput = objPos.z + objPos.y;
                // float f = finput * _SineFrequency;
                // float f2 = _SineSpeed * _Time.y;
                // float f3 = sin(f + f2) * _SineAmplitude;
                float f3 = mathlab_sineWave(finput, _SineFrequency, _SineAmplitude, _SineSpeed, _Time.y);
                float ff = objPos.x + f3;
                float3 calpos = float3(ff, objPos.y, objPos.z);
                objPos = lerp(objPos, calpos, pow(v.uv.x, _WobbleMaskPower));

                o.vertex = UnityObjectToClipPos(objPos);
                // #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 diffuse = tex2D(_MainTex, i.uv);
                return fixed4(diffuse);
            }
            ENDCG
        }
    }
}