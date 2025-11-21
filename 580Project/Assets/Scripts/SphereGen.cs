using UnityEngine;
using System.Collections.Generic;

[ExecuteAlways]
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class SphereGen : MonoBehaviour
{
    [Range(0, 6)]
    public int subdivisions = 3;
    public float radius = 1f;

    Mesh mesh;
    Dictionary<long, int> middlePointCache;

    void OnValidate()
    {
        Generate();
    }

    void Generate()
    {
        mesh = new Mesh();
        mesh.name = "Procedural Icosphere";

        middlePointCache = new Dictionary<long, int>();

        List<Vector3> vertices = new List<Vector3>();
        List<int> triangles = new List<int>();

        float t = (1.0f + Mathf.Sqrt(5.0f)) / 2.0f;

        // Create 12 initial vertices
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

                newFaces.AddRange(new int[] { a, ab, ca });
                newFaces.AddRange(new int[] { b, bc, ab });
                newFaces.AddRange(new int[] { c, ca, bc });
                newFaces.AddRange(new int[] { ab, bc, ca });
            }
            faceList = newFaces;
        }

        // Build final mesh
        for (int i = 0; i < vertices.Count; i++)
            vertices[i] = vertices[i].normalized * radius;

        mesh.vertices = vertices.ToArray();
        mesh.triangles = faceList.ToArray();
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

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
