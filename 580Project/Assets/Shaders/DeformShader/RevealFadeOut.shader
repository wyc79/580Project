Shader "Custom/RevealFadeOut"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _MainTex("Main Texture", 2D) = "white" {}

        _RevealCenter("Reveal Center (World)", Vector) = (0,0,0,0)
        _RevealRadius("Reveal Radius", Float) = 0.0
        _RevealFeather("Reveal Feather", Float) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;   // UVs from mesh
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float2 uv          : TEXCOORD2;  // UVs to fragment
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;

                float4 _RevealCenter;
                float  _RevealRadius;
                float  _RevealFeather;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS    = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);

                OUT.uv = IN.uv;

                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // --- Reveal mask (same logic as deform shader) ---
                float distToCenter = distance(IN.positionWS, _RevealCenter.xyz);
                float innerRadius  = _RevealRadius - _RevealFeather * 0.5;
                float outerRadius  = _RevealRadius + _RevealFeather * 0.5;
                float revealMask   = 1.0 - smoothstep(innerRadius, outerRadius, distToCenter);
                // revealMask: 1 inside circle, 0 outside

                // We want to disappear inside the circle → invert mask for alpha
                // (1 - revealMask) = 1 outside, 0 inside
                // We'll combine this with texture + color alpha.
                
                // --- Sample texture ---
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);

                // Base RGB from texture * color
                float3 baseColor = texColor.rgb * _BaseColor.rgb;

                // --- Simple lambert lighting ---
                float3 N = normalize(IN.normalWS);
                Light mainLight = GetMainLight();
                float3 L = normalize(mainLight.direction);
                float  NdotL = saturate(dot(N, L));

                float3 ambient  = 0.1 * baseColor;
                float3 litColor = ambient + baseColor * (NdotL * mainLight.color.rgb);

                // --- Final alpha ---
                float baseAlpha = texColor.a * _BaseColor.a;
                float alpha     = (1.0 - revealMask) * baseAlpha;

                return float4(litColor, alpha);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
