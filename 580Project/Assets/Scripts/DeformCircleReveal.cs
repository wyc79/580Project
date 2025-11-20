using UnityEngine;

public class DeformCircleReveal : MonoBehaviour
{
    public Material deformMaterial;       // material using Custom/Deform (with reveal)
    public Transform revealCenter;        // where the circle starts (often sphere center)
    public float startRadius = 0f;
    public float endRadius = 5f;
    public float duration = 3f;
    public float feather = 0.5f;

    private float time;

    void Start()
    {
        if (!deformMaterial) return;

        deformMaterial.SetFloat("_RevealRadius", startRadius);
        deformMaterial.SetFloat("_RevealFeather", feather);
    }

    void Update()
    {
        if (!deformMaterial) return;

        // Update reveal center in world space
        if (revealCenter != null)
            deformMaterial.SetVector("_RevealCenter", revealCenter.position);
        else
            deformMaterial.SetVector("_RevealCenter", transform.position);

        // Animate radius
        time += Time.deltaTime;
        float t = Mathf.Clamp01(time / duration);
        float radius = Mathf.Lerp(startRadius, endRadius, t);

        deformMaterial.SetFloat("_RevealRadius", radius);
    }
}