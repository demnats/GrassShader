Shader "Unlit/ShaderSkeleton"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0
        _Control("Control (RGBA)", 2D) = "red" {}
        _Splat3("Layer 3 (A)", 2D) = "white" {}
        _Splat2("Layer 2 (B)", 2D) = "white" {}
        _Splat1("Layer 1 (G)", 2D) = "white" {}
        _Splat0("Layer 0 (R)", 2D) = "white" {}
        _Tiling0("Tiling 0", Float) = 1.0
        _Tiling1("Tiling 1", Float) = 1.0
        _Tiling2("Tiling 2", Float) = 1.0
        _Tiling3("Tiling 3", Float) = 1.0
        [HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}
        [HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}
        [Header(Grass)]
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
        [Space]
        _PlayerPosition("Player Position" , Vector) = (0,0,0,0)
        _Radius("Radius", float) = 1.0
        _EffectStrenght("Effect Strength", float) = 0.1
        _FadeAmount("Fade", float) = 1.0
        _MaxHeight("Max Height", float) = 0.5
    }

        CGINCLUDE
#include "UnityCG.cginc"
#include "Autolight.cginc"
#include "Shaders/CustomTessellation.cginc"

#pragma instancing_options assumeuniformscaling

            sampler2D _Control;
        float4 _Control_ST;
        sampler2D _Splat0, _Splat1, _Splat2, _Splat3;
        float4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;
        float _Tiling0, _Tiling1, _Tiling2, _Tiling3;

        struct vertexInput
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };

        struct vertexOutput
        {
            float4 vertex : SV_POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
            float2 uvControl : TEXCOORD1;
        };

        struct groundOutput
        {
            float4 pos : SV_POSITION;
            float2 uvControl : TEXCOORD0;
            float2 uvSplat0 : TEXCOORD1;
            float2 uvSplat1 : TEXCOORD2;
            float2 uvSplat2 : TEXCOORD3;
            float2 uvSplat3 : TEXCOORD4;
            float3 normal : NORMAL;
            float4 worldPos : TEXCOORD5;
            unityShadowCoord4 _ShadowCoord : TEXCOORD6;
        };

        struct geometryOutput
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
            float2 uvControl : TEXCOORD1;
            float4 worldPos : TEXCOORD2;
            float3 normal : NORMAL;
            unityShadowCoord4 _ShadowCoord : TEXCOORD3;
        };

        struct TessellationControlPoint {
            float4 vertex : INTERNALTESSPOS;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
            float2 uvControl : TEXCOORD1;
        };

        vertexOutput vert(vertexInput v)
        {
            vertexOutput o;
            o.vertex = v.vertex;
            o.normal = v.normal;
            o.tangent = v.tangent;
            o.uv = v.uv;
            o.uvControl = TRANSFORM_TEX(v.uv, _Control);
            return o;
        }

        TessellationControlPoint hull_const(InputPatch<vertexOutput, 3> patch, uint id : SV_OutputControlPointID)
        {
            TessellationControlPoint p;
            p.vertex = patch[id].vertex;
            p.normal = patch[id].normal;
            p.tangent = patch[id].tangent;
            p.uv = patch[id].uv;
            p.uvControl = patch[id].uvControl;
            return p;
        }

        [domain("tri")]
        vertexOutput domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
        {
            vertexOutput v;

#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
            patch[0].fieldName * barycentricCoordinates.x + \
            patch[1].fieldName * barycentricCoordinates.y + \
            patch[2].fieldName * barycentricCoordinates.z;

            MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
                MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
                MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)
                MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
                MY_DOMAIN_PROGRAM_INTERPOLATE(uvControl)

                return v;
        }

        float rand(float3 co)
        {
            return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
        }

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

        groundOutput groundVert(appdata_full v)
        {
            groundOutput o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uvControl = TRANSFORM_TEX(v.texcoord, _Control);
            o.uvSplat0 = v.texcoord.xy * _Splat0_ST.xy * _Tiling0 + _Splat0_ST.zw;
            o.uvSplat1 = v.texcoord.xy * _Splat1_ST.xy * _Tiling1 + _Splat1_ST.zw;
            o.uvSplat2 = v.texcoord.xy * _Splat2_ST.xy * _Tiling2 + _Splat2_ST.zw;
            o.uvSplat3 = v.texcoord.xy * _Splat3_ST.xy * _Tiling3 + _Splat3_ST.zw;
            o.normal = UnityObjectToWorldNormal(v.normal);
            o.worldPos = mul(unity_ObjectToWorld, v.vertex);
            o._ShadowCoord = ComputeScreenPos(o.pos);
            return o;
        }

        geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv, float3x3 transformMatrix, float2 uvControl)
        {
            float3 tangentPoint = float3(width, forward, height);
            float3 tangentNormal = normalize(float3(0, -1, forward));
            float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
            float3 localNormal = mul(transformMatrix, tangentNormal);

            geometryOutput o;
            o.pos = UnityObjectToClipPos(float4(localPosition, 1.0));
            o.normal = UnityObjectToWorldNormal(localNormal);
            o.uv = uv;
            o.uvControl = uvControl;
            o.worldPos = mul(unity_ObjectToWorld, float4(localPosition, 1.0));
            o._ShadowCoord = ComputeScreenPos(o.pos);
            return o;
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
        float4 _PlayerPosition;
        float _Radius;
        float _EffectStrenght;
        float _MaxHeight;
        float _FadeAmount;

#define BLADE_SEGMENTS 3

        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
        void geo(triangle vertexOutput IN[3], inout TriangleStream<geometryOutput> triStream)
        {
            float3 pos = IN[0].vertex.xyz;
            float2 uvControl = IN[0].uvControl;
            float4 control = tex2D(_Control, uvControl);

            if (control.r <= 0.5) return;

            float3 worldPos = mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz;
            float dis = distance(worldPos, _PlayerPosition.xyz);

            float innerFadeStart = _Radius - _Radius * _FadeAmount;
            float innerMask = smoothstep(innerFadeStart, _Radius, dis);
            float outerMask = smoothstep(_Radius, _Radius + _EffectStrenght, dis);

            float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
            float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

            float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
            float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
            float3 wind = normalize(float3(windSample.x, windSample.y, 0));
            float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

            float3x3 transformationMatrix = mul(mul(windRotation, facingRotationMatrix), bendRotationMatrix);
            float3x3 transformationMatrixFacing = facingRotationMatrix;

            float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
            float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
            float forward = rand(pos.yyz) * _BladeForward;

            for (int i = 0; i < BLADE_SEGMENTS; i++)
            {
                float t = i / (float)BLADE_SEGMENTS;
                float segmentHeight = height * t;
                float segmentWidth = width * (1 - t);
                float segmentForward = pow(t, _BladeCurve) * forward;
                float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

                triStream.Append(GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix, uvControl));
                triStream.Append(GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix, uvControl));
            }

            triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix, uvControl));
        }

        ENDCG

            SubShader
        {
            Pass
            {
                Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }

                CGPROGRAM
                #pragma vertex groundVert
                #pragma fragment groundFrag
                #pragma multi_compile_fwdbase

                #include "Lighting.cginc"

                fixed4 _Color;

                float4 groundFrag(groundOutput i) : SV_Target
                {
                    fixed4 control = tex2D(_Control, i.uvControl);
                    fixed4 splat0 = tex2D(_Splat0, i.uvSplat0);
                    fixed4 splat1 = tex2D(_Splat1, i.uvSplat1);
                    fixed4 splat2 = tex2D(_Splat2, i.uvSplat2);
                    fixed4 splat3 = tex2D(_Splat3, i.uvSplat3);

                    fixed4 albedo = splat0 * control.r +
                                   splat1 * control.g +
                                   splat2 * control.b +
                                   splat3 * control.a;

                    float shadow = SHADOW_ATTENUATION(i);
                    float3 normal = normalize(i.normal);
                    float NdotL = saturate(dot(normal, _WorldSpaceLightPos0));
                    float3 ambient = ShadeSH9(float4(normal, 1));

                    float4 lightIntensity = NdotL * _LightColor0 * shadow + float4(ambient, 1);

                    return albedo * _Color * lightIntensity;
                }
                ENDCG
            }

            Pass
            {
                Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }

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
                    float4 control = tex2D(_Control, i.uvControl);

                    float3 normal = facing > 0 ? i.normal : -i.normal;
                    float shadow = SHADOW_ATTENUATION(i);
                    float NdotL = saturate(saturate(dot(normal, _WorldSpaceLightPos0)) + _TranslucentGain) * shadow;
                    float3 ambient = ShadeSH9(float4(normal, 1));
                    float4 lightIntensity = NdotL * _LightColor0 + float4(ambient, 1);

                    float4 col = lerp(_BottomColor, _TopColor * lightIntensity, i.uv.y) * control.r;
                    return col;
                }
                ENDCG
            }

            Pass
            {
                Tags { "LightMode" = "ShadowCaster" }

                CGPROGRAM
                #pragma vertex vert
                #pragma geometry geo
                #pragma fragment frag
                #pragma hull hull
                #pragma domain domain
                #pragma target 4.6
                #pragma multi_compile_shadowcaster

                float4 frag(geometryOutput i) : SV_Target
                {
                    SHADOW_CASTER_FRAGMENT(i)
                }
                ENDCG
            }
        }
}