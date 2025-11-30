using UnityEngine;

public class MultipleDeformCircleReveal : MonoBehaviour
{
    [Tooltip("All materials that should react to the reveal (Deform + FadeOut)")]
    public Material[] materials;

    public Transform revealCenter;
    public float startRadius = 0f;
    public float endRadius   = 5f;
    public float duration    = 3f;
    public float feather     = 0.5f;

    public float radius;

    private float time;

    void Start()
    {
        if (materials == null || materials.Length == 0) return;

        foreach (var mat in materials)
        {
            if (!mat) continue;
            mat.SetFloat("_RevealRadius", startRadius);
            mat.SetFloat("_RevealFeather", feather);
        }
    }

    void Update()
    {
        if (materials == null || materials.Length == 0) return;

        Vector3 center = revealCenter != null ? revealCenter.position : transform.position;

        time += Time.deltaTime;
        float t      = Mathf.Clamp01(time / duration);
        // float radius = Mathf.Lerp(startRadius, endRadius, t);
        radius = Mathf.Lerp(startRadius, endRadius, t);

        foreach (var mat in materials)
        {
            if (!mat) continue;
            mat.SetVector("_RevealCenter", center);
            mat.SetFloat("_RevealRadius", radius);
        }
    }
}
