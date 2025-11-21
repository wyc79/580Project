using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


[VolumeComponentMenu("Custom/EdgeAndRadialBlur")]
[SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
public class EdgeAndBlurEffectComponent : VolumeComponent, IPostProcessComponent
{
    [Header("Radial Blur Settings")]
    public FloatParameter BlurStrength = new FloatParameter(0);
    public FloatParameter BlurWidth = new FloatParameter(0);
    
    [Header("Edge Detection Settings")]
    public ColorParameter EdgeColor = new ColorParameter(Color.white, true, false, true);
    public ColorParameter BackgroundColor = new ColorParameter(Color.black, true, false, true);
    public ClampedFloatParameter EdgeThreshold = new ClampedFloatParameter(0.2f, 0f, 1f);
    
    public BoolParameter enableEffect = new BoolParameter(false); 
    public bool IsActive()
    {
        return enableEffect.value;
    }
    
    public bool IsTileCompatible() => true;
}