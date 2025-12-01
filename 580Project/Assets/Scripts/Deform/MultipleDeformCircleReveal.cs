using UnityEngine;

public class MultipleDeformCircleReveal : MonoBehaviour
{
    [Tooltip("All materials that should react to the reveal (Deform + FadeOut)")]
    public Material[] materials;

    public SphereDriver sphereDriver;

    // public Transform revealCenter;
    // public float startRadius = 0f;
    // public float endRadius   = 5f;
    // public float duration    = 3f;
    // public float feather     = 0.5f;

    private Vector3 center;
    private float startRadius;
    private float endRadius;
    private float duration;
    private float feather;

    [SerializeField] private bool triggered = false;

    // public float radius;

    private float time = 0f;

    void Start()
    {
        if (materials == null || materials.Length == 0) return;

        center = sphereDriver.center;
        startRadius = sphereDriver.startRadius;
        endRadius = sphereDriver.endRadius;
        duration = sphereDriver.duration;
        feather = sphereDriver.feather;

        foreach (var mat in materials)
        {
            if (!mat) continue;
            mat.SetFloat("_RevealRadius", startRadius);
            mat.SetFloat("_RevealFeather", feather);
        }
    }

    void Update()
    {
        if (!triggered) 
        {
            if (time != 0f) time = 0f;
            return;
        }

        if (materials == null || materials.Length == 0) return;

        // Vector3 center = revealCenter != null ? revealCenter.position : transform.position;

        time += Time.deltaTime;
        float t      = Mathf.Clamp01(time / duration);
        if (t >= 1f)
        {
            triggered = false;
            time = 0f;
            return;
        }
        float radius = Mathf.Lerp(startRadius, endRadius, t);
        // radius = Mathf.Lerp(startRadius, endRadius, t);

        foreach (var mat in materials)
        {
            if (!mat) continue;
            mat.SetVector("_RevealCenter", center);
            mat.SetFloat("_RevealRadius", radius);
        }
    }


    public void TriggerReveal()
    {
        triggered = true;
        time = 0f;
    }
}
