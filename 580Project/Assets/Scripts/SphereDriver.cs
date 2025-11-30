using UnityEngine;

[CreateAssetMenu(fileName = "SphereDriver", menuName = "Scriptable Objects/SphereDriver")]
public class SphereDriver : ScriptableObject
{
    
    public Vector3 center;
    public float startRadius = 0f;
    public float endRadius   = 5f;
    public float duration    = 3f;
    public float feather     = 0.5f;


    
}
