/***** Vec3 struct and functions generated with the assistance of Chat GPT. *****/
/* 
    Prompt: Generate a struct for me representing a 3D vector. 
    Name it Vec3, and generate functions for common operations including 
    addition, subtraction, multiplication dot and cross products, length, 
    and normalization
*/
struct Vec3
{
    float x;
    float y;
    float z;
};

__host__ __device__ Vec3 makeVec3(float x, float y, float z)
{
    Vec3 result;

    result.x = x;
    result.y = y;
    result.z = z;

    return result;
}


__host__ __device__ Vec3 vecAdd(Vec3 a, Vec3 b)
{
    Vec3 result;

    result.x = a.x + b.x;
    result.y = a.y + b.y;
    result.z = a.z + b.z;

    return result;
}


__host__ __device__ Vec3 vecSubtract(Vec3 a, Vec3 b)
{
    Vec3 result;

    result.x = a.x - b.x;
    result.y = a.y - b.y;
    result.z = a.z - b.z;

    return result;
}


__host__ __device__ Vec3 vecMultiply(Vec3 a, float value)
{
    Vec3 result;

    result.x = a.x * value;
    result.y = a.y * value;
    result.z = a.z * value;

    return result;
}


__host__ __device__ float vecDot(Vec3 a, Vec3 b)
{
    return a.x * b.x + a.y * b.y + a.z * b.z;
}


__host__ __device__ Vec3 vecCross(Vec3 a, Vec3 b)
{
    Vec3 result;

    result.x = a.y * b.z - a.z * b.y;
    result.y = a.z * b.x - a.x * b.z;
    result.z = a.x * b.y - a.y * b.x;

    return result;
}


__host__ __device__ float vecLength(Vec3 a)
{
    return sqrtf(vecDot(a, a));
}


__host__ __device__ Vec3 vecNormalize(Vec3 a)
{
    float length = vecLength(a);

    if (length == 0.0f)
    {
        return makeVec3(0.0f, 0.0f, 0.0f);
    }

    return vecMultiply(a, 1.0f / length);
}
/***** End of generated code *****/