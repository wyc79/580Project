Shader "Custom/Deform"
{
    Properties
    {
        _GroundColor("Ground Color", Color) = (0.25, 0.2, 0.18, 1)
        _LavaColor("Secondary Color", Color) = (1.0, 0.4, 0.0, 1)

        _SphereCenter("Sphere Center (World)", Vector) = (0, 0, 0, 0)

        _NoiseScale("Noise Scale", Float) = 4.0
        _CrackWidth("Crack Width", Float) = 0.15

        _LavaPulseSpeed("Pulse Speed", Float) = 1.0
        _LavaGlow("Glow Strength", Float) = 1.5
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }

        LOD 200

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _GroundColor;
                float4 _LavaColor;

                float4 _SphereCenter;

                float  _NoiseScale;
                float  _CrackWidth;

                float  _LavaPulseSpeed;
                float  _LavaGlow;
            CBUFFER_END

            // Hash & Worley 3D
            float3 hash3(float3 p)
            {
                p = float3(
                    dot(p, float3(127.1, 311.7, 74.7)),
                    dot(p, float3(269.5, 183.3, 246.1)),
                    dot(p, float3(113.5, 271.9, 124.6))
                );
                return frac(sin(p) * 43758.5453);
            }

            // 3D Worley/cellular noise (F1 = distance to nearest point)
            float2 worley3D(float3 p)
            {
                float3 cell  = floor(p);
                float3 fracP = frac(p);

                float minDist1 = 1e9;
                float minDist2 = 1e9;

                [unroll]
                for (int z = -1; z <= 1; z++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        [unroll]
                        for (int x = -1; x <= 1; x++)
                        {
                            float3 offset = float3(x, y, z);
                            float3 rand   = hash3(cell + offset);
                            float3 feature = offset + rand - fracP;
                            float d = length(feature);
                            if (d < minDist1)
                            {
                                minDist2 = minDist1;
                                minDist1 = d;
                            }
                            else if (d < minDist2)
                            {
                                minDist2 = d;
                            }
                        }
                    }
                }

                return float2(minDist1, minDist2);
            }

            // vertex
            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS   = TransformObjectToWorldNormal(IN.normalOS);

                OUT.positionWS  = positionWS;
                OUT.normalWS    = normalize(normalWS);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                return OUT;
            }

            // fragment
            float4 frag(Varyings IN) : SV_Target
            {
                float3 positionWS = IN.positionWS;

                // Direction from sphere center: makes effect stick to the sphere surface
                float3 fromCenter = positionWS - _SphereCenter.xyz;
                float  lenFC      = max(length(fromCenter), 1e-5);
                float3 dir        = fromCenter / lenFC; // unit vector on sphere

                // 3D Worley noise in direction space
                float3 p       = dir * _NoiseScale;
                float2 worley  = worley3D(p);
                float  cellGap = max(worley.y - worley.x, 0.0);

                // Harsh threshold: lava when close to cell borders (small gap between F1 and F2)
                float lavaMask = 1.0 - step(_CrackWidth, cellGap);

                // Animated secondary color brightness (optional)
                float t         = _Time.y * _LavaPulseSpeed;
                float lavaPulse = 0.5 + 0.5 * sin(t + worley.x * 12.0);

                float3 groundColor = _GroundColor.rgb;
                float3 lavaColor   = _LavaColor.rgb * (1.0 + lavaPulse * _LavaGlow);

                float3 finalColor = lerp(groundColor, lavaColor, lavaMask);

                return float4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
