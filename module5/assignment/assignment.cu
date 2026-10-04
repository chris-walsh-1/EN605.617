#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

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

struct Triangle
{
    Vec3 v0;
    Vec3 v1;
    Vec3 v2;
};

__constant__ int d_screenWidth;
__constant__ int d_screenHeight;
__constant__ float d_epsilon;
__constant__ Vec3 d_camera;

/***** rayTriangleIntersect function code adapted from code from code implemented for course EN 605.767 - Applied computer graphics *****/
__device__ int rayTriangleIntersect(Vec3 origin, Vec3 direction, Triangle triangle)
{
    Vec3 e1 = vecSubtract(triangle.v1, triangle.v0);
    Vec3 e2 = vecSubtract(triangle.v2, triangle.v0);
    Vec3 q = vecCross(direction,e2);
    float a = vecDot(e1, q);

    if (a < d_epsilon) return 0;

    float f = 1.0f / a;
    Vec3 s = vecSubtract(origin,triangle.v0);
    float u = f * vecDot(s, q);

    if (u < d_epsilon) return 0;

    Vec3 r = vecCross(s, e1);
    float v = f * vecDot(direction, r);

    if (v < d_epsilon || (u + v) > 1.0f) return 0;

    float t = f * vecDot(e2, r);

    if (t < d_epsilon) return 0;

    return 1;
}

/***** Kernel to trace rays from a camera through a pixel to determine if they intersect a triangle *****/
__global__ void rayTraceKernel(Triangle* triangle, int* output)
{
    __shared__ Triangle sharedTriangle; //Triangle shared in a block

    int pixel = blockIdx.x * blockDim.x + threadIdx.x; //This thread's pixel index

    int totalPixels = d_screenWidth * d_screenHeight; //Total number of pixels in the screen

    //Set up return flag for threads beyond the total number of pixels
    bool shouldReturn = false; 
    if (pixel >= totalPixels)
    {
        shouldReturn = true;
    }

    //Copy triangle to shared memory
    if (threadIdx.x == 0)
    {
        sharedTriangle = *triangle;
    }

    __syncthreads(); //Wait until triangle is copied to memory

    if (shouldReturn)
    {
        return; //Exit if the tread's ID is greater than the total number of pixels
    }

    int x = pixel % d_screenWidth; //Get this pixel's x coordinate
    int y = pixel / d_screenWidth; //Get this pixel's y coordinate

    float screenX = ((float)x / (float)d_screenWidth) - 0.5f; //Normalize x coordinate to [-0.5, 0.5]
    float screenY = ((float)y / (float)d_screenHeight) - 0.5f; //Normalize y coordinate to [-0.5, 0.5]

    Vec3 screenPoint = makeVec3(screenX, screenY, 0.0f); //Get a point representing the pixel
    Vec3 direction = vecSubtract(screenPoint, d_camera); //Calculate the direction of a ray through the pixel

    direction = vecNormalize(direction); //Normalize the direction vector

    int hit = rayTriangleIntersect(d_camera, direction, sharedTriangle); //Check if the ray intersects the triangle

    output[pixel] = hit;
}

int main(int argc, char** argv)
{
    int blockSize = 256;
	if (argc >= 2) {
		blockSize = atoi(argv[1]);
	}

    int screenWidth = 512;
    if (argc >= 2) {
		screenWidth = atoi(argv[2]);
	}

    int screenHeight = 512;
    if (argc >= 2) {
		screenHeight = atoi(argv[3]);
	}

    int totalPixels = screenWidth * screenHeight;

    Triangle* triangle = (Triangle*)malloc(sizeof(Triangle));
    triangle->v0 = makeVec3(-0.5f, -0.5f, 0.0f);
    triangle->v1 = makeVec3(0.5f, -0.5f, 0.0f);
    triangle->v2 = makeVec3(0.0f, 0.5f, 0.0f);

    Vec3 camera = makeVec3(0.0f, 0.0f, 5.0f);

    int* output = (int*)malloc(totalPixels * sizeof(int));

    Triangle* d_triangle;
    int* d_output;

    cudaMalloc((void**)&d_triangle, sizeof(Triangle));
    cudaMalloc((void**)&d_output, totalPixels * sizeof(int));

    cudaEvent_t kernel_start1, kernel_stop1;
    float delta_time1 = 0.0f;

    cudaEventCreate(&kernel_start1);
    cudaEventCreateWithFlags(&kernel_stop1, cudaEventBlockingSync);

    cudaMemcpy(d_triangle, triangle, sizeof(Triangle), cudaMemcpyHostToDevice);

    //Epsilon for ray-triangle intersection to account for floating point rounding errors
    float epsilon = 1.0e-5; 

    cudaMemcpyToSymbol(d_screenWidth, &screenWidth, sizeof(int));
    cudaMemcpyToSymbol(d_screenHeight, &screenHeight, sizeof(int));
    cudaMemcpyToSymbol(d_epsilon, &epsilon, sizeof(float));
    cudaMemcpyToSymbol(d_camera, &camera, sizeof(Vec3));

    int blocks = (totalPixels + blockSize -1) / blockSize;

    rayTraceKernel<<<blocks, blockSize>>>(d_triangle, d_output);

    cudaDeviceSynchronize();

    cudaEventRecord(kernel_start1,0);

    rayTraceKernel<<<blocks, blockSize>>>(d_triangle, d_output);

    cudaEventRecord(kernel_stop1,0);
    cudaEventSynchronize(kernel_stop1);
    cudaEventElapsedTime(&delta_time1, kernel_start1, kernel_stop1);

    cudaDeviceSynchronize();

    cudaMemcpy(output, d_output, totalPixels * sizeof(int), cudaMemcpyDeviceToHost);

    int hitCount = 0;

    for (int i = 0; i < totalPixels; i++)
    {
        if (output[i] == 1)
        {
            hitCount++;
        }
    }

    printf("Pixels hitting triangle: %d\n", hitCount);
    printf("Ray trace kernel took: %.5fms ", delta_time1);

    cudaFree(d_triangle);
    cudaFree(d_output);

    free(triangle);
    free(output);

    return 0;
}
