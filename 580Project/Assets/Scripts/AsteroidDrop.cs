using UnityEngine;

public class AsteroidBehavior : MonoBehaviour
{
    [Header("Motion Settings")]
    public float destroyHeight = -3.0f;
    public float downwardForce = 0f;    

    [Header("Visual Settings")]
    public float maxSpeed = 60f;       

    [Header("Color Gradient")]
    [ColorUsage(true, true)]
    public Color startColor = new Color(0.5f, 0.0f, 0.0f, 1f); 
    [ColorUsage(true, true)]
    public Color endColor = new Color(2.0f, 1.2f, 0.2f, 1f); 

    [Header("Rim Light Intensity")]
    public float minRimStrength = 0.5f;  
    public float maxRimStrength = 30.0f; 

    [Header("Inner Glow Intensity")]
    public float minEmission = 0.0f;    
    public float maxEmission = 5.0f;     

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
        UpdateVisuals();
    }

    void Update()
    {
        UpdateVisuals();
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
            float t = Mathf.Clamp01(currentSpeed / maxSpeed);
            Color currentColor = Color.Lerp(startColor, endColor, t);
            float currentRim = Mathf.Lerp(minRimStrength, maxRimStrength, t);
            float currentEmission = Mathf.Lerp(minEmission, maxEmission, t);
            float currentPulse = Mathf.Lerp(1.0f, 15.0f, t);
            asteroidMat.SetColor("_RimColor", currentColor);
            asteroidMat.SetFloat("_RimStrength", currentRim);
            asteroidMat.SetColor("_EmissionColor", currentColor * currentEmission);
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