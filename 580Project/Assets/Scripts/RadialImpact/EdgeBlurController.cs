using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.InputSystem;

public class EdgeBlurController : MonoBehaviour
{

    public Volume globalVolume;
    public Camera targetCamera;
    public GameObject sphereObject;
    
    public float blurDurationToTarget = 0.2f;
    public float blurDurationRecover = 0.8f;
    
    public float sphereGrowDuration = 1.0f;
    public float sphereStartScale = 0.2f;
    public float sphereTargetScale = 10.0f;

    public AnimationCurve motionCurve = new AnimationCurve(new Keyframe(0, 0), new Keyframe(1, 1));
    
    public float startValue = 1.0f;
    public float targetValue = 0.159f;

    private EdgeAndBlurEffectComponent _edgeBlurComponent;
    private Coroutine _currentCoroutine;
    private bool _hasHitPosition = false;
    
    void Start()
    {
        if (globalVolume == null) globalVolume = GetComponent<Volume>();
        if (targetCamera == null) targetCamera = Camera.main;
        if (globalVolume.profile.TryGet(out _edgeBlurComponent))
        {
            _edgeBlurComponent.dissolveThreshold.value = startValue;
            _edgeBlurComponent.dissolveThreshold.overrideState = true;
            _edgeBlurComponent.enableEffect.overrideState = true;
            _edgeBlurComponent.enableEffect.value = false;
        }

        if (sphereObject != null)
        {
            sphereObject.SetActive(false);
            sphereObject.transform.localScale = Vector3.zero;
        }
    }

    void Update()
    {
        if (Keyboard.current != null && Keyboard.current.spaceKey.wasPressedThisFrame)
        {
            TriggerEffect();
        }
    }

    
    void TriggerEffect()
    {
        if (_edgeBlurComponent == null) return;
        if (Mouse.current == null) return;

        Vector2 mousePos = Mouse.current.position.ReadValue();
        
        _hasHitPosition = false;
        if (targetCamera != null && sphereObject != null)
        {
            Ray ray = targetCamera.ScreenPointToRay(mousePos);
            if (Physics.Raycast(ray, out RaycastHit hit, 1000f))
            {
                sphereObject.transform.position = hit.point;
                _hasHitPosition = true;
            }
        }

        if (sphereObject != null)
        {
            sphereObject.SetActive(false);
            sphereObject.transform.localScale = Vector3.zero;
        }
        
        if (_currentCoroutine != null) StopCoroutine(_currentCoroutine);
        _currentCoroutine = StartCoroutine(DoSequence());
    }

    IEnumerator DoSequence()
    {

        _edgeBlurComponent.enableEffect.value = true;

        float timer;
        float curveValue;
        
        timer = 0f;
        while (timer < blurDurationToTarget)
        {
            timer += Time.deltaTime;
            float t = Mathf.Clamp01(timer / blurDurationToTarget);
            curveValue = motionCurve.Evaluate(t);
            _edgeBlurComponent.dissolveThreshold.value = Mathf.Lerp(startValue, targetValue, curveValue);
            yield return null;
        }
        _edgeBlurComponent.dissolveThreshold.value = targetValue;


        timer = 0f;
        while (timer < blurDurationRecover)
        {
            timer += Time.deltaTime;
            float t = Mathf.Clamp01(timer / blurDurationRecover);
            curveValue = motionCurve.Evaluate(t);
            _edgeBlurComponent.dissolveThreshold.value = Mathf.Lerp(targetValue, startValue, curveValue);
            yield return null;
        }
        _edgeBlurComponent.dissolveThreshold.value = startValue;
        
        _edgeBlurComponent.enableEffect.value = false;
        

        if (sphereObject != null && _hasHitPosition)
        {
            sphereObject.SetActive(true);
            
            sphereObject.transform.localScale = Vector3.one * sphereStartScale;

            timer = 0f;
            while (timer < sphereGrowDuration)
            {
                timer += Time.deltaTime;
                float t = Mathf.Clamp01(timer / sphereGrowDuration);
                curveValue = motionCurve.Evaluate(t);
                
                float currentScale = Mathf.Lerp(sphereStartScale, sphereTargetScale, curveValue);
                sphereObject.transform.localScale = Vector3.one * currentScale;

                yield return null;
            }
            sphereObject.transform.localScale = Vector3.one * sphereTargetScale;
            sphereObject.SetActive(false);
        }
        _currentCoroutine = null;
    }
}