Shader "Custom/TerrainShader 1"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        _PlayerPosition("Player Position" , Vector) = (0,0,0,0)
        _Radius("Radius", float) = 1.0
        _EffectStrenght("Effect Strength", float) = 0.1
        _FadeAmount("Fade", float) = 1.0

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

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
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

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_Control, IN.uv_Control) * _Color;
            fixed4 s0 = tex2D(_Splat0, IN.uv_Control) * _Color; 
            fixed4 s1 = tex2D(_Splat1, IN.uv_Control) * _Color;
            fixed4 s2 = tex2D(_Splat2, IN.uv_Control) * _Color;
            fixed4 s3 = tex2D(_Splat3, IN.uv_Control) * _Color;

            o.Albedo = s0 * c.r + s1 * c.g + s2 * c.b + s3 * c.a ;
            //o.Emission = c.rgb;

            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}