using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class EdgeAndRadialBlurFeature : ScriptableRendererFeature
{
    class EdgeAndRadialBlurPass : ScriptableRenderPass
    {
        private Material m_edgeMaterial;
        private Material m_radialMaterial;
        private EdgeAndBlurEffectComponent m_effectComponent;
        
        private class PassData
        {
            public Material material;
            public TextureHandle sourceTexture;
        }

        public EdgeAndRadialBlurPass(Material edgeMaterial, Material radialMaterial)
        {
            m_edgeMaterial = edgeMaterial;
            m_radialMaterial = radialMaterial;
            profilingSampler = new ProfilingSampler("EdgeAndRadialBlur");
        }
        
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var stack = VolumeManager.instance.stack;
            m_effectComponent = stack.GetComponent<EdgeAndBlurEffectComponent>();

            if (m_radialMaterial == null || m_edgeMaterial == null || m_effectComponent == null || !m_effectComponent.IsActive())
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
            textureDesc.name = "TempEdgeMap";

            TextureHandle tempTexture = renderGraph.CreateTexture(textureDesc);
            
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Pass 1: Edge Detection", out var passData))
            {
                passData.material = m_edgeMaterial;
                passData.sourceTexture = cameraColor;

                builder.UseTexture(passData.sourceTexture);
                builder.SetRenderAttachment(tempTexture, 0);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    Blitter.BlitTexture(context.cmd, data.sourceTexture, new Vector4(1, 1, 0, 0), data.material, 0);
                });
            }
            
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("Pass 2: Radial Blur", out var passData))
            {
                passData.material = m_radialMaterial;
                passData.sourceTexture = tempTexture;

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
            m_radialMaterial.SetFloat("_BlurStrength", m_effectComponent.BlurStrength.value);
            m_radialMaterial.SetFloat("_BlurWidth", m_effectComponent.BlurWidth.value);
            
            m_edgeMaterial.SetColor("_EdgeColor", m_effectComponent.EdgeColor.value);
            m_edgeMaterial.SetColor("_BackgroundColor", m_effectComponent.BackgroundColor.value);
            m_edgeMaterial.SetFloat("_Threshold", m_effectComponent.EdgeThreshold.value);
        }
    }
    
    [Header("Shaders")]
    [SerializeField] private Shader edgeShader;
    [SerializeField] private Shader radialShader;
    
    [Header("Render Settings")]
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

    private EdgeAndRadialBlurPass m_ScriptablePass;
    private Material m_edgeMaterial;
    private Material m_radialMaterial;

    public override void Create()
    {
        if (edgeShader != null) m_edgeMaterial = CoreUtils.CreateEngineMaterial(edgeShader);
        if (radialShader != null) m_radialMaterial = CoreUtils.CreateEngineMaterial(radialShader);
        
        m_ScriptablePass = new EdgeAndRadialBlurPass(m_edgeMaterial, m_radialMaterial);
        m_ScriptablePass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_radialMaterial == null || m_edgeMaterial == null) return;

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