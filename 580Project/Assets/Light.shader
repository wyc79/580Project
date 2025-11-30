Shader "Custom/AsteroidCrater_Lit_Glow"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.25,0.18,0.12,1)

        // --- Emission / Glow Properties (New) ---
        [Header(Emission System)]
        [HDR] _EmissionColor("Emission Color", Color) = (1, 0.2, 0.0, 1) // 默认岩浆橙色
        _EmissionThreshold("Glow Depth Threshold", Range(-1, 2)) = 0.5   // 越小只有越深的地方亮
        _EmissionSoftness("Glow Edge Softness", Range(0.01, 1)) = 0.2
        _GlowPulseSpeed("Pulse Speed", Float) = 1.0                      // 呼吸速度
        _GlowFlowSpeed("Flow Speed", Float) = 0.5                        // 流动速度

        [Header(Noise Settings)]
        _NoiseScaleLarge("Large Noise Scale", Float) = 2
        _NoiseScaleDetail("Detail Noise Scale", Float) = 3.5

        [Header(Crater Settings)]
        _CraterSize("Crater Size", Float) = 1.1
        _CraterDepth("Crater Depth", Float) = 0.91
        _DistortAmount("Voronoi Distort Amount", Float) = 0.19
        _RimSharpness("Rim Sharpness", Float) = 2.98

        [Header(Details)]
        _FBMStrength("FBM Detail Strength", Float) = 1.39
        _WarpStrength("Warp Strength", Float) = 0.37
        _Seed("Random Seed", Vector) = (1,1,1,1)
        
        [Header(Rendering)]
        _DisplaceStrength("Displace Strength", Float) = 0.3
        _NormalStrength("Normal Strength", Range(0,1)) = 0.8
        _AmbientColor("Ambient Color", Color) = (0.0,0.05,0.05,1)
        _SpecularIntensity("Specular Intensity", Range(0,2)) = 0.46
        _Shininess("Shininess", Range(1,128)) = 32
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                // Emission Vars
                half4 _EmissionColor;
                float _EmissionThreshold;
                float _EmissionSoftness;
                float _GlowPulseSpeed;
                float _GlowFlowSpeed;

                float _NoiseScaleLarge;
                float _NoiseScaleDetail;
                float _CraterSize;
                float _CraterDepth;
                float _DistortAmount;
                float _FBMStrength;
                float _WarpStrength;
                float _RimSharpness;
                float4 _Seed;
                float _DisplaceStrength;
                float _NormalStrength;
                float4 _AmbientColor;
                float _SpecularIntensity;
                float _Shininess;
            CBUFFER_END

            // --- Noise Functions ---
            float hash(float3 p) {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float noise3D(float3 p) {
                float3 i = floor(p);
                float3 f = frac(p);
                float3 u = f * f * (3.0 - 2.0*f);
                float n = lerp(lerp(lerp(hash(i+float3(0,0,0)), hash(i+float3(1,0,0)), u.x),
                                    lerp(hash(i+float3(0,1,0)), hash(i+float3(1,1,0)), u.x), u.y),
                               lerp(lerp(hash(i+float3(0,0,1)), hash(i+float3(1,0,1)), u.x),
                                    lerp(hash(i+float3(0,1,1)), hash(i+float3(1,1,1)), u.x), u.y), u.z);
                return n;
            }

            float fbm(float3 p) {
                float r = 0.0; float f = 1.0; float w = 0.5;
                [unroll] for (int i = 0; i < 4; i++) {
                    r += noise3D(p * f) * w; f *= 2.0; w *= 0.5;
                }
                return r;
            }

            float voronoi(float3 p) {
                float3 g = floor(p);
                float minDist = 9999;
                for(int x=-1; x<=1; x++) for(int y=-1; y<=1; y++) for(int z=-1; z<=1; z++) {
                    float3 cell = g + float3(x,y,z);
                    float3 rnd = hash(cell);
                    float3 diff = (cell + rnd - p);
                    float d = length(diff);
                    minDist = min(minDist, d);
                }
                return minDist;
            }

            float craterProfile(float dist) {
                float t = saturate(1.0 - dist / _CraterSize);
                return pow(t, _RimSharpness);
            }

            // Height calculation
            float craterHeightAtPoint(float3 p) {
                p += _Seed.xyz * 10.0;
                float warp = fbm(p * 2.0) * _WarpStrength;
                float3 pw = p + warp;
                float cellDist = voronoi(pw * _NoiseScaleLarge);
                cellDist += noise3D(pw * 2.0) * _DistortAmount;
                float crater = craterProfile(cellDist);
                float craterHeight = crater * _CraterDepth;
                float detail = fbm(pw * _NoiseScaleDetail) * _FBMStrength;
                return craterHeight + detail;
            }

            struct Attributes {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings {
                float4 positionHCS : SV_POSITION;
                float3 worldPos    : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float fogFactor    : TEXCOORD3; 
            };

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
                OUT.fogFactor = ComputeFogFactor(OUT.positionHCS.z);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 worldPos = IN.worldPos;
                
                // --- 1. Geometry & Normals ---
                float3 pBase = worldPos;
                float hCenter = craterHeightAtPoint(pBase);
                float eps = 0.05;
                float hX = craterHeightAtPoint(pBase + float3(eps, 0, 0));
                float hZ = craterHeightAtPoint(pBase + float3(0, 0, eps));
                float3 v1 = float3(eps, hX - hCenter, 0);
                float3 v2 = float3(0,   hZ - hCenter, eps);
                float3 nHeight = normalize(cross(v2, v1));
                float3 Ngeom = normalize(IN.worldNormal);
                float3 N = normalize(lerp(Ngeom, nHeight, _NormalStrength));

                // --- 2. Lighting ---
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);
                float4 shadowCoord = TransformWorldToShadowCoord(worldPos);
                Light mainLight = GetMainLight(shadowCoord);
                float3 lightDir = normalize(mainLight.direction);
                float3 lightColor = mainLight.color;
                float shadowAtten = mainLight.shadowAttenuation;

                float NdotL = max(0, dot(N, lightDir));
                float3 diffuse = NdotL * lightColor * shadowAtten;

                float3 H = normalize(lightDir + viewDir);
                float NdotH = max(0, dot(N, H));
                float spec = pow(NdotH, _Shininess) * _SpecularIntensity * shadowAtten;

                float3 ambient = _AmbientColor.rgb;
                float craterOcclusion = lerp(1.0, 0.25, saturate(hCenter));

                // --- 3. Dynamic Emission Logic (New) ---
                
                // A. Mask: Where should it glow? (In the deep parts)
                // Invert height: High values = Deep crater bottom
                // We use smoothstep to make the edge of the lava/energy soft
                float emissionMask = 1.0 - smoothstep(_EmissionThreshold, _EmissionThreshold + _EmissionSoftness, hCenter);

                // B. Dynamic Noise: Make the energy flow
                // We offset the noise sampling position by Time
                float3 flowPos = worldPos * 3.0 + float3(0, _Time.y * _GlowFlowSpeed, 0);
                float flowNoise = fbm(flowPos); // Use existing FBM for organic look

                // C. Pulsing: Make it breathe
                float pulse = sin(_Time.y * _GlowPulseSpeed) * 0.5 + 0.5; // Remap -1..1 to 0..1
                float dynamicIntensity = lerp(0.5, 1.2, pulse); // Breathe between intensity 0.5 and 1.2

                // D. Combine Emission
                float3 emission = _EmissionColor.rgb * emissionMask * (flowNoise + 0.5) * dynamicIntensity;


                // --- 4. Final Color ---
                float3 finalColor = _BaseColor.rgb * craterOcclusion * (ambient + diffuse) + (spec * lightColor);
                
                // Add Emission
                finalColor += emission;

                finalColor = MixFog(finalColor, IN.fogFactor);

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // ShadowCaster Pass (Unchanged from previous, required for shadows)
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
            ZWrite On ZTest LEqual ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float _NoiseScaleLarge; float _NoiseScaleDetail; float _CraterSize; float _CraterDepth;
                float _DistortAmount; float _FBMStrength; float _WarpStrength; float _RimSharpness;
                float4 _Seed; float _DisplaceStrength;
            CBUFFER_END

            float hash(float3 p) { p = frac(p * 0.3183099 + 0.1); p *= 17.0; return frac(p.x * p.y * p.z * (p.x + p.y + p.z)); }
            float noise3D(float3 p) { float3 i = floor(p); float3 f = frac(p); float3 u = f * f * (3.0 - 2.0*f); return lerp(lerp(lerp(hash(i+float3(0,0,0)), hash(i+float3(1,0,0)), u.x), lerp(hash(i+float3(0,1,0)), hash(i+float3(1,1,0)), u.x), u.y), lerp(lerp(hash(i+float3(0,0,1)), hash(i+float3(1,0,1)), u.x), lerp(hash(i+float3(0,1,1)), hash(i+float3(1,1,1)), u.x), u.y), u.z); }
            float fbm(float3 p) { float r = 0.0; float f = 1.0; float w = 0.5; [unroll] for (int i = 0; i < 4; i++) { r += noise3D(p * f) * w; f *= 2.0; w *= 0.5; } return r; }
            float voronoi(float3 p) { float3 g = floor(p); float minDist = 9999; for(int x=-1; x<=1; x++) for(int y=-1; y<=1; y++) for(int z=-1; z<=1; z++) { float3 cell = g + float3(x,y,z); float3 rnd = hash(cell); float3 diff = (cell + rnd - p); float d = length(diff); minDist = min(minDist, d); } return minDist; }
            float craterProfile(float dist) { float t = saturate(1.0 - dist / _CraterSize); return pow(t, _RimSharpness); }
            float craterHeightAtPoint(float3 p) { p += _Seed.xyz * 10.0; float warp = fbm(p * 2.0) * _WarpStrength; float3 pw = p + warp; float cellDist = voronoi(pw * _NoiseScaleLarge); cellDist += noise3D(pw * 2.0) * _DistortAmount; float crater = craterProfile(cellDist); float craterHeight = crater * _CraterDepth; float detail = fbm(pw * _NoiseScaleDetail) * _FBMStrength; return craterHeight + detail; }

            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct Varyings { float4 positionCS : SV_POSITION; };
            
            Varyings vert(Attributes IN) {
                Varyings OUT; float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz); float3 worldNormal = TransformObjectToWorldNormal(IN.normalOS);
                float h = craterHeightAtPoint(worldPos); worldPos += worldNormal * (h * _DisplaceStrength);
                OUT.positionCS = TransformWorldToHClip(worldPos); return OUT;
            }
            half4 frag(Varyings IN) : SV_Target { return 0; }
            ENDHLSL
        }
    }
}