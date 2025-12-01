using UnityEngine;
using System.Collections;
using UnityEngine.InputSystem;

public class ExplosionSequenceController : MonoBehaviour
{

    public GameObject asteroid;
    public EdgeBlurController edgeBlurController;
    public MultipleDeformCircleReveal multipleDeformCircleReveal;
    public float waitOffset = 0f;

    private Transform asteroidTransform;

    void Start()
    {
        if (asteroid != null) asteroidTransform = asteroid.transform;
    }

    void Update()
    {
        if (asteroid != null) asteroidTransform = asteroid.transform;
        if (Keyboard.current != null && Keyboard.current.spaceKey.wasPressedThisFrame)
        {
            StartExplosion();
        }

        if (asteroidTransform != null && asteroidTransform.position.y < .01f)
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
            if (asteroidTransform != null) {
                multipleDeformCircleReveal.TriggerReveal(asteroidTransform.position);
            } else {
                multipleDeformCircleReveal.TriggerReveal();
            }
        }
    }
}