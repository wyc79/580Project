using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class EdgeAndRadialBlurFeature : ScriptableRendererFeature
{
    class EdgeAndRadialBlurPass : ScriptableRenderPass
    {
        private Material m_edgeMaterial;
        private Material m_radialBlurMaterial;
        private Material m_noiseMaterial;
        private EdgeAndBlurEffectComponent m_effectComponent;
        
        private class PassData
        {
            public Material material;
            public TextureHandle sourceTexture;
        }

        public EdgeAndRadialBlurPass(Material edgeMat, Material blurMat, Material noiseMat)
        {
            m_edgeMaterial = edgeMat;
            m_radialBlurMaterial = blurMat;
            m_noiseMaterial = noiseMat;
        }
        
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var stack = VolumeManager.instance.stack;
            m_effectComponent = stack.GetComponent<EdgeAndBlurEffectComponent>();
            
            if (m_radialBlurMaterial == null || m_edgeMaterial == null || m_noiseMaterial == null || 
                m_effectComponent == null || !m_effectComponent.IsActive())
            {
                return;
            }
            
            UpdateMaterialProperties();
            
            var resourceData = frameData.Get<UniversalResourceData>();
            TextureHandle cameraColor = resourceData.activeColorTexture;
            var cameraData = frameData.Get<UniversalCameraData>();
            var cameraDesc = cameraData.cameraTargetDescriptor;
            
            TextureDesc textureDesc = new TextureDesc(cameraDesc.width, cameraDesc.height);
            textureDesc.colorFormat = cameraDesc.graphicsFormat;
            textureDesc.depthBufferBits = DepthBits.None;
            textureDesc.msaaSamples = MSAASamples.None;
            
            textureDesc.name = "TempTexture_Edge";
            TextureHandle tempTextureEdge = renderGraph.CreateTexture(textureDesc);
            
            textureDesc.name = "TempTexture_Blur";
            TextureHandle tempTextureBlur = renderGraph.CreateTexture(textureDesc);


            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Pass 1: Edge Detection", out var passData))
            {
                passData.material = m_edgeMaterial;
                passData.sourceTexture = cameraColor;
                
                builder.UseTexture(passData.sourceTexture);
                builder.SetRenderAttachment(tempTextureEdge, 0);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.sourceTexture, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }
            

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Pass 2: Radial Blur", out var passData))
            {
                passData.material = m_radialBlurMaterial;
                passData.sourceTexture = tempTextureEdge;

                builder.UseTexture(passData.sourceTexture);
                builder.SetRenderAttachment(tempTextureBlur, 0);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.sourceTexture, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }
            

            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Pass 3: Radial Noise", out var passData))
            {
                passData.material = m_noiseMaterial;
                passData.sourceTexture = tempTextureBlur;
                
                builder.UseTexture(passData.sourceTexture);
                builder.SetRenderAttachment(cameraColor, 0);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.sourceTexture, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }
        }
        
        private void UpdateMaterialProperties()
        {
            m_radialBlurMaterial.SetFloat("_BlurStrength", m_effectComponent.BlurStrength.value);
            m_radialBlurMaterial.SetFloat("_BlurWidth", m_effectComponent.BlurWidth.value);
            m_radialBlurMaterial.SetFloat("_CenterX", m_effectComponent.CenterX.value);
            m_radialBlurMaterial.SetFloat("_CenterY", m_effectComponent.CenterY.value);
            m_edgeMaterial.SetColor("_EdgeColor", m_effectComponent.EdgeColor.value);
            m_edgeMaterial.SetColor("_BackgroundColor", m_effectComponent.BackgroundColor.value);
            m_edgeMaterial.SetFloat("_Threshold", m_effectComponent.EdgeThreshold.value);
            
            m_noiseMaterial.SetFloat("_Count", m_effectComponent.rayCount.value);
            m_noiseMaterial.SetFloat("_StepValue", m_effectComponent.dissolveThreshold.value);
            m_noiseMaterial.SetColor("_BaseColor", m_effectComponent.tintColor.value);
            m_noiseMaterial.SetTexture("_NoiseTex", m_effectComponent.noiseTexture.value);
        }
    }
    
    [Header("Shaders")]
    [SerializeField] private Shader edgeShader;
    [SerializeField] private Shader radialShader;
    [SerializeField] private Shader radialNoiseShader;
    
    [Header("Render Settings")]
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

    private EdgeAndRadialBlurPass m_ScriptablePass;
    private Material m_edgeMaterial;
    private Material m_radialMaterial;
    private Material m_noiseMaterial;
    public override void Create()
    {
        if (edgeShader != null) m_edgeMaterial = CoreUtils.CreateEngineMaterial(edgeShader);
        if (radialShader != null) m_radialMaterial = CoreUtils.CreateEngineMaterial(radialShader);
        if (radialNoiseShader != null) m_noiseMaterial = CoreUtils.CreateEngineMaterial(radialNoiseShader);
        
        m_ScriptablePass = new EdgeAndRadialBlurPass(m_edgeMaterial, m_radialMaterial, m_noiseMaterial);
        m_ScriptablePass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_radialMaterial == null || m_edgeMaterial == null) return;

        if (!VolumeManager.instance.stack.GetComponent<EdgeAndBlurEffectComponent>().IsActive())
        {
            return;
        }
        
        
        if (renderingData.cameraData.cameraType == CameraType.Game)
        {
            m_ScriptablePass.ConfigureInput(ScriptableRenderPassInput.Color);
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(m_edgeMaterial);
        CoreUtils.Destroy(m_radialMaterial);
    }
}