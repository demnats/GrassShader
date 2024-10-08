Shader "Unlit/Grass"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _PlayerPosition("Player Position" , Vector) = (0,0,0,0)
        _Radius("Radius", float) = 1.0
        _EffectStrenght("Effect Strength", float) = 0.1
        _FadeAmount("Fade", float) = 1.0
        _MaxHeight("Max Height", float) = 0.5
        _GreenThreshold("Green Threshold", Range(0.0, 1.0)) = 0.5
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" }
            LOD 100

            Pass
            {
                            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma geometry geo

            #include "UnityCG.cginc"
            #include "Autolight.cginc"
            #include "Shaders/CustomTessellation.cginc"



            fixed4 _Color;
            float4 _PlayerPosition;
            float _Radius;
            float _EffectStrenght;
            float _FadeAmount;
            float _MaxHeight;
            float _GreenThreshold;
            float3 grassPos;

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
                float4 worldPos : TEXCOORD1;
            };
            float GetRandomFloat(float2 seed)
            {
                float random = (frac(sin(dot(seed, float2(12.9898, 78.233) * 2.0)) * 43758.5453));
                    return random;
            }

             v2f vert(appdata v)
             {
                 v2f o;
                 float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                 o.vertex = UnityObjectToClipPos(worldPos);
                 o.worldPos = worldPos;
                 o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                 return o;
             }

             struct geometryOutput
             {
                 float4 pos : SV_POSITION;
                 float4 worldPos : TEXCOORD1;
             };

             [maxvertexcount(3)]
             void geo(triangle float4 IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
             {
                 //float3 pos = IN[0];
                 geometryOutput o;
                 float3 worldPos = mul(unity_ObjectToWorld, IN[0]).xyz;
                 o.worldPos = float4(worldPos, 1.0);


                 o.pos = UnityObjectToClipPos(worldPos + float3(0.5, 0, 0));
                 triStream.Append(o);

                 o.pos = UnityObjectToClipPos(worldPos + float3(-0.5, 0, 0));
                 triStream.Append(o);

                 o.pos = UnityObjectToClipPos(worldPos + float3(0, 1, 0));
                 triStream.Append(o);
             }

             fixed4 frag(v2f i) : SV_Target
             {
                 // sample the texture
                 fixed4 col = tex2D(_MainTex, i.uv);
             // apply fog
             UNITY_APPLY_FOG(i.fogCoord, col);
             return col;
             }
             ENDCG
         }
        }
}

