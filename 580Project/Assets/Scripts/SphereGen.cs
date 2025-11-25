using UnityEngine;
using System.Collections.Generic;

[ExecuteAlways]
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class SphereGen : MonoBehaviour
{
    [Range(0, 6)]
    public int subdivisions = 3;
    public float radius = 1f;

    [Header("Height Noise")]
    public bool useHeightNoise = true;

    // Main displacement
    [Range(0f, 0.1f)]
    public float heightAmplitude = 0.05f;    // max base bump

    public float heightNoiseScale = 3f;      // frequency of bumps
    public float heightNoiseOffset = 0f;     // change for different pattern

    [Header("Peak Spikes")]
    [Range(0f, 0.1f)]
    public float spikeAmplitude = 0.02f;     // extra height only on peaks
    [Range(0.5f, 1f)]
    public float spikeThreshold = 0.8f;      // how high the noise must be to spike

    Mesh mesh;
    Dictionary<long, int> middlePointCache;

    void OnValidate()
    {
        Generate();
    }

    void OnEnable()
    {
        Generate();
    }

    void Generate()
    {
        if (mesh == null)
        {
            mesh = new Mesh();
            mesh.name = "Procedural Icosphere";
        }
        else
        {
            mesh.Clear();
        }

        middlePointCache = new Dictionary<long, int>();

        List<Vector3> vertices = new List<Vector3>();
        List<int> triangles = new List<int>();

        float t = (1.0f + Mathf.Sqrt(5.0f)) / 2.0f;

        // 12 initial vertices of an icosahedron
        AddVertex(vertices, new Vector3(-1,  t,  0).normalized);
        AddVertex(vertices, new Vector3( 1,  t,  0).normalized);
        AddVertex(vertices, new Vector3(-1, -t,  0).normalized);
        AddVertex(vertices, new Vector3( 1, -t,  0).normalized);

        AddVertex(vertices, new Vector3( 0, -1,  t).normalized);
        AddVertex(vertices, new Vector3( 0,  1,  t).normalized);
        AddVertex(vertices, new Vector3( 0, -1, -t).normalized);
        AddVertex(vertices, new Vector3( 0,  1, -t).normalized);

        AddVertex(vertices, new Vector3( t,  0, -1).normalized);
        AddVertex(vertices, new Vector3( t,  0,  1).normalized);
        AddVertex(vertices, new Vector3(-t,  0, -1).normalized);
        AddVertex(vertices, new Vector3(-t,  0,  1).normalized);

        int[] faces = {
            0,11,5,   0,5,1,   0,1,7,   0,7,10,  0,10,11,
            1,5,9,    5,11,4,  11,10,2, 10,7,6,  7,1,8,
            3,9,4,    3,4,2,   3,2,6,   3,6,8,   3,8,9,
            4,9,5,    2,4,11,  6,2,10,  8,6,7,   9,8,1
        };

        List<int> faceList = new List<int>(faces);

        // Subdivide
        for (int i = 0; i < subdivisions; i++)
        {
            List<int> newFaces = new List<int>();
            for (int f = 0; f < faceList.Count; f += 3)
            {
                int a = faceList[f];
                int b = faceList[f + 1];
                int c = faceList[f + 2];

                int ab = GetMiddlePoint(a, b, vertices);
                int bc = GetMiddlePoint(b, c, vertices);
                int ca = GetMiddlePoint(c, a, vertices);

                newFaces.Add(a);  newFaces.Add(ab); newFaces.Add(ca);
                newFaces.Add(b);  newFaces.Add(bc); newFaces.Add(ab);
                newFaces.Add(c);  newFaces.Add(ca); newFaces.Add(bc);
                newFaces.Add(ab); newFaces.Add(bc); newFaces.Add(ca);
            }
            faceList = newFaces;
        }

        // Apply radius + height noise + spikes
        for (int i = 0; i < vertices.Count; i++)
        {
            Vector3 dir = vertices[i].normalized; // base normal / direction
            float finalRadius = radius;

            if (useHeightNoise && (heightAmplitude > 0f || spikeAmplitude > 0f))
            {
                // Use spherical direction for stable noise on the surface
                float nx = dir.x * heightNoiseScale + heightNoiseOffset;
                float ny = dir.y * heightNoiseScale + heightNoiseOffset;

                float n = Mathf.PerlinNoise(nx, ny); // 0..1

                // Base displacement: small bumps around radius
                float baseHeight = (n - 0.5f) * 2f * heightAmplitude; // -amp..amp
                finalRadius += baseHeight;

                // Extra spike for high peaks (only when n is above the threshold)
                if (n > spikeThreshold && spikeAmplitude > 0f)
                {
                    // fade-in factor from threshold to 1
                    float spikeT = Mathf.InverseLerp(spikeThreshold, 1f, n);
                    spikeT = spikeT * spikeT; // sharpen a bit

                    float spike = spikeT * spikeAmplitude; // 0..spikeAmplitude
                    finalRadius += spike;
                }
            }

            vertices[i] = dir * finalRadius;
        }

        // Build mesh
        mesh.vertices = vertices.ToArray();
        mesh.triangles = faceList.ToArray();

        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        // UVs (simple spherical mapping)
        Vector2[] uvs = new Vector2[vertices.Count];
        for (int i = 0; i < vertices.Count; i++)
        {
            Vector3 v = vertices[i].normalized;
            float u = 0.5f + Mathf.Atan2(v.z, v.x) / (2f * Mathf.PI);
            float vCoord = 0.5f - Mathf.Asin(v.y) / Mathf.PI;
            uvs[i] = new Vector2(u, vCoord);
        }
        mesh.uv = uvs;

        GetComponent<MeshFilter>().sharedMesh = mesh;
    }

    void AddVertex(List<Vector3> v, Vector3 point)
    {
        v.Add(point);
    }

    long Key(int a, int b)
    {
        return ((long)Mathf.Min(a, b) << 32) + Mathf.Max(a, b);
    }

    int GetMiddlePoint(int a, int b, List<Vector3> vertices)
    {
        long key = Key(a, b);
        if (middlePointCache.TryGetValue(key, out int ret))
            return ret;

        Vector3 pa = vertices[a];
        Vector3 pb = vertices[b];
        Vector3 pm = ((pa + pb) * 0.5f).normalized;

        int i = vertices.Count;
        vertices.Add(pm);
        middlePointCache.Add(key, i);
        return i;
    }
}