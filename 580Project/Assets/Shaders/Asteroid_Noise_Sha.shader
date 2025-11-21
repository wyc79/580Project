Shader "Custom/AsteroidCrater"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.25,0.18,0.12,1)

        _NoiseScaleLarge("Large Noise Scale", Float) = 2
        _NoiseScaleDetail("Detail Noise Scale", Float) = 3.5

        _CraterSize("Crater Size", Float) = 1.1
        _CraterDepth("Crater Depth", Float) = 0.91
        _DistortAmount("Voronoi Distort Amount", Float) = 0.19

        _FBMStrength("FBM Detail Strength", Float) = 1.39
        _WarpStrength("Warp Strength", Float) = 0.37
        _RimSharpness("Rim Sharpness", Float) = 2.98

        _Seed("Random Seed", Vector) = (1,1,1,1)
        _ParallaxDepth("Parallax Depth", Float) = 2.24

        _DisplaceStrength("Displace Strength", Float) = 0.3
        _NormalStrength("Normal Strength", Range(0,1)) = 0.49

        _AmbientColor("Ambient Color", Color) = (0.0,0.05,0.05,1)
        _LightColor("Light Color", Color) = (1,0.9,0.7,1)
        _LightDirection("Light Direction (World)", Vector) = (-3.26,-1.43,1.41,0)

        _SpecularIntensity("Specular Intensity", Range(0,2)) = 0.46
        _Shininess("Shininess", Range(1,128)) = 32
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //Material Params
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;

                float _NoiseScaleLarge;
                float _NoiseScaleDetail;

                float _CraterSize;
                float _CraterDepth;
                float _DistortAmount;

                float _FBMStrength;
                float _WarpStrength;
                float _RimSharpness;

                float4 _Seed;
                float _ParallaxDepth;

                float _DisplaceStrength;
                float _NormalStrength;

                float4 _AmbientColor;
                float4 _LightColor;
                float4 _LightDirection;
                float _SpecularIntensity;
                float _Shininess;
            CBUFFER_END

            //Noise / Voronoi
            float hash(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float noise3D(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);
                float3 u = f * f * (3.0 - 2.0*f);

                float n =
                    lerp(
                        lerp(lerp(hash(i+float3(0,0,0)), hash(i+float3(1,0,0)), u.x),
                             lerp(hash(i+float3(0,1,0)), hash(i+float3(1,1,0)), u.x),
                             u.y),
                        lerp(lerp(hash(i+float3(0,0,1)), hash(i+float3(1,0,1)), u.x),
                             lerp(hash(i+float3(0,1,1)), hash(i+float3(1,1,1)), u.x),
                             u.y),
                        u.z);

                return n;
            }

            float fbm(float3 p)
            {
                float r = 0.0;
                float f = 1.0;
                float w = 0.5;

                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    r += noise3D(p * f) * w;
                    f *= 2.0;
                    w *= 0.5;
                }
                return r;
            }

            float voronoi(float3 p)
            {
                float3 g = floor(p);
                float minDist = 9999;

                for(int x=-1; x<=1; x++)
                for(int y=-1; y<=1; y++)
                for(int z=-1; z<=1; z++)
                {
                    float3 cell = g + float3(x,y,z);
                    float3 rnd = hash(cell);
                    float3 diff = (cell + rnd - p);
                    float d = length(diff);
                    minDist = min(minDist, d);
                }
                return minDist;
            }

            //Crater profile
            float craterProfile(float dist)
            {
                float t = saturate(1.0 - dist / _CraterSize);
                //RimSharpness
                return pow(t, _RimSharpness);
            }

            float craterHeightAtPoint(float3 p)
            {
                //Seed
                p += _Seed.xyz * 10.0;

                //warping
                float warp = fbm(p * 2.0) * _WarpStrength;
                float3 pw = p + warp;

                float cellDist = voronoi(pw * _NoiseScaleLarge);
                cellDist += noise3D(pw * 2.0) * _DistortAmount;

                float crater = craterProfile(cellDist);
                float craterHeight = crater * _CraterDepth;

                float detail = fbm(pw * _NoiseScaleDetail) * _FBMStrength;

                return craterHeight + detail;
            }

            //Shader Structs
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 worldPos    : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
            };

            //Vertex Shader
            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(IN.normalOS);

                float h = craterHeightAtPoint(worldPos);
                worldPos += worldNormal * (h * _DisplaceStrength);

                OUT.worldPos = worldPos;
                OUT.worldNormal = worldNormal;
                OUT.positionHCS = TransformWorldToHClip(worldPos);
                return OUT;
            }

            //Fragment Shader
            half4 frag(Varyings IN) : SV_Target
            {
                float3 worldPos = IN.worldPos;

                // camera -> pixel
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);

                const int STEPS = 8;
                float layerDepth = _ParallaxDepth / STEPS;
                float currentDepth = 0.0;
                float maxHeight = 0.0;

                [loop]
                for (int i = 0; i < STEPS; i++)
                {
                    float3 sampleP = worldPos - viewDir * currentDepth;
                    float h = craterHeightAtPoint(sampleP);
                    maxHeight = max(maxHeight, h);
                    currentDepth += layerDepth;
                }

                //normal mesh
                float3 pBase = worldPos;
                float hCenter = craterHeightAtPoint(pBase);
                float eps = 0.05;

                float hX = craterHeightAtPoint(pBase + float3(eps,0,0));
                float hZ = craterHeightAtPoint(pBase + float3(0,0,eps));

                float3 v1 = float3(eps, hX - hCenter, 0);
                float3 v2 = float3(0,   hZ - hCenter, eps);
                float3 nHeight = normalize(cross(v2, v1));

                float3 Ngeom = normalize(IN.worldNormal);
                float3 N = normalize(lerp(Ngeom, nHeight, _NormalStrength));

                //PBR(fake) temporory
                float3 L = normalize(-_LightDirection.xyz);
                float3 V = viewDir;
                float3 H = normalize(L + V);

                float NdotL = saturate(dot(N, L));
                float diffuse = NdotL;
                float spec = pow(saturate(dot(N, H)), _Shininess) * _SpecularIntensity;

                float3 ambient = _AmbientColor.rgb;
                float3 lightCol = _LightColor.rgb;
                float craterOcclusion = lerp(1.0, 0.25, saturate(maxHeight));

                float3 color =
                    _BaseColor.rgb * craterOcclusion * (ambient + diffuse * lightCol) +
                    spec * lightCol;

                color = saturate(color);

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
