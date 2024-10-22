Shader "Custom/TerrainShaderWithGrass"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0

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
        [Header(Player Dot)]
        _PlayerPosition("Player Position", Vector) = (0,0,0,0)
        _Radius("Radius", float) = 1.0
        _EffectStrength("Effect Strength", float) = 0.1
        _FadeAmount("Fade", float) = 1.0
        _MaxHeight("Max Height", float) = 0.5

            // Splat Map Control Texture
            [HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}

        // Textures
        [HideInInspector] _Splat0("Grass Layer (R)", 2D) = "white" {}
        [HideInInspector] _Splat3("Layer 3 (A)", 2D) = "white" {}
        [HideInInspector] _Splat2("Layer 2 (B)", 2D) = "white" {}
        [HideInInspector] _Splat1("Layer 1 (G)", 2D) = "white" {}


        // Normal Maps
        [HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}
        [HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}

    }

        SubShader
    {
        CGPROGRAM
        Tags { "RenderType" = "Opaque" }
        LOD 200

        #include "UnityCG.cginc"
        #include "Autolight.cginc"
        #include "Shaders/CustomTessellation.cginc"

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
        // Read the control map and terrain textures
        fixed4 control = tex2D(_Control, IN.uv_Control);
        fixed4 s1 = tex2D(_Splat1, IN.uv_Control) * _Color;
        fixed4 s2 = tex2D(_Splat2, IN.uv_Control) * _Color;
        fixed4 s3 = tex2D(_Splat3, IN.uv_Control) * _Color;

        // Blending of the other terrain layers
        o.Albedo = s1 * control.g + s2 * control.b + s3 * control.a;
        o.Emission = c.rgb;
        o.Metallic = _Metallic;
        o.Smoothness = _Glossiness;
    }
    ENDCG

    CGPROGRAM

    #pragma target 3.0

    sampler2D _Control;
    sampler2D _Splat0;
    sampler2D _Splat1;
    sampler2D _Splat2;
    sampler2D _Splat3;

    struct Input
    {
        float2 uv_Control;
    };

    half _Glossiness;
    half _Metallic;
    fixed4 _Color;

    UNITY_INSTANCING_BUFFER_START(Props)
    UNITY_INSTANCING_BUFFER_END(Props)

    struct geometryOutput
    {
        float4 pos : SV_POSITION;
        float4 worldPos : TEXCOORD2;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        unityShadowCoord4 _ShadowCoord : TEXCOORD1;
    };

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
        float outerMask = smoothstep(_Radius, _Radius + _EffectStrength, dis);

        float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
        float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

        float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
        float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
        float3 wind = normalize(float3(windSample.x, windSample.y, 0));

        float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

        float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight; S
            float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
        float forward = rand(pos.yyz) * _BladeForward;

        for (int i = 0; i < BLADE_SEGMENTS; i++)
        {
            float t = i / (float)BLADE_SEGMENTS;
            float segmentHeight = height * t;
            float segmentWidth = width * (1 - t);
            float segmentForward = pow(t, _BladeCurve) * forward;

            float3x3 transformMatrix = i == 0 ? facingRotationMatrix : bendRotationMatrix;
            triStream.Append(GenerateGrassVertex(pos / innerMask, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
            triStream.Append(GenerateGrassVertex(pos / innerMask, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
        }

        triStream.Append(GenerateGrassVertex(pos / innerMask, 0, height, forward, float2(0.5, 1), bendRotationMatrix));

    }

    ENDCG
        //}
       // FallBack "Diffuse"
    }