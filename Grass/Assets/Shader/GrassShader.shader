Shader "Unlit/Grass"
{
    Properties
    {
                [Header(Shading)]
        _TopColor("Top Color", Color) = (1,1,1,1)
        _BottomColor("Bottom Color", Color) = (1,1,1,1)
        _TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
        [Space]
        _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
        [Header(Blades)]
        _BladeWidth("Blade Width", Float) = 0.05
        _BladeWidthRandom("Blade Width Random", Float) = 0.02
        _BladeHeight("Blade Height", Float) = 0.5
        _BladeHeightRandom("Blade Height Random", Float) = 0.3
        _BladeForward("Blade Forward Amount", Float) = 0.38
        _BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
        [Header(Wind)]
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindStrength("Wind Strength", Float) = 1
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    }

            CGINCLUDE

            #include "UnityCG.cginc"
            #include "Autolight.cginc"
            #include "Shaders/CustomTessellation.cginc"



        struct geometryOutput
        {
            float4 pos : SV_POSITION;
#if UNITY_PASS_FORWARDBASE		//vraag
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0;
            // unityShadowCoord4 is defined as a float4 in UnityShadowLibrary.cginc.
            unityShadowCoord4 _ShadowCoord : TEXCOORD1;
#endif
        };

            //creat random number van 0 tot 1 
        float GetRandomFloat(float3 seed)
        {
            return frac(sin(dot(seed.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
        }

            //transform matrix die zorgt voor rotatie
            float3x3 AngleAxis3x3(float angle, float3 axis) 
            {
                float c, s;
                sincos(angle, s, c);

                float t = 1 - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;

                return float3x3(
                    t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                    t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                    t * x * z - s * y, t * y * z + s * x, t * z * z + c
                    );
            }

            geometryOutput VertexOutput(float3 pos, float3 normal, float2 uv)
            {
                geometryOutput o;

                o.pos = UnityObjectToClipPos(pos);

#if UNITY_PASS_FORWARDBASE
                o.normal = UnityObjectToWorldNormal(normal);
                o.uv = uv;

                o._ShadowCoord = ComputeScreenPos(o.pos);
#elif UNITY_PASS_SHADOWCASTER

                o.pos = UnityApplyLinearShadowBias(o.pos);
#endif

                return o;
            }

            geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv, float3x3 transformMatrtix)
            {
                float3 tangentPoint = float3(width, forward, height);

                float3 tangentNormal = normalize(float3(0, -1, forward));

                float3 localPosition = vertexPosition + mul(transformMatrtix, tangentPoint);
                float3 localNormal = mul(transformMatrtix, tangentNormal);

                return VertexOutput(localPosition, localNormal, uv);
            }

            float _BladeHeight;
            float _BladeHeightRandom;

            float _BladeWidthRandom;
            float _BladeWidth;

            float _BladeForward;
            float _BladeCurve;

            float _BendRotationRandom;

            sampler2D _WindDistortionMap;
            float4 _WindDistortionMap_ST;

            float _WindStrength;
            float2 _WindFrequency;

#define BLADE_SEGMENTS 3

            [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
            void geo(triangle vertexOutput IN[3], inout TriangleStream<geometryOutput> triStream)
            {
                float3 pos = IN[0].vertex.xyz;

                float3x3 facingRotationMatrix = AngleAxis3x3(GetRandomFloat(pos) * UNITY_TWO_PI, float3(0, 0, 1));

                float3x3 bendRoationMatrix = AngleAxis3x3(GetRandomFloat(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

                float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
                float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
                float3 wind = normalize(float3(windSample.x, windSample.y, 0));

                float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

                float3 vNormal = IN[0].normal;
                float4 vTangent = IN[0].tangent;
                float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;

                float3x3 tangentToLocal = float3x3
                    (
                        vTangent.x, vBinormal.x, vNormal.x,
                        vTangent.y, vBinormal.y, vNormal.y,
                        vTangent.z, vBinormal.z, vNormal.z
                        );

                float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRoationMatrix);
                float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);
            
                float height = (GetRandomFloat(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
                float width = (GetRandomFloat(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
                float forward = GetRandomFloat(pos.yyz) * _BladeForward;

                for (int i = 0; i < BLADE_SEGMENTS; i++)
                {
                    float t = i / (float)BLADE_SEGMENTS;

                    float segmentHeight = height * t;
                    float segmentWidth = width * (1 - t);
                    float segmentForward = pow(t, _BladeCurve) * forward;

                   				float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

                    triStream.Append(GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
                    triStream.Append(GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
                }

                triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix));

            }

            ENDCG

                SubShader
            {
                Pass
                {
                    Tags
                    {
                        "RenderType" = "Opaque"
                        "LightMode" = "ForwardBase"
                    }
                    CGPROGRAM
                #pragma vertex vert
                #pragma geometry geo
                #pragma fragment frag
                #pragma hull hull
                #pragma domain domain
                #pragma target 4.6
                #pragma multi_compile_fwdbase

#include "Lighting.cginc"

                    float4 _TopColor;
                    float4 _BottomColor;
                    float _TranslucentGain;

                    float4 frag(geometryOutput i, fixed facing : VFACE) : SV_Target
                    {
                        float3 normal = facing > 0 ? i.normal : -i.normal;
                
                        float shadow = SHADOW_ATTENUATION(i);
                        float NdotL = saturate(saturate(dot(normal, _WorldSpaceLightPos0)) + _TranslucentGain) * shadow;
            
                        float3 ambient = ShadeSH9(float4(normal, 1));
                        float4 lightInensity = NdotL * _LightColor0 + float4(ambient, 1);
                        float4 col = lerp(_BottomColor, _TopColor * lightInensity, i.uv.y);

                        return col;
                    }

                    ENDCG
                }

                Pass
                {
                        Tags
                        {
                            "LightMode" = "ShadowCaster"
                        }

                        CGPROGRAM
                #pragma vertex vert
                #pragma geometry geo
                #pragma fragment frag
                #pragma hull hull
                #pragma domain domain
                #pragma target 4.6
                #pragma multi_compile_shadowcaster
                        
                        float4 frag(geometryOutput i): SV_Target
                    {
                        SHADOW_CASTER_FRAGMENT(i)
                    }

                    ENDCG
                }
            }
}

