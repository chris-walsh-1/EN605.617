# Final project: Surface visibility calculation
---
**Author**: Chris Walsh

**Course**: EN.605.617

**Date**: December 13, 2026

---

### Project Description

This application will serve as the final project for EN.605.617. The purpose of this program is to detect the visibility of a point of interest on the surface of a triangulated model. It uses CUDA to parallelize triangle collision detection to detect whether another triangle in the model occludes the target. The algorithm implemented in this project has practical utility in shadowing for antenna signal simulations.

A unique part of this projeect is the use of [CUDA interoperability with graphics libraries](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/graphics-interop.html). In order to minimize the amount of data that needs to get moved from the host to device, graphics buffers are mapped to CUDA resources so data can be used in kernels and in rendering. This removes the need to duplicate memory copying from host to device for both CUDA and Open GL.

By default a cube model is included as a default model to use in the application. This model only has 12 triangles and does not truly show the power of using CUDA to parallelize triangle intersection detection. You may load your own model by downloading one and using command line arguments to select it.

This project was tested in Windows 11 and Ubuntu 26.04.1.

### Required dependencies

This application requires a number of libraries to compile.

* `glm` - A math library featuring impementations of common 3D math functions
* `assimp` - Asset importer library for loading 3D models
* `SDL` - Open GL Context manager (among other things)
* `glew` - Open GL extension loader

**Windows Instructions**

```powershell
# download and initialize vcpkg
git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
cd C:\vcpkg
.\bootstrap-vcpkg.bat

# download project dependencies
vcpkg install glm:x64-windows sdl3:x64-windows assimp:x64-windows glew:x64-windows
```

**Linux Instructions**

```bash
# download project dependencies (note: needs to be Ubuntu 26.04 for sdl3)
sudo apt install -y libglm-dev libsdl3-dev libassimp-dev libglew-dev
```

### Building and running

The assignment is configured to work with both `make` and with `build.sh` and `run.sh` run via `run_assignments.sh` from this project's root.

* Option 1: make script:
    * run the command `make` from the `final_project` folder
    * run the command ./assignment.exe to run the app
    * optional command line arguments are `blockSize` and `input file`(e.g. `./assignment.exe 256 cube.obj`)
* Option 2: `run_assignments.sh`
    * run `./run_assignments.sh` from the root of the project. It is configured to run with default arguments.
