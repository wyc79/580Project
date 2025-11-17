Shader "Hidden/EdgeDetection"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _EdgeColor ("Edge Color", Color) = (1,1,1,1)
        _BackgroundColor ("Background Color", Color) = (0,0,0,1)
        _Threshold ("Threshold", Range(0, 1)) = 0.2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        LOD 100
        
        Pass
        {
            Name "EdgeDetection"
            ZTest Always ZWrite Off Cull Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_TexelSize;
            
            float4 _EdgeColor;
            float4 _BackgroundColor;
            float _Threshold;
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }
            
            float GetLuminance(float3 color)
            {
                return dot(color, float3(0.299, 0.587, 0.114));
            }
            
            float SobelEdgeDetection(float2 uv)
            {
                float2 texelSize = _MainTex_TexelSize.xy;
                
                float3 s00 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-texelSize.x, -texelSize.y)).rgb;
                float3 s01 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(0, -texelSize.y)).rgb;
                float3 s02 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(texelSize.x, -texelSize.y)).rgb;
                
                float3 s10 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-texelSize.x, 0)).rgb;
                float3 s12 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(texelSize.x, 0)).rgb;
                
                float3 s20 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-texelSize.x, texelSize.y)).rgb;
                float3 s21 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(0, texelSize.y)).rgb;
                float3 s22 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(texelSize.x, texelSize.y)).rgb;
                
                float l00 = GetLuminance(s00);
                float l01 = GetLuminance(s01);
                float l02 = GetLuminance(s02);
                float l10 = GetLuminance(s10);
                float l12 = GetLuminance(s12);
                float l20 = GetLuminance(s20);
                float l21 = GetLuminance(s21);
                float l22 = GetLuminance(s22);
                
                // Sobel
                // Gx = [-1  0  1]      Gy = [-1 -2 -1]
                //      [-2  0  2]           [ 0  0  0]
                //      [-1  0  1]           [ 1  2  1]
                
                float gx = -l00 - 2.0 * l10 - l20 + l02 + 2.0 * l12 + l22;
                float gy = -l00 - 2.0 * l01 - l02 + l20 + 2.0 * l21 + l22;
                
                float edge = sqrt(gx * gx + gy * gy);
                
                return edge;
            }
            
            float4 frag(Varyings input) : SV_Target
            {
                float edge = SobelEdgeDetection(input.uv);
                
                float edgeMask = step(_Threshold, edge);
                float4 color = lerp(_BackgroundColor, _EdgeColor, edgeMask);
                
                return color;
            }
            ENDHLSL
        }
    }
}