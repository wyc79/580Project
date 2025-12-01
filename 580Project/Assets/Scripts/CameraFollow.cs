using UnityEngine;

public class CameraTracker : MonoBehaviour
{
    [Header("Target")]
    public Transform target;

    [Header("Settings")]
    public float rotationSpeed = 10.0f;

    void LateUpdate()
    {
        if (target == null) return;
        Vector3 direction = target.position - transform.position;
        Quaternion targetRotation = Quaternion.LookRotation(direction);
        Vector3 currentEuler = targetRotation.eulerAngles;
        float xAngle = currentEuler.x;
        if (xAngle > 180) xAngle -= 360;
        if (xAngle > 0)
        {
            xAngle = 0;
        }
        float yAngle = targetRotation.eulerAngles.y; 
        Quaternion finalRotation = Quaternion.Euler(xAngle, yAngle, 0);
        transform.rotation = Quaternion.Slerp(transform.rotation, finalRotation, Time.deltaTime * rotationSpeed);
    }
}