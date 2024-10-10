Shader "Unlit/Grass3D"
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

		[HideInInspector] _Control("Control (RGBA)", 2D) = "red"{}

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
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		// make fog work
		#pragma multi_compile_fog

		#include "UnityCG.cginc"


		fixed4 _Color;
		float4 _PlayerPosition;
		float _Radius;
		float _EffectStrenght;
		float _FadeAmount;
		float _MaxHeight;

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
			float4 worldPos : TEXCOORD1;
			UNITY_FOG_COORDS(1)
			float4 vertex : SV_POSITION;
		};


		v2f vert(appdata v)
		{
			v2f o;

			float4 worldPos = mul(unity_ObjectToWorld,float4(v.vertex.xyz,1.0));
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			o.worldPos = worldPos;
			o.uv = v.uv;
			return o;
		}

		fixed4 frag(v2f i) : SV_Target
		{
			float dis = distance(i.worldPos.xyz, _PlayerPosition.xyz);

			float innerFadeStart = _Radius - _Radius * _FadeAmount;
			float innerMask = smoothstep(innerFadeStart, _Radius, dis);
			float outerMask = smoothstep(_Radius, _Radius + _EffectStrenght, dis);

			fixed4 colorOutside = tex2D(_MainTex, i.uv);
			fixed4 greenToTexture = lerp(_Color, colorOutside, innerMask);

			fixed4 finalColor = lerp(greenToTexture, colorOutside, outerMask);
			return finalColor;
		}
		ENDCG
	}
	}
}
