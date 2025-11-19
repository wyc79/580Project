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
        _LavaBlend("Lava Blend", Range(0,1)) = 0.5

        // Height controls
        _HeightAmplitude("Height Amplitude", Float) = 0.15
        _HeightOffset("Ground Above Lava", Float) = 0.10
        _HeightNoiseScale("Height Noise Scale", Float) = 2.0

        // Corner rounding
        _CornerExpand("Corner Expansion", Range(0,3)) = 1.0

        // Detail normal (per-pixel bump) strength
        _DetailNormalStrength("Detail Normal Strength", Float) = 0.3
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
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
                float  _LavaBlend;

                float  _HeightAmplitude;
                float  _HeightOffset;
                float  _HeightNoiseScale;

                float  _CornerExpand;

                float  _DetailNormalStrength;
            CBUFFER_END

            // -------- Hash & Worley 3D --------
            float3 hash3(float3 p)
            {
                p = float3(
                    dot(p, float3(127.1, 311.7, 74.7)),
                    dot(p, float3(269.5, 183.3, 246.1)),
                    dot(p, float3(113.5, 271.9, 124.6))
                );
                return frac(sin(p) * 43758.5453);
            }

            // 3D Worley: returns F1, F2, F3 (nearest 3 distances)
            float3 worley3D(float3 p)
            {
                float3 cell  = floor(p);
                float3 fracP = frac(p);

                float minDist1 = 1e9;
                float minDist2 = 1e9;
                float minDist3 = 1e9;

                [unroll]
                for (int z = -1; z <= 1; z++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        [unroll]
                        for (int x = -1; x <= 1; x++)
                        {
                            float3 offset  = float3(x, y, z);
                            float3 rand    = hash3(cell + offset);
                            float3 feature = offset + rand - fracP;
                            float  d       = length(feature);

                            if (d < minDist1)
                            {
                                minDist3 = minDist2;
                                minDist2 = minDist1;
                                minDist1 = d;
                            }
                            else if (d < minDist2)
                            {
                                minDist3 = minDist2;
                                minDist2 = d;
                            }
                            else if (d < minDist3)
                            {
                                minDist3 = d;
                            }
                        }
                    }
                }

                return float3(minDist1, minDist2, minDist3);
            }

            // -------- Perlin-style 3D noise (for height / detail) --------
            float fade(float t)
            {
                // 6t^5 - 15t^4 + 10t^3
                return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
            }

            float gradNoise(float3 lattice, float3 p)
            {
                float3 rand = normalize(hash3(lattice) * 2.0 - 1.0);
                return dot(rand, p - lattice);
            }

            // Returns ~[-1,1]
            float perlin3D(float3 p)
            {
                float3 pi = floor(p);
                float3 pf = p - pi;

                float3 w = float3(
                    fade(pf.x),
                    fade(pf.y),
                    fade(pf.z)
                );

                float n000 = gradNoise(pi + float3(0,0,0), p);
                float n100 = gradNoise(pi + float3(1,0,0), p);
                float n010 = gradNoise(pi + float3(0,1,0), p);
                float n110 = gradNoise(pi + float3(1,1,0), p);
                float n001 = gradNoise(pi + float3(0,0,1), p);
                float n101 = gradNoise(pi + float3(1,0,1), p);
                float n011 = gradNoise(pi + float3(0,1,1), p);
                float n111 = gradNoise(pi + float3(1,1,1), p);

                float nx00 = lerp(n000, n100, w.x);
                float nx10 = lerp(n010, n110, w.x);
                float nx01 = lerp(n001, n101, w.x);
                float nx11 = lerp(n011, n111, w.x);

                float nxy0 = lerp(nx00, nx10, w.y);
                float nxy1 = lerp(nx01, nx11, w.y);

                float nxyz = lerp(nxy0, nxy1, w.z);

                return nxyz; // ~[-1,1]
            }

            // -------- Helpers: crack / corner from Worley --------
            void ComputeCrackData(float3 worley, out float cellGap, out float localCrackWidth)
            {
                float F1 = worley.x;
                float F2 = worley.y;
                float F3 = worley.z;

                // edge signal
                cellGap = max(F2 - F1, 0.0);

                // corner metric: F3-F1 small when 3 cells meet
                float cornerMetric = F3 - F1;

                // make this less extreme: scale denominator up
                float cornerFactor = saturate(1.0 - cornerMetric / (_CrackWidth * 4.0));
                // emphasize corners a bit
                cornerFactor = cornerFactor * cornerFactor;

                // widen crack near corners
                localCrackWidth = _CrackWidth * (1.0 + cornerFactor * _CornerExpand * 4.0);
            }

            // -------- Vertex --------
            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS   = normalize(TransformObjectToWorldNormal(IN.normalOS));

                float3 fromCenter = positionWS - _SphereCenter.xyz;
                float  lenFC      = max(length(fromCenter), 1e-5);
                float3 dir        = fromCenter / lenFC; // unit vector on sphere

                float3 p       = dir * _NoiseScale;
                float3 worley  = worley3D(p);

                float cellGap;
                float localCrackWidth;
                ComputeCrackData(worley, cellGap, localCrackWidth);

                // lava vs ground mask using locally-adjusted crack width
                float lavaMask = 1.0 - step(localCrackWidth, cellGap); // 1 = lava, 0 = ground

                // Smooth edge factor around cracks (for normal bending)
                float lavaMaskSoft = saturate(1.0 - cellGap / (localCrackWidth * 1.2));
                float transition   = saturate(lavaMaskSoft * (1.0 - lavaMaskSoft) * 4.0);

                // Finer Perlin for height
                float3 pHeight    = p * _HeightNoiseScale;
                float  baseNoise  = perlin3D(pHeight);          // ~[-1,1]
                float  baseHeight = baseNoise * _HeightAmplitude;

                float groundHeight = baseHeight + _HeightOffset * 0.5;
                float lavaHeight   = baseHeight - _HeightOffset * 0.5;

                float height = lerp(groundHeight, lavaHeight, lavaMask);

                // Bend normals slightly towards inward direction near the rim
                float3 inwardDir    = -dir;
                float3 bentNormalWS = normalize(lerp(normalWS, inwardDir, transition * 0.5));

                positionWS += bentNormalWS * height;

                OUT.positionWS  = positionWS;
                OUT.normalWS    = bentNormalWS;
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                return OUT;
            }

            // -------- Fragment (lit + detail normal) --------
            float4 frag(Varyings IN) : SV_Target
            {
                float3 positionWS = IN.positionWS;

                float3 fromCenter = positionWS - _SphereCenter.xyz;
                float  lenFC      = max(length(fromCenter), 1e-5);
                float3 dir        = fromCenter / lenFC;

                float3 p      = dir * _NoiseScale;
                float3 worley = worley3D(p);

                float cellGap;
                float localCrackWidth;
                ComputeCrackData(worley, cellGap, localCrackWidth);

                // thresholds based on (expanded) crack width
                float threshold1 = localCrackWidth * (1.0 - _LavaBlend);  // lava side
                float threshold2 = localCrackWidth * (1.0 + _LavaBlend);  // ground side

                float tWidth = max(threshold2 - threshold1, 1e-5);

                // Animated lava brightness (emissive-ish color basis)
                float timeVal   = _Time.y * _LavaPulseSpeed;
                float lavaPulse = 0.5 + 0.5 * sin(timeVal + worley.x * 12.0);

                float3 groundColor   = _GroundColor.rgb;
                float3 lavaBaseColor = _LavaColor.rgb * (1.0 + lavaPulse * _LavaGlow);

                float3 baseColor;

                if (cellGap <= threshold1)
                {
                    // Hard lava
                    baseColor = lavaBaseColor;
                }
                else if (cellGap >= threshold2)
                {
                    // Hard ground
                    baseColor = groundColor;
                }
                else
                {
                    // In the band: smoothly blend based on Worley gap
                    float w = saturate((cellGap - threshold1) / tWidth);
                    w = smoothstep(0.0, 1.0, w); // rounded easing

                    baseColor = lerp(lavaBaseColor, groundColor, w);
                }

                // -------- Detail normal (per-pixel bump) --------
                float3 N = normalize(IN.normalWS);

                // Build a tangent basis from N
                float3 up = (abs(N.y) < 0.999) ? float3(0,1,0) : float3(1,0,0);
                float3 T  = normalize(cross(up, N));
                float3 B  = cross(N, T);

                // Use Perlin again to drive bumpiness
                float3 pDetail = p * (_HeightNoiseScale * 1.5);
                float  h1      = perlin3D(pDetail);           // [-1,1]
                float  h2      = perlin3D(pDetail * 2.37);    // more detail
                float  detail  = (h1 + 0.5 * h2);             // ~[-1.5,1.5]

                // Perturb normal in tangent plane
                float3 bump = N + (T * detail + B * detail) * _DetailNormalStrength;
                N = normalize(bump);

                // -------- Simple Lambert lighting with URP main light --------
                Light mainLight = GetMainLight();
                float3 L = normalize(-mainLight.direction);  // surface -> light
                float  NdotL = saturate(dot(N, L));

                // Ambient term so backfaces aren't totally black
                float3 ambient = 0.1 * baseColor;

                float3 litColor = ambient + baseColor * (NdotL * mainLight.color.rgb);

                return float4(litColor, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
