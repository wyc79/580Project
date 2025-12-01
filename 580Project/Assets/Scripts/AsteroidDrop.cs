using UnityEngine;

public class AsteroidBehavior : MonoBehaviour
{
    [Header("Motion Settings")]
    public float destroyHeight = -3.0f;
    public float downwardForce = 0f;    // 建议设为 0 或很小，让它慢慢加速，这样才有变色过程

    [Header("Visual Settings")]
    public float maxSpeed = 60f;        // 达到这个速度时最亮

    [Header("Color Gradient")]
    [ColorUsage(true, true)]
    public Color startColor = new Color(0.5f, 0.0f, 0.0f, 1f); // 初始：暗红色 (岩浆冷却)
    [ColorUsage(true, true)]
    public Color endColor = new Color(2.0f, 1.2f, 0.2f, 1f);   // 极速：亮金色 (剧烈燃烧)

    [Header("Rim Light Intensity")]
    public float minRimStrength = 0.5f;  // 初始边缘光 (很暗)
    public float maxRimStrength = 30.0f; // 极速边缘光 (爆亮)

    [Header("Inner Glow Intensity")]
    public float minEmission = 0.0f;     // 初始内部 (几乎不亮)
    public float maxEmission = 5.0f;     // 极速内部

    // 内部变量
    private Rigidbody rb;
    private Material asteroidMat;

    void Start()
    {
        rb = GetComponent<Rigidbody>();
        Renderer rend = GetComponent<Renderer>();
        if (rend != null)
        {
            asteroidMat = rend.material;
        }

        if (rb != null)
        {
            rb.useGravity = true;
            rb.linearVelocity = Vector3.down * downwardForce;
            rb.angularVelocity = Random.insideUnitSphere * 3f;
        }

        // 关键：在第一帧就开始更新视觉，防止出现一瞬间的默认高亮
        UpdateVisuals();
    }

    void Update()
    {
        UpdateVisuals();

        // 销毁逻辑
        if (transform.position.y < destroyHeight)
        {
            DetachTrails();
            Destroy(gameObject);
        }
    }

    void UpdateVisuals()
    {
        if (rb != null && asteroidMat != null)
        {
            float currentSpeed = rb.linearVelocity.magnitude;

            // 计算进度 t (0 到 1)
            float t = Mathf.Clamp01(currentSpeed / maxSpeed);

            // 1. 颜色插值：从暗红 变成 金色
            Color currentColor = Color.Lerp(startColor, endColor, t);

            // 2. 强度插值
            float currentRim = Mathf.Lerp(minRimStrength, maxRimStrength, t);
            float currentEmission = Mathf.Lerp(minEmission, maxEmission, t);
            float currentPulse = Mathf.Lerp(1.0f, 15.0f, t);

            // 3. 应用到材质
            // 设置边缘光颜色和强度
            asteroidMat.SetColor("_RimColor", currentColor);
            asteroidMat.SetFloat("_RimStrength", currentRim);

            // 设置内部发光 (Emission)
            // 注意：这里我们把颜色 * 强度 结合起来
            asteroidMat.SetColor("_EmissionColor", currentColor * currentEmission);
            
            // 设置呼吸频率
            asteroidMat.SetFloat("_GlowPulseSpeed", currentPulse);
        }
    }

    void DetachTrails()
    {
        ParticleSystem[] particles = GetComponentsInChildren<ParticleSystem>();
        foreach (var p in particles)
        {
            p.transform.parent = null;
            var main = p.main;
            main.stopAction = ParticleSystemStopAction.Destroy;
            p.Stop();
        }

        TrailRenderer trail = GetComponent<TrailRenderer>();
        if (trail != null)
        {
            trail.transform.parent = null;
            trail.autodestruct = true;
        }
    }
}