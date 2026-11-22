//
// raytrace.cl
//
// OpenCL port of the CUDA rayTriangleIntersect() device function and
// rayTraceKernel() from final_project/assignment.cu.
//

float rayTriangleIntersect(float3 origin, float3 direction,
                           float3 v0, float3 v1, float3 v2, float epsilon)
{
    float3 e1 = v1 - v0;
    float3 e2 = v2 - v0;
    float3 q  = cross(direction, e2);
    float  a  = dot(e1, q);
    if (a < epsilon) return 0.0f;

    float  f = 1.0f / a;
    float3 s = origin - v0;
    float  u = f * dot(s, q);
    if (u < epsilon) return 0.0f;

    float3 r = cross(s, e1);
    float  v = f * dot(direction, r);
    if (v < epsilon || (u + v) > 1.0f) return 0.0f;

    float t = f * dot(e2, r);
    if (t < epsilon) return 0.0f;
    return t;
}

/***** Kernel to trace rays from a camera through a pixel to determine if they intersect a triangle *****/
__kernel void rayTraceKernel(const int totalTriangles,
                             const float distance,
                             const float4 targetCenter,
                             __global const float *vertices,
                             __global const uint  *indices,
                             __global const float *camera,
                             __global volatile int *occluded,
                             const float epsilon)
{
    int triangle = get_global_id(0); //This thread's pixel index

    //Set up return flag for threads beyond the total number of pixels
    if (triangle >= totalTriangles)
    {
        return;
    }

    float3 cam = vload3(0, camera);

    float3 v0 = vload3(indices[triangle * 3 + 0], vertices);
    float3 v1 = vload3(indices[triangle * 3 + 1], vertices);
    float3 v2 = vload3(indices[triangle * 3 + 2], vertices);

    float3 direction = normalize(targetCenter.xyz - cam); //Calculate the direction of a ray through the pixel

    float hit = rayTriangleIntersect(cam, direction, v0, v1, v2, epsilon); //Check if the ray intersects the triangle

    if (hit > 0.0f && hit < distance - epsilon)
    {
        atomic_or(occluded, 1);
    }
}
