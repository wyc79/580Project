Shader "Hidden/EdgeDetection_DepthNormals"
{
    Properties
    {
        _EdgeColor ("Edge Color", Color) = (0,0,0,1)
        _BackgroundColor ("Background Color", Color) = (1,1,1,0)
        _DepthThreshold ("Depth Threshold", Range(0, 1)) = 0.2
        _Threshold ("Normal Threshold", Range(0, 1)) = 0.4
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
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            
            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);
            float4 _BlitTexture_TexelSize;
            
            float4 _EdgeColor;
            float4 _BackgroundColor;
            float _DepthThreshold;
            float _Threshold;
            
            struct Attributes
            {
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uv_depth[4] : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.uv = GetFullScreenTriangleTexCoord(input.vertexID);
                
                float2 texelSize = _BlitTexture_TexelSize.xy;
                output.uv_depth[0] = output.uv + float2(-1.0, -1.0) * texelSize;
                output.uv_depth[1] = output.uv + float2( 1.0,  1.0) * texelSize;
                output.uv_depth[2] = output.uv + float2( 1.0, -1.0) * texelSize;
                output.uv_depth[3] = output.uv + float2(-1.0,  1.0) * texelSize;
                
                return output;
            }
            

            float CheckEdge(float2 uv_1, float2 uv_2)
            {
                float d1 = Linear01Depth(SampleSceneDepth(uv_1), _ZBufferParams);
                float d2 = Linear01Depth(SampleSceneDepth(uv_2), _ZBufferParams);
                
                float3 n1 = SampleSceneNormals(uv_1);
                float3 n2 = SampleSceneNormals(uv_2);
                
                float depthDiff = abs(d1 - d2);
                
                float isDepthEdge = step(_DepthThreshold * d1, depthDiff);
                
                float normalDiff = dot(n1, n2);
                float isNormalEdge = step(normalDiff, _Threshold); 
                
                return max(isDepthEdge, isNormalEdge);
            }
            
           float4 frag(Varyings input) : SV_Target
            {
                float centerDepth = Linear01Depth(SampleSceneDepth(input.uv), _ZBufferParams);

                if(centerDepth > 0.999)
                {
                    return _BackgroundColor;
                }
                
                float edge1 = CheckEdge(input.uv_depth[0], input.uv_depth[1]);
                float edge2 = CheckEdge(input.uv_depth[2], input.uv_depth[3]);
                float edge = max(edge1, edge2);

                float4 finalColor = lerp(_BackgroundColor, _EdgeColor, edge);
                
                return finalColor;
            }
            ENDHLSL
        }
    }
}