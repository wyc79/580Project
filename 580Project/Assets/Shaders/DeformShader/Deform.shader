Shader "Custom/Deform"
{
    Properties
    {
        _BaseColor("Base Color (Original)", Color) = (0.25, 0.2, 0.18, 1)
        _GroundColor("Ground Color", Color)        = (0.25, 0.2, 0.18, 1)
        _LavaColor("Lava Color", Color)           = (1.0, 0.4, 0.0, 1)

        _SphereCenter("Sphere Center (World)", Vector) = (0, 0, 0, 0)

        _NoiseScale("Noise Scale", Float) = 0.4
        _CrackWidth("Crack Width", Float) = 0.15

        _LavaPulseSpeed("Pulse Speed", Float) = 1.0
        _LavaGlow("Glow Strength", Float)     = 1.5
        _LavaBlend("Lava Blend", Range(0,1))  = 0.5

        _HeightNoiseScale("Height Noise Scale", Float) = 0.2

        _CornerExpand("Corner Expansion", Range(0,3)) = 1.0
        _DetailNormalStrength("Detail Normal Strength", Float) = 0.3

        _RevealCenter("Reveal Center (World)", Vector) = (0, 0, 0, 0)
        _RevealRadius("Reveal Radius", Float) = 0.0
        _RevealFeather("Reveal Feather", Float) = 0.5
    }

    SubShader
    {
        Tags
        {
            // OPAQUE instead of Transparent
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Geometry"
        }

        LOD 200

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            // Opaque blend & depth write ON
            Blend One Zero
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;   // not used but harmless
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _GroundColor;
                float4 _LavaColor;

                float4 _SphereCenter;

                float  _NoiseScale;
                float  _CrackWidth;

                float  _LavaPulseSpeed;
                float  _LavaGlow;
                float  _LavaBlend;

                float  _HeightNoiseScale;

                float  _CornerExpand;

                float  _DetailNormalStrength;

                float4 _RevealCenter;
                float  _RevealRadius;
                float  _RevealFeather;
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

            // -------- Perlin-style 3D noise --------
            float fade(float t)
            {
                return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
            }

            float gradNoise(float3 lattice, float3 p)
            {
                float3 rand = normalize(hash3(lattice) * 2.0 - 1.0);
                return dot(rand, p - lattice);
            }

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

                return nxyz;
            }

            // -------- Helpers: crack / corner from Worley --------
            void ComputeCrackData(float3 worley, out float cellGap, out float localCrackWidth)
            {
                float F1 = worley.x;
                float F2 = worley.y;
                float F3 = worley.z;

                cellGap = max(F2 - F1, 0.0);

                float cornerMetric = F3 - F1;

                float cornerFactor = saturate(1.0 - cornerMetric / (_CrackWidth * 4.0));
                cornerFactor = cornerFactor * cornerFactor;

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
                float3 dir        = fromCenter / lenFC; // used for inward normal

                float3 p      = fromCenter * _NoiseScale;
                float3 worley = worley3D(p);

                float cellGap;
                float localCrackWidth;
                ComputeCrackData(worley, cellGap, localCrackWidth);

                float lavaMaskSoft = saturate(1.0 - cellGap / (localCrackWidth * 1.2));
                float transition   = saturate(lavaMaskSoft * (1.0 - lavaMaskSoft) * 4.0);

                float3 inwardDir    = -dir;
                float3 bentNormalWS = normalize(lerp(normalWS, inwardDir, transition * 0.5));

                OUT.positionWS  = positionWS;
                OUT.normalWS    = bentNormalWS;
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                return OUT;
            }

            // -------- Fragment --------
            float4 frag(Varyings IN) : SV_Target
            {
                float3 positionWS = IN.positionWS;

                // ----- Reveal mask: 0 = before deform, 1 = fully deformed -----
                float distToCenter = distance(positionWS, _RevealCenter.xyz);
                float innerRadius  = _RevealRadius - _RevealFeather * 0.5;
                float outerRadius  = _RevealRadius + _RevealFeather * 0.5;
                float revealMask   = 1.0 - smoothstep(innerRadius, outerRadius, distToCenter);

                float3 fromCenter = positionWS - _SphereCenter.xyz;
                float  lenFC      = max(length(fromCenter), 1e-5);
                float3 dir        = fromCenter / lenFC;

                float3 p      = fromCenter * _NoiseScale;
                float3 worley = worley3D(p);

                float cellGap;
                float localCrackWidth;
                ComputeCrackData(worley, cellGap, localCrackWidth);

                float threshold1 = localCrackWidth * (1.0 - _LavaBlend);  // lava side
                float threshold2 = localCrackWidth * (1.0 + _LavaBlend);  // ground side
                float tWidth     = max(threshold2 - threshold1, 1e-5);

                // -------- Detail normal --------
                float3 N = normalize(IN.normalWS);

                float3 up = (abs(N.y) < 0.999) ? float3(0,1,0) : float3(1,0,0);
                float3 T  = normalize(cross(up, N));
                float3 B  = cross(N, T);

                float3 pDetail  = fromCenter * _HeightNoiseScale;
                float3 detail3D = worley3D(pDetail);
                float  h2       = perlin3D(pDetail * 3);
                float  detail   = detail3D.x + 0.5 * h2;

                float3 groundDetailNormal = N + (T * detail + B * detail) * _DetailNormalStrength;
                float3 lavaNormal         = N;

                // -------- Deform colors (ground & lava) --------
                float3 groundColor   = _GroundColor.rgb;
                float3 lavaBaseColor = _LavaColor.rgb;

                float timeVal   = _Time.y * _LavaPulseSpeed;
                float lavaPulse = 0.5 + 0.5 * sin(timeVal + worley.x * 12.0);
                lavaBaseColor  *= (1.0 + lavaPulse * _LavaGlow);

                float3 effectColor;
                float3 finalNormal;

                if (cellGap <= threshold1)
                {
                    effectColor = lavaBaseColor;
                    finalNormal = lavaNormal;
                }
                else if (cellGap >= threshold2)
                {
                    effectColor = groundColor;
                    finalNormal = groundDetailNormal;
                }
                else
                {
                    float w = saturate((cellGap - threshold1) / tWidth);
                    w = smoothstep(0.0, 1.0, w);

                    effectColor = lerp(lavaBaseColor, groundColor, w);
                    finalNormal = normalize(lerp(lavaNormal, groundDetailNormal, w));
                }

                N = normalize(finalNormal);

                // -------- Blend original ↔ deformed by revealMask --------
                float3 originalColor = _BaseColor.rgb;
                float3 surfaceColor  = lerp(originalColor, effectColor, revealMask);

                // -------- Lighting --------
                Light mainLight = GetMainLight();
                float3 L        = normalize(mainLight.direction);
                float  NdotL    = saturate(dot(N, L));

                float3 ambient  = 0.1 * surfaceColor;
                float3 litColor = ambient + surfaceColor * (NdotL * mainLight.color.rgb);

                float alpha = _BaseColor.a;   // keep fully opaque (or tint)

                return float4(litColor, alpha);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
