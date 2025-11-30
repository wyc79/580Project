Shader "URP/ForceField"
{
    Properties
    {
        [MainColor] _BaseColor ("Base Color", Color) = (0, 0.5, 1, 0.5)
        
        _IntersectPower ("Intersect Power", Range(0, 10)) = 2.0
        
        _RimStrength ("Rim Strength", Range(0, 10)) = 3.0
        
        [Toggle(_DISTORTION_ON)] _UseDistort ("Use Distortion", Float) = 0
        _NoiseTex ("Distortion Noise", 2D) = "white" {}
        _DistortTimeFactor ("Distort Speed", Float) = 1.0
        _DistortStrength ("Distort Strength", Range(0, 0.2)) = 0.05
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent" 
            "RenderPipeline" = "UniversalPipeline" 
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "ForceField"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma shader_feature_local _DISTORTION_ON
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 screenPos  : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float3 viewDirWS  : TEXCOORD2;
                float2 uv         : TEXCOORD3;
            };


            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _IntersectPower;
                float _RimStrength;
                float4 _NoiseTex_ST;
                float _DistortTimeFactor;
                float _DistortStrength;
            CBUFFER_END

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = vertexInput.positionCS;
                
                OUT.screenPos = ComputeScreenPos(OUT.positionCS);
                
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, float4(0,0,0,0));
                OUT.normalWS = normalInput.normalWS;
                
                OUT.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

                OUT.uv = TRANSFORM_TEX(IN.uv, _NoiseTex);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
                float3 viewDir = normalize(IN.viewDirWS);
                float3 normal = normalize(IN.normalWS);
                
                #if UNITY_REVERSED_Z
                    real rawDepth = SampleSceneDepth(screenUV);
                #else
                    real rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
                #endif
                
                float sceneZ = LinearEyeDepth(rawDepth, _ZBufferParams);
                
                float partZ = IN.screenPos.w;
                
                float diff = sceneZ - partZ;
                
                float intersectShape = pow(1.0 - saturate(diff), _IntersectPower);
                
                float intersect = intersectShape * 2;
                
                if(diff > 1.0) intersect = 0;
                
                float NdotV = abs(dot(normal, viewDir));
                float rim = pow(1.0 - NdotV, _RimStrength);
                
                half4 finalColor = _BaseColor;
                
                #if _DISTORTION_ON
                    float2 noiseOffset = _Time.y * _DistortTimeFactor;
                    float2 noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, IN.uv - noiseOffset).rg;
                
                    float2 distortedUV = screenUV + (noise - 0.5) * _DistortStrength;
                
                    half3 sceneColor = SampleSceneColor(distortedUV);
                
                    finalColor.rgb = lerp(sceneColor, _BaseColor.rgb, _BaseColor.a);
                    finalColor.rgb += sceneColor * 0.2;
                #endif
                
                float glow = max(intersect, rim);
                
                finalColor.rgb += glow * _BaseColor.rgb * 2.0;
                
                finalColor.a = saturate(_BaseColor.a + glow);

                return finalColor;
            }
            ENDHLSL
        }
    }
}