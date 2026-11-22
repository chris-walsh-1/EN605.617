#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cmath>

#include "info.hpp"

#include "../library/vector_math_cl.h"

#define DEFAULT_PLATFORM 0
#define NUM_QUEUES 4

// Each camera gets its own sub-buffer of this many elements
// OpenCL requires every sub-buffer to start
// at a multiple of the device's alignment (CL_DEVICE_MEM_BASE_ADDR_ALIGN),
// which is at most a few hundred bytes on common devices. 256 elements * 4 bytes
// = 1024 bytes, so every sub-buffer start offset is aligned. Only the first
// element of each is used (3 floats for a camera position, 1 int for a flag).

//Slot elements was a suggestion provided by Chat GPT
#define SLOT_ELEMENTS 256

/***** Cube model generated with Chat GPT *****/
// Hard-coded unit cube centerd on the origin: 8 vertices (x, y, z) and
// 12 triangles (3 vertex indices each, two triangles per face).
#define NUM_VERTICES  8
#define NUM_TRIANGLES 12

static const float cubeVertices[NUM_VERTICES * 3] =
{
    -0.5f, -0.5f, -0.5f,   // 0
     0.5f, -0.5f, -0.5f,   // 1
     0.5f,  0.5f, -0.5f,   // 2
    -0.5f,  0.5f, -0.5f,   // 3
    -0.5f, -0.5f,  0.5f,   // 4
     0.5f, -0.5f,  0.5f,   // 5
     0.5f,  0.5f,  0.5f,   // 6
    -0.5f,  0.5f,  0.5f    // 7
};

static const cl_uint cubeIndices[NUM_TRIANGLES * 3] =
{
    0, 2, 1,   0, 3, 2,    // -z face
    4, 5, 6,   4, 6, 7,    // +z face
    0, 1, 5,   0, 5, 4,    // -y face
    3, 6, 2,   3, 7, 6,    // +y face
    0, 4, 7,   0, 7, 3,    // -x face
    1, 2, 6,   1, 6, 5     // +x face
};

// Look up a cube vertex by index
static Vec3 cubeVertex(cl_uint index)
{
    return makeVec3(cubeVertices[index * 3 + 0],
                    cubeVertices[index * 3 + 1],
                    cubeVertices[index * 3 + 2]);
}
/**********/

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

/***** generateSphereArcPoints function generated with the assistance of Chat GPT after generateEquatorArcPoints *****/
std::vector<Vec3> generateSphereArcPoints(
    double radius,
    double startAzimuth,
    double endAzimuth,
    double startPolar,
    double endPolar,
    int numPoints,
    bool degrees = true)
{
    std::vector<Vec3> points;

    if (numPoints < 2) {
        return points;
    }

    const double pi = 3.14159265358979323846;

    if (degrees) {
        startAzimuth *= pi / 180.0;
        endAzimuth   *= pi / 180.0;
        startPolar   *= pi / 180.0;
        endPolar     *= pi / 180.0;
    }

    points.reserve(numPoints * numPoints);

    for (int i = 0; i < numPoints; ++i) {
        double t = static_cast<double>(i) / (numPoints - 1);
        double theta = startAzimuth +
                       t * (endAzimuth - startAzimuth);

        for (int j = 0; j < numPoints; ++j) {
            double u = static_cast<double>(j) / (numPoints - 1);
            double phi = startPolar +
                         u * (endPolar - startPolar);

            Vec3 p;
            p.x = radius * std::sin(phi) * std::cos(theta);
            p.y = radius * std::cos(phi);
            p.z = radius * std::sin(phi) * std::sin(theta);

            points.push_back(p);
        }
    }

    return points;
}
/***** End of generated code *****/

// Function to check and handle OpenCL errors
inline void 
checkErr(cl_int err, const char * name)
{
    if (err != CL_SUCCESS) {
        std::cerr << "ERROR: " <<  name << " (" << err << ")" << std::endl;
        exit(EXIT_FAILURE);
    }
}

int main(int argc, char** argv)
{	
    int az_el_points = 30;
	if (argc >= 2) {
		az_el_points = atoi(argv[1]);
	}
    int num_queues = NUM_QUEUES;
	if (argc >= 3) {
		num_queues = atoi(argv[2]);
	}


	cl_int errNum;
    cl_uint numPlatforms;
    cl_uint numDevices;
    cl_platform_id * platformIDs;
    cl_device_id * deviceIDs;
    cl_context context;
    cl_program program;
    cl_kernel kernel;
    std::vector<cl_command_queue> queues;

    int platform = DEFAULT_PLATFORM; 

    int blockSize = 256;

    std::cout << "Surface Visibility Detection in OpenCL" << std::endl;

    // for (int i = 1; i < argc; i++)
    // {
    //     std::string input(argv[i]);

    //     if (!input.compare("--platform"))
    //     {
    //         input = std::string(argv[++i]);
    //         std::istringstream buffer(input);
    //         buffer >> platform;
    //     }
    //     else
    //     {
    //         std::cout << "usage: --platform n --useMap" << std::endl;
    //         return 0;
    //     }
    // }

    /***** Set up target information *****/
	int totalTriangles = NUM_TRIANGLES;

    std::vector<Vec3> cameras = generateSphereArcPoints(5.0, 0.0, 360.0, 40.0, 120.0, az_el_points);
    if (cameras.size() == 0)
	{
		return 0;
	}

    const int numCameras = (int)cameras.size();
    const int targetTri  = 0;

    Vec3 v0 = cubeVertex(cubeIndices[targetTri * 3]);
    Vec3 v1 = cubeVertex(cubeIndices[targetTri * 3 + 1]);
    Vec3 v2 = cubeVertex(cubeIndices[targetTri * 3 + 2]);
    Vec3 targetCenter = vecMultiply(vecAdd(v0, vecAdd(v1, v2)), 1.0f / 3.0f);

    std::cout << "Triangle " << targetTri << ": ("
              << v0.x << ", " << v0.y << ", " << v0.z << "), ("
              << v1.x << ", " << v1.y << ", " << v1.z << "), ("
              << v2.x << ", " << v2.y << ", " << v2.z << ")" << std::endl;
    std::cout << "Target Center: (" << targetCenter.x << ", "
              << targetCenter.y << ", " << targetCenter.z << ")" << std::endl;

    /**********/

    /***** Boilerplate to set up OpenCL platform, device, and program *****/
    // First, select an OpenCL platform to run on.  
    errNum = clGetPlatformIDs(0, NULL, &numPlatforms);
    checkErr( 
        (errNum != CL_SUCCESS) ? errNum : (numPlatforms <= 0 ? -1 : CL_SUCCESS), 
        "clGetPlatformIDs"); 
 
    platformIDs = (cl_platform_id *)alloca(
            sizeof(cl_platform_id) * numPlatforms);

    std::cout << "Number of platforms: \t" << numPlatforms << std::endl; 

    errNum = clGetPlatformIDs(numPlatforms, platformIDs, NULL);
    checkErr( 
       (errNum != CL_SUCCESS) ? errNum : (numPlatforms <= 0 ? -1 : CL_SUCCESS), 
       "clGetPlatformIDs");

    std::ifstream srcFile("assignment.cl");
    checkErr(srcFile.is_open() ? CL_SUCCESS : -1, "reading assignment.cl");

    std::string srcProg(
        std::istreambuf_iterator<char>(srcFile),
        (std::istreambuf_iterator<char>()));

    const char * src = srcProg.c_str();
    size_t length = srcProg.length();

    deviceIDs = NULL;
    DisplayPlatformInfo(
        platformIDs[platform], 
        CL_PLATFORM_VENDOR, 
        "CL_PLATFORM_VENDOR");

    errNum = clGetDeviceIDs(
        platformIDs[platform], 
        CL_DEVICE_TYPE_ALL, 
        0,
        NULL,
        &numDevices);
    if (errNum != CL_SUCCESS && errNum != CL_DEVICE_NOT_FOUND)
    {
        checkErr(errNum, "clGetDeviceIDs");
    }       

    deviceIDs = (cl_device_id *)alloca(sizeof(cl_device_id) * numDevices);
    errNum = clGetDeviceIDs(
        platformIDs[platform],
        CL_DEVICE_TYPE_ALL,
        numDevices, 
        &deviceIDs[0], 
        NULL);
    checkErr(errNum, "clGetDeviceIDs");

    cl_device_id device = deviceIDs[0];

    cl_context_properties contextProperties[] =
    {
        CL_CONTEXT_PLATFORM,
        (cl_context_properties)platformIDs[platform],
        0
    };

    context = clCreateContext(
        contextProperties, 
        1,
        &device, 
        NULL,
        NULL, 
        &errNum);
    checkErr(errNum, "clCreateContext");

    // Create program from source
    program = clCreateProgramWithSource(
        context, 
        1, 
        &src, 
        &length, 
        &errNum);
    checkErr(errNum, "clCreateProgramWithSource");

    // Build program
    errNum = clBuildProgram(
        program,
        numDevices,
        deviceIDs,
        "-I.",
        NULL,
        NULL);
    if (errNum != CL_SUCCESS) 
    {
        // Determine the reason for the error
        char buildLog[16384];
        clGetProgramBuildInfo(
            program, 
            deviceIDs[0], 
            CL_PROGRAM_BUILD_LOG,
            sizeof(buildLog), 
            buildLog, 
            NULL);

            std::cerr << "Error in OpenCL C source: " << std::endl;
            std::cerr << buildLog;
            checkErr(errNum, "clBuildProgram");
    }

    kernel = clCreateKernel(
            program,
            "rayTraceKernel",
            &errNum);
    checkErr(errNum, "clCreateKernel(rayTraceKernel)");

    for (int i = 0; i < num_queues; i++)
    {
        cl_command_queue queue = 
            clCreateCommandQueue(
                context,
                device,
                0,
                &errNum);
        checkErr(errNum, "clCreateCommandQueue");

        queues.push_back(queue);
    }
    /**********/

    /***** Set up buffers and sub-buffers *****/
    cl_mem vertexBuffer = clCreateBuffer(
        context,
        CL_MEM_READ_ONLY,
        sizeof(cubeVertices),
        NULL,
        &errNum);
    checkErr(errNum, "clCreateBuffer(vertices)");

    cl_mem indexBuffer = clCreateBuffer(
        context,
        CL_MEM_READ_ONLY,
        sizeof(cubeIndices),
        NULL,
        &errNum);
    checkErr(errNum, "clCreateBuffer(indices)");

    cl_mem cameraMain = clCreateBuffer(
        context,
        CL_MEM_READ_ONLY,
        sizeof(float) * SLOT_ELEMENTS * numCameras,
        NULL,
        &errNum);
    checkErr(errNum, "clCreateBuffer(cameras)");

    cl_mem occludedMain = clCreateBuffer(
        context,
        CL_MEM_READ_WRITE,
        sizeof(cl_int) * SLOT_ELEMENTS * numCameras,
        NULL,
        &errNum);
    checkErr(errNum, "clCreateBuffer(occluded)");

    // Create one sub-buffer per camera out of each of the two main buffers
    std::vector<cl_mem> cameraBuffers;
    std::vector<cl_mem> occludedBuffers;

    for (int i = 0; i < numCameras; i++)
    {
        cl_buffer_region cameraRegion =
        {
            SLOT_ELEMENTS * i * sizeof(float),
            SLOT_ELEMENTS * sizeof(float)
        };

        cl_mem cameraSub = clCreateSubBuffer(
            cameraMain,
            CL_MEM_READ_ONLY,
            CL_BUFFER_CREATE_TYPE_REGION,
            &cameraRegion,
            &errNum);
        checkErr(errNum, "clCreateSubBuffer(camera)");

        cameraBuffers.push_back(cameraSub);

        cl_buffer_region occludedRegion =
        {
            SLOT_ELEMENTS * i * sizeof(cl_int),
            SLOT_ELEMENTS * sizeof(cl_int)
        };

        cl_mem occludedSub = clCreateSubBuffer(
            occludedMain,
            CL_MEM_READ_WRITE,
            CL_BUFFER_CREATE_TYPE_REGION,
            &occludedRegion,
            &errNum);
        checkErr(errNum, "clCreateSubBuffer(occluded)");

        occludedBuffers.push_back(occludedSub);
    }
    /**********/

    /***** Set up data to copy to buffers *****/
    std::vector<float> cameraHost(SLOT_ELEMENTS * numCameras, 0.0f);
    for (int i = 0; i < numCameras; i++)
    {
        cameraHost[i * SLOT_ELEMENTS + 0] = cameras[i].x;
        cameraHost[i * SLOT_ELEMENTS + 1] = cameras[i].y;
        cameraHost[i * SLOT_ELEMENTS + 2] = cameras[i].z;
    }

    // All flags start at 0 (not occluded)
    std::vector<cl_int> occludedHost(SLOT_ELEMENTS * numCameras, 0);

    // Write vertices
    errNum = clEnqueueWriteBuffer(
        queues[0],
        vertexBuffer,
        CL_TRUE,
        0,
        sizeof(cubeVertices),
        (void*)cubeVertices,
        0,
        NULL,
        NULL);
    checkErr(errNum, "clEnqueueWriteBuffer(vertices)");

    // Write indices
    errNum = clEnqueueWriteBuffer(
        queues[0],
        indexBuffer,
        CL_TRUE,
        0,
        sizeof(cubeIndices),
        (void*)cubeIndices,
        0,
        NULL,
        NULL);
    checkErr(errNum, "clEnqueueWriteBuffer(indices)");

    // Clear the occlusion flags
    errNum = clEnqueueWriteBuffer(
        queues[0],
        occludedMain,
        CL_TRUE,
        0,
        sizeof(cl_int) * SLOT_ELEMENTS * numCameras,
        (void*)occludedHost.data(),
        0,
        NULL,
        NULL);
    checkErr(errNum, "clEnqueueWriteBuffer(occluded)");

    // Write camera positions
    errNum = clEnqueueWriteBuffer(
        queues[0],
        cameraMain,
        CL_TRUE,
        0,
        sizeof(float) * SLOT_ELEMENTS * numCameras,
        (void*)cameraHost.data(),
        0,
        NULL,
        NULL);
    checkErr(errNum, "clEnqueueWriteBuffer(cameras)");
    /**********/

    /***** Set up kernel arguments and run kernel *****/
    const float epsilon = 1.0e-5f;
    cl_float4 clTargetCenter = {{ targetCenter.x, targetCenter.y, targetCenter.z, 0.0f }};

    size_t localSize  = (size_t)blockSize;
    size_t globalSize = ((totalTriangles + blockSize - 1) / blockSize) * blockSize;

    std::vector<cl_event> events;

    for (int i = 0; i < numCameras; i++)
    {
        float distance = vecLength(vecSubtract(cameras[i], targetCenter));

        errNum  = clSetKernelArg(kernel, 0, sizeof(cl_int),    &totalTriangles);
        errNum |= clSetKernelArg(kernel, 1, sizeof(cl_float),  &distance);
        errNum |= clSetKernelArg(kernel, 2, sizeof(cl_float4), &clTargetCenter);
        errNum |= clSetKernelArg(kernel, 3, sizeof(cl_mem),    &vertexBuffer);
        errNum |= clSetKernelArg(kernel, 4, sizeof(cl_mem),    &indexBuffer);
        errNum |= clSetKernelArg(kernel, 5, sizeof(cl_mem),    &cameraBuffers[i]);
        errNum |= clSetKernelArg(kernel, 6, sizeof(cl_mem),    &occludedBuffers[i]);
        errNum |= clSetKernelArg(kernel, 7, sizeof(cl_float),  &epsilon);
        checkErr(errNum, "clSetKernelArg(rayTraceKernel)");

        cl_event event;
        errNum = clEnqueueNDRangeKernel(
            queues[i % num_queues],
            kernel,
            1,
            NULL,
            (const size_t*)&globalSize,
            (const size_t*)&localSize,
            0,
            0,
            &event);
        checkErr(errNum, "clEnqueueNDRangeKernel");
        events.push_back(event);
    }

    errNum = clWaitForEvents(events.size(), &events[0]);
    checkErr(errNum, "clWaitForEvents");
    /**********/

    /***** Read back the occlusion results and print*****/
    errNum = clEnqueueReadBuffer(
        queues[0],
        occludedMain,
        CL_TRUE,
        0,
        sizeof(cl_int) * SLOT_ELEMENTS * numCameras,
        (void*)occludedHost.data(),
        0,
        NULL,
        NULL);
    checkErr(errNum, "clEnqueueReadBuffer(occluded)");

    int numVisible = 0;

    for (int i = 0; i < numCameras; i++)
    {
        bool visible = (occludedHost[SLOT_ELEMENTS  * i] == 0);
        if (visible) numVisible++;

        std::cout << "Camera " << i << " ("
                  << cameras[i].x << ", " << cameras[i].y << ", " << cameras[i].z << "): "
                  << (visible ? "VISIBLE" : "OCCLUDED") << std::endl;
    }

    std::cout << "Target triangle " << targetTri << " is visible from "
              << numVisible << " of " << numCameras << " cameras" << std::endl;
    /**********/

    /***** Clean up *****/
    for (int i = 0; i < numCameras; i++)
    {
        clReleaseMemObject(cameraBuffers[i]);
        clReleaseMemObject(occludedBuffers[i]);
    }
    clReleaseMemObject(cameraMain);
    clReleaseMemObject(occludedMain);
    clReleaseMemObject(vertexBuffer);
    clReleaseMemObject(indexBuffer);
    for (int i = 0; i < num_queues; i++) clReleaseCommandQueue(queues[i]);
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseContext(context);
    /**********/

    return 0;
}
