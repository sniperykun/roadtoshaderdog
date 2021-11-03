Shader "Unlit/TextureMapping"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [PowerSlider(1)]_factor("Lerp Factor", Range(0.0, 1.0)) = 0 
    	
		_LineColor ("LineColor", Color) = (1,1,1,1)
		_FillColor ("FillColor", Color) = (0,0,0,0)
		_WireThickness ("Wire Thickness", RANGE(0, 800)) = 100
		[MaterialToggle] UseDiscard("Discard Fill", Float) = 1
    	[PowerSlider(30)]_Scale("Scale", Range(1, 30)) = 10
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            Cull OFF
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _factor;
            float _Scale;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                float3 uvpos = float3(v.uv.x - 0.5, v.uv.y - 0.5, 0.0) * _Scale;
                float3 targetpos = lerp(uvpos, v.vertex, _factor);
                o.vertex = UnityObjectToClipPos(targetpos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            { 
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }

        
        Pass
		{
			// Wireframe shader based on the the following
			// http://developer.download.nvidia.com/SDK/10/direct3d/Source/SolidWireframe/Doc/SolidWireframe.pdf
			Tags
			{
				"RenderType"="Transparent"
				"Queue"="Transparent"
			}
			
			Cull off
			ZWrite off
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile _ USEDISCARD_ON
			#include "UnityCG.cginc"

			float _WireThickness;
            float _factor;
			float _Scale;
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2g
			{
				float4 projectionSpaceVertex : SV_POSITION;
				float4 worldSpacePosition : TEXCOORD1;
			};

			struct g2f
			{
				float4 projectionSpaceVertex : SV_POSITION;
				float4 worldSpacePosition : TEXCOORD0;
				float4 dist : TEXCOORD1;
			};

			
			v2g vert (appdata v)
			{
				v2g o;
				float3 uvpos = float3(v.uv.x - 0.5, v.uv.y - 0.5, 0.0) * _Scale;
                float3 targetpos = lerp(uvpos, v.vertex, _factor);
				
				o.projectionSpaceVertex = UnityObjectToClipPos(targetpos);
				o.worldSpacePosition = mul(unity_ObjectToWorld, targetpos);
				return o;
			}
			
			[maxvertexcount(3)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triangleStream)
			{
				float2 p0 = i[0].projectionSpaceVertex.xy / i[0].projectionSpaceVertex.w;
				float2 p1 = i[1].projectionSpaceVertex.xy / i[1].projectionSpaceVertex.w;
				float2 p2 = i[2].projectionSpaceVertex.xy / i[2].projectionSpaceVertex.w;

				float2 edge0 = p2 - p1;
				float2 edge1 = p2 - p0;
				float2 edge2 = p1 - p0;

				// To find the distance to the opposite edge, we take the
				// formula for finding the area of a triangle Area = Base/2 * Height, 
				// and solve for the Height = (Area * 2)/Base.
				// We can get the area of a triangle by taking its cross product
				// divided by 2.  However we can avoid dividing our area/base by 2
				// since our cross product will already be double our area.
				float area = abs(edge1.x * edge2.y - edge1.y * edge2.x);
				float wireThickness = 800 - _WireThickness;

				g2f o;
				o.worldSpacePosition = i[0].worldSpacePosition;
				o.projectionSpaceVertex = i[0].projectionSpaceVertex;
				o.dist.xyz = float3( (area / length(edge0)), 0.0, 0.0) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				triangleStream.Append(o);

				o.worldSpacePosition = i[1].worldSpacePosition;
				o.projectionSpaceVertex = i[1].projectionSpaceVertex;
				o.dist.xyz = float3(0.0, (area / length(edge1)), 0.0) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				triangleStream.Append(o);

				o.worldSpacePosition = i[2].worldSpacePosition;
				o.projectionSpaceVertex = i[2].projectionSpaceVertex;
				o.dist.xyz = float3(0.0, 0.0, (area / length(edge2))) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				triangleStream.Append(o);
			}

			uniform fixed4 _LineColor;
			uniform fixed4 _FillColor;

			fixed4 frag (g2f i) : SV_Target
			{
				float minDistanceToEdge = min(i.dist[0], min(i.dist[1], i.dist[2])) * i.dist[3];

				// Early out if we know we are not on a line segment.
				if(minDistanceToEdge > 0.9)
				{
				    #ifdef USEDISCARD_ON
						discard;
					#else
						return _FillColor;
					#endif
				}
				return _LineColor;
			}
			ENDCG
		}
    }
}