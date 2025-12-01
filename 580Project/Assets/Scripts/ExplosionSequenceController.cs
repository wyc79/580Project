using UnityEngine;
using System.Collections;
using UnityEngine.InputSystem;

public class ExplosionSequenceController : MonoBehaviour
{
    public EdgeBlurController edgeBlurController;
    public MultipleDeformCircleReveal multipleDeformCircleReveal;
    public float waitOffset = 0f;
    void Update()
    {
        if (Keyboard.current != null && Keyboard.current.spaceKey.wasPressedThisFrame)
        {
            StartExplosion();
        }
    }
    
    public void StartExplosion()
    {
        StartCoroutine(PerformExplosionSequence());
    }
    
    IEnumerator PerformExplosionSequence()
    {
        if (edgeBlurController != null)
        {
            edgeBlurController.TriggerEffect();

            float waitDuration = edgeBlurController.blurDurationToTarget + edgeBlurController.blurDurationRecover;

            yield return new WaitForSeconds(waitDuration + waitOffset);
        }
        else
        {
            yield break;
        }

        if (multipleDeformCircleReveal != null)
        {
            multipleDeformCircleReveal.TriggerReveal();
        }
    }
}