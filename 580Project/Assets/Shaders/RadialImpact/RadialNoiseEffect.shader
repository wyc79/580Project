Shader "Custom/RadialNoiseEffect"
{
    Properties
    {
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _Count ("Ray Count", Float) = 0
        _StepValue ("Dissolve Threshold", Range(0, 1)) = 0.5
        [MainColor] _BaseColor ("Tint Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }

        ZWrite Off 
        Cull Off 
        ZTest Always
        Blend Off 

        Pass
        {
            Name "RadialPass"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _NoiseTex_ST;
                half _Count;
                half _StepValue;
                half4 _BaseColor;
            CBUFFER_END
            
            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);
            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            struct Attributes
            {
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
           Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.uv = GetFullScreenTriangleTexCoord(input.vertexID);
                
                return output;
            }
            
            float GetRadialShape(float2 texcoord)
            {
                float2 uv = texcoord * 2 - 1;
                float angle = (atan2(uv.x, uv.y) / PI + 1) * 0.5;
                angle *= _Count;
                float left = angle - floor(angle);
                float right = ceil(angle) - angle;
                return step(0.1, left * right);
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                half value = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).r;
                half mask = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv).r;
                float radialLine = GetRadialShape(uv);
                // float finalResult = step(_StepValue, value) * step(_StepValue, mask) * radialLine;
                float finalResult = step(_StepValue, value) * radialLine;
                return half4(_BaseColor.rgb * finalResult, finalResult);
            }
            ENDHLSL
        }
    }
}