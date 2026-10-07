#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <iostream>
#include "../library/vector_math.h"

#include <vector>

/***** generateEquatorArcPoints function generated with the assistance of Chat GPT. Slightly modified after creation. *****/
/*
	Prompt: Help me write a function in c++ to calculate points along an arc 
	on the surface of a sphere. I want to generate a number of points around 
	the equator of a sphere given a starting azimuth, ending azimuth, and 
	number of points
*/
std::vector<Vec3> generateEquatorArcPoints(
    double radius,
    double startAzimuth,
    double endAzimuth,
    int numPoints,
    bool degrees = true)
{
	std::vector<Vec3> points;
    if (numPoints < 2) {
        return points;
    }

    const double pi = 3.14159265358979323846;

    if (degrees) {
        startAzimuth = startAzimuth * pi / 180.0;
        endAzimuth = endAzimuth * pi / 180.0;
    }

    points.reserve(numPoints);

    for (int i = 0; i < numPoints; ++i) {
        double t = static_cast<double>(i) / (numPoints - 1);
        double theta = startAzimuth + t * (endAzimuth - startAzimuth);

        Vec3 p;
        p.x = radius * std::cos(theta);
        p.y = 0.0;
        p.z = radius * std::sin(theta);

        points.push_back(p);
    }

    return points;
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

/***** rayTriangleIntersect function code adapted from code from code implemented for course EN 605.767 - Applied computer graphics *****/
__device__ int rayTriangleIntersect(Vec3* origin, Vec3 direction, Triangle triangle)
{
    Vec3 e1 = vecSubtract(triangle.v1, triangle.v0);
    Vec3 e2 = vecSubtract(triangle.v2, triangle.v0);
    Vec3 q = vecCross(direction,e2);
    float a = vecDot(e1, q);

    if (a < d_epsilon) return 0;

    float f = 1.0f / a;
    Vec3 s = vecSubtract(*origin,triangle.v0);
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
__global__ void rayTraceKernel(Triangle* triangle, Vec3* camera, int* output)
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
    Vec3 direction = vecSubtract(screenPoint, *camera); //Calculate the direction of a ray through the pixel

    direction = vecNormalize(direction); //Normalize the direction vector

    int hit = rayTriangleIntersect(camera, direction, sharedTriangle); //Check if the ray intersects the triangle

    output[pixel] = hit;
}

int main(int argc, char** argv)
{
	/***** Read inputs and calculate number of threads and blocks *****/
    int blockSize = 256;
	if (argc >= 2) {
		blockSize = atoi(argv[1]);
	}

    int screenWidth = 512;
    if (argc >= 2) {
		screenWidth = atoi(argv[2]);
	}

    int screenHeight = 512;
    if (argc >= 3) {
		screenHeight = atoi(argv[3]);
	}

	int totalPixels = screenWidth * screenHeight;

	int blocks = (totalPixels + blockSize -1) / blockSize;
	/**********/

	//Generate camera positions
	std::vector<Vec3> cameras = generateEquatorArcPoints(5.0, 0.0, 180.0, 5);
	if (cameras.size() == 0)
	{
		return 0;
	}

	/***** Allocate device and host memory for later calculations *****/
	cudaStream_t* streams;
	cudaMallocHost((void**)&streams, cameras.size() * sizeof(cudaStream_t));

	int** outputs;
	cudaMallocHost((void**)&outputs, cameras.size() * sizeof(int*));

	Triangle* d_triangle;
	cudaMalloc((void**)&d_triangle, sizeof(Triangle));

	Vec3** d_cameras;
	cudaMallocHost((void**)&d_cameras, cameras.size() * sizeof(Vec3*));

	int** d_outputs;
	cudaMallocHost((void**)&d_outputs, cameras.size() * sizeof(int*));

	for (int i = 0; i < cameras.size(); i++) {
		cudaStreamCreate(&streams[i]);
		cudaMalloc((void**)&d_cameras[i], sizeof(Vec3));
		cudaMalloc((void**)&d_outputs[i], totalPixels * sizeof(int));
		cudaMallocHost((void**)&outputs[i], totalPixels * sizeof(int));
	}

	//Epsilon for ray-triangle intersection to account for floating point rounding errors
	float epsilon = 1.0e-5; 
	cudaMemcpyToSymbol(d_screenWidth, &screenWidth, sizeof(int), 0, cudaMemcpyHostToDevice);
	cudaMemcpyToSymbol(d_screenHeight, &screenHeight, sizeof(int), 0, cudaMemcpyHostToDevice);
	cudaMemcpyToSymbol(d_epsilon, &epsilon, sizeof(float), 0, cudaMemcpyHostToDevice);

    Triangle* triangle;
	cudaMallocHost((void**)&triangle, sizeof(Triangle));
    triangle->v0 = makeVec3(-0.25f, -0.25f, 0.0f);
    triangle->v1 = makeVec3(0.25f, -0.25f, 0.0f);
    triangle->v2 = makeVec3(0.00f, 0.25f, 0.0f);
	cudaMemcpy(d_triangle, triangle, sizeof(Triangle), cudaMemcpyHostToDevice);
	/**********/

	//Lazy way to load ray trace kernel for later timing
	rayTraceKernel<<<blocks, blockSize, 1>>>(d_triangle, d_cameras[0], d_outputs[0]);

	cudaEvent_t kernel_start1, kernel_stop1;
	float delta_time1 = 0.0f;
	float delta_time2 = 0.0f;
	cudaEventCreate(&kernel_start1);
	cudaEventCreateWithFlags(&kernel_stop1, cudaEventBlockingSync);

	cudaEventRecord(kernel_start1,0);

	//Run ray trace kernel sequentially for comparison
	for(int i = 0; i < cameras.size(); i++) {
		cudaMemcpyAsync(d_cameras[i], &cameras[i], sizeof(Vec3), cudaMemcpyHostToDevice);

		rayTraceKernel<<<blocks, blockSize>>>(d_triangle, d_cameras[i], d_outputs[i]);

		cudaMemcpyAsync(outputs[i], d_outputs[i], totalPixels * sizeof(int), cudaMemcpyDeviceToHost);
	}

	cudaEventRecord(kernel_stop1,0);
	cudaEventSynchronize(kernel_stop1);
	cudaEventElapsedTime(&delta_time1, kernel_start1, kernel_stop1);

	cudaDeviceSynchronize();

	cudaEventRecord(kernel_start1,0);

	//Run ray trace kernel concurrently using CUDA streams
	for(int i = 0; i < cameras.size(); i++) {
		cudaMemcpyAsync(d_cameras[i], &cameras[i], sizeof(Vec3), cudaMemcpyHostToDevice, streams[i]);

		rayTraceKernel<<<blocks, blockSize, 0, streams[i]>>>(d_triangle, d_cameras[i], d_outputs[i]);

		cudaMemcpyAsync(outputs[i], d_outputs[i], totalPixels * sizeof(int), cudaMemcpyDeviceToHost, streams[i]);
	}

	cudaEventRecord(kernel_stop1,0);
	cudaEventSynchronize(kernel_stop1);
	cudaEventElapsedTime(&delta_time2, kernel_start1, kernel_stop1);

	cudaDeviceSynchronize();

	printf("Synchronous Ray trace kernel took: %.5fms\n ", delta_time1);
	printf("Stream Ray trace kernel took: %.5fms\n ", delta_time2);

	/***** Free device and host memory *****/
    cudaFree(d_triangle);
	for (int i = 0; i < cameras.size(); i++) {
		cudaStreamDestroy(streams[i]);
		cudaFree(d_cameras[i]);
		cudaFree(d_outputs[i]);
		cudaFreeHost(outputs[i]);
	}

	cudaFreeHost(d_cameras);
	cudaFreeHost(d_outputs);
	cudaFreeHost(streams);
    cudaFreeHost(triangle);
    cudaFreeHost(outputs);
	/**********/

    return 0;
}
