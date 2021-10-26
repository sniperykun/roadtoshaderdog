Shader "roadtoshaderdog/island/Flag"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RadialPush("Radia Push", Float) = 0
        _SineFrequency("Sine Frequency", Float) = 1.0
        _SineSpeed("Sine Speed", Float) = 4.0
        _SineAmplitude("Sine Amplitude", Float) = 1.0
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

            float _RadialPush;
            float _SineFrequency;
            float _SineSpeed;
            float _SineAmplitude;

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
                float inputx = objPos.x;
                float f = inputx * _SineFrequency;
                float f2 = _SineSpeed * _Time.y;
                float f3 = sin(f + f2) * (v.uv.x) * _SineAmplitude;

                // make offset
                // f3 = mathlab_sineWave(x, _SineFrequency, _SineAmplitude, _SineSpeed, _Time.y) * saturate((v.uv.x - 0.1));
                // sine wave [smaller ----> bigger]
                f3 = mathlab_sineWave(inputx, _SineFrequency, _SineAmplitude, _SineSpeed, _Time.y) * v.uv.x;
                objPos.z += f3;

                // f(x) = (1 - x) * x
                float f4 = ( 1.0 - v.uv.y) * v.uv.y;
                f4 *= _RadialPush;
                objPos.x += f4;

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