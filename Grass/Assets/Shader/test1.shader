Shader "Unlit/ShaderSkeleton"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0

        // Splat Map Control Texture
        [HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}

        // Textures
        [HideInInspector] _Splat3("Layer 3 (A)", 2D) = "white" {}
        [HideInInspector] _Splat2("Layer 2 (B)", 2D) = "white" {}
        [HideInInspector] _Splat1("Layer 1 (G)", 2D) = "white" {}
        [HideInInspector] _Splat0("Layer 0 (R)", 2D) = "white" {}

        // Normal Maps
        [HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}
        [HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}

        [Header(Ground)]
        _GroundColor("Ground Color", Color) = (0.4, 0.3, 0.2, 1)
        _GroundTexture("Ground Texture", 2D) = "white" {}
        _GroundTiling("Ground Tiling", Float) = 1.0

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
    sampler2D _MainTex;
    sampler2D _Splat0, _Splat1, _Splat2, _Splat3;
    sampler2D _GroundTexture;
    float _GroundTiling;
    float4 _GroundColor;

    // Ground vertex output structure
    struct Input
    {
        float2 uv_Control;
    };
    struct groundOutput
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
        float4 worldPos : TEXCOORD1;
        unityShadowCoord4 _ShadowCoord : TEXCOORD2;
    };

    struct geometryOutput
    {
        float4 pos : SV_POSITION;
        float4 worldPos : TEXCOORD2;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        unityShadowCoord4 _ShadowCoord : TEXCOORD1;
    };

    // Simple noise function
    float rand(float3 co)
    {
        return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
    }

    // Rotation matrix construction
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
        o.normal = UnityObjectToWorldNormal(normal);
        o.uv = uv;
        o._ShadowCoord = ComputeScreenPos(o.pos);
        o.worldPos = mul(unity_ObjectToWorld, float4(pos, 1.0));
        return o;
    }

    // Ground vertex shader
    groundOutput groundVert(appdata_full v)
    {
        groundOutput o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord.xy * _GroundTiling;
        o.normal = UnityObjectToWorldNormal(v.normal);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex);
        o._ShadowCoord = ComputeScreenPos(o.pos);
        return o;
    }

    geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv, float3x3 transformMatrix)
    {
        float3 tangentPoint = float3(width, forward, height);
        float3 tangentNormal = normalize(float3(0, -1, forward));
        float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
        float3 localNormal = mul(transformMatrix, tangentNormal);
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

        float3 vNormal = IN[0].normal;
        float4 vTangent = IN[0].tangent;
        float3 vBinormal = cross(vNormal, vTangent.xyz) * vTangent.w;

        float3x3 tangentToLocal = float3x3(
            vTangent.x, vBinormal.x, vNormal.x,
            vTangent.y, vBinormal.y, vNormal.y,
            vTangent.z, vBinormal.z, vNormal.z
        );

        float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix);
        float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);

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

            triStream.Append(GenerateGrassVertex(pos / innerMask, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
            triStream.Append(GenerateGrassVertex(pos / innerMask, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
        }

        triStream.Append(GenerateGrassVertex(pos / innerMask, 0, height, forward, float2(0.5, 1), transformationMatrix));
    }

    ENDCG

    SubShader
    {
        // First pass - render ground
        Pass
        {
            Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
            LOD 200
            CGPROGRAM
#pragma vertex groundVert
#pragma fragment groundFrag
#pragma multi_compile_fwdbase
//#pragma surface surf Standard fullforwardshadows
#include "Lighting.cginc"

        //sampler2D _Control;
        /*sampler2D _Splat0;
        sampler2D _Splat1;
        sampler2D _Splat2;
        sampler2D _Splat3;
              void surf(Input IN, inout SurfaceOutputStandard o)
              {
                    // Albedo comes from a texture tinted by color
                    fixed4 c = tex2D(_Control, IN.uv_Control) * _Color;
                    fixed4 s0 = tex2D(_Splat0, IN.uv_Control) * _Color;
                    fixed4 s1 = tex2D(_Splat1, IN.uv_Control) * _Color;
                    fixed4 s2 = tex2D(_Splat2, IN.uv_Control) * _Color;
                    fixed4 s3 = tex2D(_Splat3, IN.uv_Control) * _Color;

                    o.Albedo = s0 * c.r + s1 * c.g + s2 * c.b + s3 * c.a;
                    //o.Emission = c.rgb;

                    // Metallic and smoothness come from slider variables
                    //o.Metallic = _Metallic;
                    //o.Smoothness = _Glossiness;
                    o.Alpha = c.a;
              }*/
            float4 groundFrag(groundOutput i) : SV_Target
            {
                //fixed4 c  = tex2D(_Control, uv_Control.xy) * _Color

                float shadow = SHADOW_ATTENUATION(i);
                float3 normal = normalize(i.normal);
                float NdotL = saturate(dot(normal, _WorldSpaceLightPos0));
                float3 ambient = ShadeSH9(float4(normal, 1));
                
                float4 texColor = tex2D(_GroundTexture, i.uv);
                float4 finalColor = texColor * _GroundColor;
                
                float4 lightIntensity = NdotL * _LightColor0 * shadow + float4(ambient, 1);
                return finalColor * lightIntensity;
            }
            ENDCG
        }

        // Second pass - render grass
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

            fixed4 _Color;
            float4 _Color_ST;
            fixed4 _Albedo;

            float4 frag(geometryOutput i, fixed facing : VFACE) : SV_Target
            {
                float3 normal = facing > 0 ? i.normal : -i.normal;
                float shadow = SHADOW_ATTENUATION(i);
                float NdotL = saturate(saturate(dot(normal, _WorldSpaceLightPos0)) + _TranslucentGain) * shadow;
                float3 ambient = ShadeSH9(float4(normal, 1));
                float4 lightIntensity = NdotL * _LightColor0 + float4(ambient, 1);
                float4 col = lerp(_BottomColor, _TopColor * lightIntensity, i.uv.y);
                return col;
            }
            ENDCG
        }

        // Shadow caster pass
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