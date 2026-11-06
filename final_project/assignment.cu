#include <GL/glew.h>
#include <SDL3/SDL.h>

#include <cuda_runtime.h>
#include <cuda_gl_interop.h>

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <vector>

#include "../library/vector_math.h"
#include "../library/model_loader.h"

/***** Shaders *****/
static const char* meshVS = R"(#version 430 core
layout(location=0) in vec3 aPos;
uniform mat4 uMVP;
out vec3 vPos;
void main(){ vPos = aPos; gl_Position = uMVP * vec4(aPos,1.0); })";

static const char* meshFS = R"(#version 430 core
layout(std430, binding=0) buffer Occ { float occ[]; };
uniform int uTargetTri;
in vec3 vPos;
out vec4 frag;
void main(){
    vec3 n = normalize(cross(dFdx(vPos), dFdy(vPos)));
    float shade = 0.35 + 0.65 * abs(dot(n, normalize(vec3(0.4,0.8,0.6))));
    vec3 base = vec3(0.7);                                    // neutral
    if (occ[gl_PrimitiveID] > 0.0) base = vec3(0.9,0.15,0.15); // occluder
    if (gl_PrimitiveID == uTargetTri) base = vec3(0.15,0.85,0.25); // target
    frag = vec4(base * shade, 1.0);
})";

static const char* lineVS = R"(#version 430 core
layout(location=0) in vec3 aPos;
uniform mat4 uMVP;
void main(){ gl_Position = uMVP * vec4(aPos,1.0); })";

static const char* lineFS = R"(#version 430 core
uniform vec4 uColor;
out vec4 frag;
void main(){ frag = uColor; })";

void log_compile_error(GLuint shader)
{
    GLint   len = 0;
    GLsizei slen = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &len);
    if(len > 1)
    {
        GLchar *compilerlog = (GLchar *)new GLchar *[len];
        glGetShaderInfoLog(shader, len, &slen, compilerlog);
        std::cout << "compiler log:\n" << compilerlog << '\n';
        delete[] compilerlog;
    }
}

bool check_compile_status(GLuint shader)
{
    int param = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &param);
    return (param == GL_TRUE);
}

bool check_link_status(GLuint shader_program_)
{
    int param = 0;
    glGetProgramiv(shader_program_, GL_LINK_STATUS, &param);
    return (param == GL_TRUE);
}

void log_link_error(GLuint shader_program_)
{
    GLint   len = 0;
    GLsizei slen = 0;
    glGetProgramiv(shader_program_, GL_INFO_LOG_LENGTH, &len);
    if(len > 1)
    {
        GLchar *linklog = (GLchar *)new GLchar *[len];
        glGetProgramInfoLog(shader_program_, len, &slen, linklog);
        std::cout << "Program Link Log:\n" << linklog << '\n';
        delete[] linklog;
    }
}

static GLuint createShaderProgram(const char* vs, const char* fs) {
    GLuint vertex_shader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertex_shader, 1, &vs, NULL);
    glCompileShader(vertex_shader);
    if(!check_compile_status(vertex_shader))
    {
        std::cout << "Vertex" << " shader compile failed.\n";
        log_compile_error(vertex_shader);
        std::cout << "Vertex" << " Shader Source = \n";
        std::cout << vs << '\n';
        return 0;
    }

    GLuint fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragment_shader, 1, &fs, NULL);
    glCompileShader(fragment_shader);
    if(!check_compile_status(fragment_shader))
    {
        std::cout << "Fragment" << " shader compile failed.\n";
        log_compile_error(fragment_shader);
        std::cout << "Fragment" << " Shader Source = \n";
        std::cout << fs << '\n';
        return 0;
    }

    GLuint shader_program_ = glCreateProgram();

    glAttachShader(shader_program_, vertex_shader);
    glAttachShader(shader_program_, fragment_shader);
    glLinkProgram(shader_program_);
    if(!check_link_status(shader_program_))
    {
        std::cout << "Shader link failed\n";
        log_link_error(shader_program_);
        return 0;
    }
    return shader_program_;
}
/***** End of Shader Section ******/

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

struct Triangle
{
    Vec3 v0;
    Vec3 v1;
    Vec3 v2;
};

__constant__ float d_epsilon;

/***** Simple orbit camera *****/
struct Camera { float yaw = 0.6f, pitch = 0.4f, dist = 12.f; glm::vec3 target{0}; } cam;

/***** rayTriangleIntersect function code adapted from code from code implemented for course EN 605.767 - Applied computer graphics *****/
__device__ float rayTriangleIntersect(Vec3* origin, Vec3 direction, Triangle triangle)
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

    return t;
}

/***** Kernel to trace rays from a camera through a pixel to determine if they intersect a triangle *****/
__global__ void rayTraceKernel(int totalTriangles, float distance, Triangle targetTriangle, Vec3* vertices, uint32_t* indices, Vec3* camera, float* output, char* occluded)
{
    int triangle = blockIdx.x * blockDim.x + threadIdx.x; //This thread's pixel index

    //Set up return flag for threads beyond the total number of pixels
    if (triangle >= totalTriangles)
    {
        return;
    }

    Triangle thisThread;
    thisThread.v0 = vertices[indices[triangle * 3]];
    thisThread.v1 = vertices[indices[triangle * 3 + 1]];
    thisThread.v2 = vertices[indices[triangle * 3 + 2]];
    
    Vec3 direction = vecSubtract(vecMultiply(vecAdd(targetTriangle.v0, vecAdd(targetTriangle.v1, targetTriangle.v2)), 1.0f / 3.0f), *camera); //Calculate the direction of a ray through the pixel

    direction = vecNormalize(direction); //Normalize the direction vector

    float hit = rayTriangleIntersect(camera, direction, thisThread); //Check if the ray intersects the triangle

    if (hit > 0.0f && hit < distance-d_epsilon) {
        output[triangle] = hit;
        *occluded = 1;
    } else {
        output[triangle] = 0;
    }
}
/***** End of device code *****/

int main(int argc, char** argv)
{
	/***** Read inputs and calculate number of threads and blocks *****/
    int blockSize = 256;
	if (argc >= 2) {
		blockSize = atoi(argv[1]);
	}

    std::string inputFile = "input/cube.obj";
    if (argc >= 3) {
		inputFile = argv[2];
	}

    MeshData mesh;
    if (!loadModel(inputFile, mesh)) {
        std::cerr << "Failed to load model" << std::endl;
        return 1;
    }

	int totalTriangles = mesh.numTriangles();

	int blocks = (totalTriangles + blockSize -1) / blockSize;
	/**********/

    /***** Generate camera positions and setup target *****/
	std::vector<Vec3> cameras = generateSphereArcPoints(5.0, 0.0, 360.0, 40.0, 120.0, 30);
    if (cameras.size() == 0)
	{
		return 0;
	}

    const int numCameras = (int)cameras.size();
    const int targetTri  = 0;

    std::cout << "Triangle " << targetTri << ": ("
                << mesh.vertices[mesh.indices[targetTri * 3]].x << ", "
                << mesh.vertices[mesh.indices[targetTri * 3]].y << ", "
                << mesh.vertices[mesh.indices[targetTri * 3]].z << "), ("
                << mesh.vertices[mesh.indices[targetTri * 3 + 1]].x << ", "
                << mesh.vertices[mesh.indices[targetTri * 3 + 1]].y << ", "
                << mesh.vertices[mesh.indices[targetTri * 3 + 1]].z << "), ("
                << mesh.vertices[mesh.indices[targetTri * 3 + 2]].x << ", "
                << mesh.vertices[mesh.indices[targetTri * 3 + 2]].y << ", "
                << mesh.vertices[mesh.indices[targetTri * 3 + 2]].z << ")\n";

    /**********/

    /***** Set up renderer. Code adapted from lab code used in EN 605.767 - Applied computer graphics ******/
    // Initialize SDL
    if(!SDL_Init(SDL_INIT_VIDEO))
    {
        std::cout << "Error initializing SDL: " << SDL_GetError() << '\n';
        exit(1);
    }

    // Initialize display mode and window
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    SDL_PropertiesID props = SDL_CreateProperties();
    if(props == 0)
    {
        std::cout << "Error creating SDL Window Properties: " << SDL_GetError() << '\n';
        exit(1);
    }

    SDL_SetStringProperty(
        props, SDL_PROP_WINDOW_CREATE_TITLE_STRING, "Visibility Detection");
    SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_RESIZABLE_BOOLEAN, true);
    SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_OPENGL_BOOLEAN, true);
    SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, 800);
    SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, 600);
    SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_X_NUMBER, 100);
    SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_Y_NUMBER, 100);

    SDL_Window *g_sdl_window = SDL_CreateWindowWithProperties(props);
    if(g_sdl_window == nullptr)
    {
        std::cout << "Error initializing SDL Window" << SDL_GetError() << '\n';
        exit(1);
    }

    // Initialize OpenGL
    SDL_GLContext g_gl_context = SDL_GL_CreateContext(g_sdl_window);

    std::cout << "OpenGL  " << glGetString(GL_VERSION) << ", GLSL "
            << glGetString(GL_SHADING_LANGUAGE_VERSION) << '\n';

    int32_t glew_init_result = glewInit();
    if(GLEW_OK != glew_init_result)
    {
        std::cout << "GLEW Error: " << glewGetErrorString(glew_init_result) << '\n';
        exit(EXIT_FAILURE);
    }

    // Set the clear color to black. Any part of the window outside the
    // viewport should appear black
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);

    // Enable multi-sample anti-aliasing
    glEnable(GL_MULTISAMPLE);

    // Enable depth testing
    glEnable(GL_DEPTH_TEST);

    // Enable back face polygon removal
    glFrontFace(GL_CCW);
    glCullFace(GL_BACK);
    glEnable(GL_CULL_FACE);
    /***** End of renderer setup *****/

    /***** Set up shaders, model buffers, and shared buffers ******/
    GLuint meshShader = createShaderProgram(meshVS, meshFS);
    GLuint lineShader = createShaderProgram(lineVS, lineFS);

    // Generate vertex buffers for the vertex list and the face list
    GLuint vbo_, facebuffer_, vao_;
    glGenBuffers(1, &vbo_);
    glGenBuffers(1, &facebuffer_);

    // Bind the vertex list to the vertex buffer object
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferData(GL_ARRAY_BUFFER, mesh.vertices.size() * sizeof(Vec3), mesh.vertices.data(), GL_STATIC_DRAW);

    // Bind the face list to the vertex buffer object
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, facebuffer_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, mesh.indices.size() * sizeof(uint32_t), mesh.indices.data(), GL_STATIC_DRAW);

    // Allocate a VAO, enable it and set the vertex attribute arrays and pointers
    glGenVertexArrays(1, &vao_);
    glBindVertexArray(vao_);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vec3), 0); 
    glEnableVertexAttribArray(0);

    // Bind the face list buffer and draw. Note the use of 0 offset in glDrawElements
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, facebuffer_);

    cudaGraphicsResource* vboRes;
    cudaGraphicsResource* eboRes;
    cudaGraphicsGLRegisterBuffer(&vboRes, vbo_,        cudaGraphicsRegisterFlagsReadOnly);
    cudaGraphicsGLRegisterBuffer(&eboRes, facebuffer_, cudaGraphicsRegisterFlagsReadOnly);
    cudaGraphicsMapResources(1, &vboRes, 0);
    cudaGraphicsMapResources(1, &eboRes, 0);

    Vec3*     d_verts;   size_t vBytes;
    uint32_t* d_indices; size_t iBytes;
    cudaGraphicsResourceGetMappedPointer((void**)&d_verts,   &vBytes, vboRes);
    cudaGraphicsResourceGetMappedPointer((void**)&d_indices, &iBytes, eboRes);

    std::vector<float> zeros(totalTriangles, 0.f);
    GLuint visSSBO = 0;
    cudaGraphicsResource* visRes = nullptr;
    glGenBuffers(1, &visSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, visSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, totalTriangles * sizeof(float), zeros.data(), GL_DYNAMIC_DRAW);
    cudaGraphicsGLRegisterBuffer(&visRes, visSSBO, cudaGraphicsRegisterFlagsNone);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, visSSBO);

    GLuint rayVAO, rayVBO; 
    cudaGraphicsResource* rayRes = nullptr;
    glGenVertexArrays(1, &rayVAO); 
    glBindVertexArray(rayVAO);
    glGenBuffers(1, &rayVBO);
    glBindBuffer(GL_ARRAY_BUFFER, rayVBO);
    glBufferData(GL_ARRAY_BUFFER, 2 * numCameras * sizeof(Vec3), nullptr, GL_DYNAMIC_DRAW);
    cudaGraphicsGLRegisterBuffer(&rayRes, rayVBO, cudaGraphicsRegisterFlagsWriteDiscard);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vec3), 0); 
    glEnableVertexAttribArray(0);
    /***** End of buffer setup *****/

	/***** Allocate device and host memory for later calculations *****/
    cudaStream_t* streams;
	cudaMallocHost((void**)&streams, cameras.size() * sizeof(cudaStream_t));

	float** outputs;
	cudaMallocHost((void**)&outputs, cameras.size() * sizeof(float*));

    int* occluded;
    cudaMallocHost(&occluded, numCameras * sizeof(int));

	Vec3** d_cameras;
	cudaMallocHost((void**)&d_cameras, cameras.size() * sizeof(Vec3*));

	float** d_outputs;
	cudaMallocHost((void**)&d_outputs, cameras.size() * sizeof(float*));

    char* d_occluded;
    cudaMalloc(&d_occluded, numCameras * sizeof(char));

	for (int i = 0; i < cameras.size(); i++) {
		cudaStreamCreate(&streams[i]);
		cudaMalloc((void**)&d_cameras[i], sizeof(Vec3));
		cudaMalloc((void**)&d_outputs[i], totalTriangles * sizeof(float));
		cudaMallocHost((void**)&outputs[i], totalTriangles * sizeof(float));
	}

	//Epsilon for ray-triangle intersection to account for floating point rounding errors
	float epsilon = 1.0e-5; 
	cudaMemcpyToSymbol(d_epsilon, &epsilon, sizeof(float), 0, cudaMemcpyHostToDevice);
    /**********/

    /***** Run kernel and record time *****/
	cudaEvent_t kernel_start1, kernel_stop1;

    float delta_time = 0.0f;
	cudaEventCreate(&kernel_start1);
	cudaEventCreateWithFlags(&kernel_stop1, cudaEventBlockingSync);

	cudaEventRecord(kernel_start1,0);

    Triangle targetTriangle;
    targetTriangle.v0 = mesh.vertices[mesh.indices[targetTri]];
    targetTriangle.v1 = mesh.vertices[mesh.indices[targetTri+1]];
    targetTriangle.v2 = mesh.vertices[mesh.indices[targetTri+2]];
    Vec3 targetCenter = vecMultiply(vecAdd(targetTriangle.v0, vecAdd(targetTriangle.v1, targetTriangle.v2)), 1.0f / 3.0f);
    std::cout << "Target Center: (" << targetCenter.x << ", " << targetCenter.y << ", " << targetCenter.z << ")" << std::endl;
        
	//Run ray trace kernel concurrently using CUDA streams
	for(int i = 0; i < cameras.size(); i++) {
        float distance = vecLength(vecSubtract(cameras[i], targetCenter));

		cudaMemcpyAsync(d_cameras[i], &cameras[i], sizeof(Vec3), cudaMemcpyHostToDevice, streams[i]);

		rayTraceKernel<<<blocks, blockSize, 0, streams[i]>>>(totalTriangles, distance, targetTriangle, d_verts, d_indices, d_cameras[i], d_outputs[i], &d_occluded[i]);

		cudaMemcpyAsync(outputs[i], d_outputs[i], totalTriangles * sizeof(float), cudaMemcpyDeviceToHost, streams[i]);
        cudaMemcpyAsync(&occluded[i], &d_occluded[i], sizeof(char), cudaMemcpyDeviceToHost, streams[i]);
	}

	cudaEventRecord(kernel_stop1,0);
	cudaEventSynchronize(kernel_stop1);
	cudaEventElapsedTime(&delta_time, kernel_start1, kernel_stop1);

	cudaDeviceSynchronize();

	printf("Stream Ray trace kernel took: %.5fms\n ", delta_time);
    /***** *****/
    
    // Clean up device memory
    cudaGraphicsUnmapResources(1, &vboRes, 0);
    cudaGraphicsUnmapResources(1, &eboRes, 0);

    /***** Read back results from device *****/ 
    std::vector<Vec3> rayVerts(2 * numCameras);
    for (int i = 0; i < numCameras; i++) { rayVerts[2*i] = cameras[i]; rayVerts[2*i + 1] = targetCenter; }

    cudaGraphicsMapResources(1, &rayRes, 0);
    void* dRays; size_t b;
    cudaGraphicsResourceGetMappedPointer(&dRays, &b, rayRes);
    cudaMemcpy(dRays, rayVerts.data(), rayVerts.size() * sizeof(Vec3), cudaMemcpyHostToDevice);
    cudaGraphicsUnmapResources(1, &rayRes, 0);
    
    std::vector<char> visible(numCameras, 1);
    for (int i = 0; i < numCameras; i++) visible[i] = (occluded[i] == 0);
    /***** *****/

    /***** Render loop *****/
    int  selectedRay = 0;
    bool rerender = true, running = true, dragging = false;

    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            switch (e.type) {
            case SDL_EVENT_QUIT: running = false; break;
            case SDL_EVENT_KEY_DOWN:
                if (e.key.key == SDLK_ESCAPE) running = false;
                if (e.key.key == SDLK_RIGHT) { selectedRay = (selectedRay + 1) % numCameras; rerender = true; }
                if (e.key.key == SDLK_LEFT)  { selectedRay = (selectedRay - 1 + numCameras) % numCameras; rerender = true; }
                break;
            case SDL_EVENT_MOUSE_BUTTON_DOWN: if (e.button.button == SDL_BUTTON_LEFT) dragging = true;  break;
            case SDL_EVENT_MOUSE_BUTTON_UP:   if (e.button.button == SDL_BUTTON_LEFT) dragging = false; break;
            case SDL_EVENT_MOUSE_MOTION:
                if (dragging) {
                    cam.yaw  -= e.motion.xrel * 0.01f;
                    cam.pitch = glm::clamp(cam.pitch + e.motion.yrel * 0.01f, -1.5f, 1.5f);
                }
                break;
            case SDL_EVENT_MOUSE_WHEEL: cam.dist *= (e.wheel.y > 0 ? 0.9f : 1.1f); break;
            }
        }

        /***** CUDA phase: copy the selected camera's results into the shared SSBO *****/
        if (rerender) {
            cudaGraphicsMapResources(1, &visRes, 0);
            void* dOcc; size_t b;
            cudaGraphicsResourceGetMappedPointer(&dOcc, &b, visRes);

            cudaMemcpy(dOcc, d_outputs[selectedRay], totalTriangles * sizeof(float), cudaMemcpyDeviceToDevice);
            cudaGraphicsUnmapResources(1, &visRes, 0);

            char title[128];
            snprintf(title, sizeof(title), "Camera %d/%d - target %s",
                    selectedRay, numCameras - 1, visible[selectedRay] ? "VISIBLE" : "OCCLUDED");
            SDL_SetWindowTitle(g_sdl_window, title);
            rerender = false;
        }
        /***** *****/

        /***** GL phase *****/
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glm::vec3 eye = cam.target + cam.dist * glm::vec3(cosf(cam.pitch)*sinf(cam.yaw), sinf(cam.pitch), cosf(cam.pitch)*cosf(cam.yaw));
        glm::mat4 mvp = glm::perspective(glm::radians(50.f), (float)800/(float)(600), 0.01f, 1000.f)
                    * glm::lookAt(eye, cam.target, glm::vec3(0,1,0));

        glUseProgram(meshShader);
        glUniformMatrix4fv(glGetUniformLocation(meshShader, "uMVP"), 1, GL_FALSE, glm::value_ptr(mvp));
        glUniform1i(glGetUniformLocation(meshShader, "uTargetTri"), targetTri);
        glBindVertexArray(vao_);
        glDrawElements(GL_TRIANGLES, (GLsizei)mesh.indices.size(), GL_UNSIGNED_INT, 0);

        glUseProgram(lineShader);
        glUniformMatrix4fv(glGetUniformLocation(lineShader, "uMVP"), 1, GL_FALSE, glm::value_ptr(mvp));
        glBindVertexArray(rayVAO);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND); 
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        GLint colorLoc = glGetUniformLocation(lineShader, "uColor");
        glUniform4f(colorLoc, 1.f, 0.9f, 0.2f, 0.12f);             
        glDrawArrays(GL_LINES, 0, 2 * numCameras);
        if (visible[selectedRay]) glUniform4f(colorLoc, 0.2f, 1.f, 0.3f, 1.f);   // selected ray: green if clear
        else              glUniform4f(colorLoc, 1.f, 0.2f, 0.2f, 1.f);   // red if blocked
        glDrawArrays(GL_LINES, 2 * selectedRay, 2);
        glDisable(GL_BLEND);
        glEnable(GL_DEPTH_TEST);

        SDL_GL_SwapWindow(g_sdl_window);
        /***** *****/
    }
    /***** *****/

	/***** Free device and host memory *****/
	for (int i = 0; i < cameras.size(); i++) {
		cudaStreamDestroy(streams[i]);
		cudaFree(d_cameras[i]);
		cudaFree(d_outputs[i]);
		cudaFreeHost(outputs[i]);
	}

	cudaFreeHost(d_cameras);
	cudaFreeHost(d_outputs);
	cudaFreeHost(streams);
    cudaFreeHost(outputs);

    cudaGraphicsUnregisterResource(vboRes);
    cudaGraphicsUnregisterResource(eboRes);
    glDeleteBuffers(1, &vbo_);
    glDeleteBuffers(1, &facebuffer_);
    glDeleteVertexArrays(1, &vao_);

    cudaGraphicsUnregisterResource(visRes); 
    glDeleteBuffers(1, &visSSBO);
    
    cudaGraphicsUnregisterResource(rayRes); 
    glDeleteBuffers(1, &rayVBO);
    glDeleteBuffers(1, &rayVAO);

    glDeleteProgram(meshShader);
    glDeleteProgram(lineShader);

    SDL_GL_DestroyContext(g_gl_context);
    SDL_DestroyWindow(g_sdl_window);
    SDL_Quit();
	/**********/

    return 0;
}