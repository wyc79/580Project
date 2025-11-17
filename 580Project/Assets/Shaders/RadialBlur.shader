Shader "FX/RadialBlur"
{
    Properties
    {
        _MainTex ("Input Texture", 2D) = "white" {}
        _BlurStrength ("Blur Strength", Range(0, 5)) = 1.0
        _BlurWidth ("Blur Width", Range(0, 1)) = 0.5
        _CenterX("Center X", Range(0, 1)) = 0.5
        _CenterY("Center Y", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)
                float _BlurStrength;
                float _BlurWidth;
                float _CenterX;
                float _CenterY;
            CBUFFER_END

            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                
                #if UNITY_UV_STARTS_AT_TOP
                    OUT.uv.y = 1 - OUT.uv.y;
                #endif
                
                return OUT;
            }
            
            half4 frag(Varyings IN) : SV_TARGET
            {
                half4 originalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                
                half samples[10];
                samples[0] = -0.08;
                samples[1] = -0.05;
                samples[2] = -0.03;
                samples[3] = -0.02;
                samples[4] = -0.01;
                samples[5] =  0.01;
                samples[6] =  0.02;
                samples[7] =  0.03;
                samples[8] =  0.05;
                samples[9] =  0.08;
       
                half2 center = half2(_CenterX, _CenterY);
                
                half2 dir = center - IN.uv;
                half dist = length(dir);
                
                half blurFactor = smoothstep(1.0 - _BlurWidth, 1.0, dist);
                
                dir = dir / (dist + 1e-5); 
                
                half4 sum = originalColor;
                for(int n = 0; n < 10; n++)
                {
                    sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv + dir * samples[n] * blurFactor);
                }
                
                sum *= (1.0 / 11.0);
                half t = dist * _BlurStrength;
                t = saturate(t);
                
                return lerp(originalColor, sum, t);
            }
            ENDHLSL
        }
    }
}