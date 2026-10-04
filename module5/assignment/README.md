# Module 5 Project: CUDA Memory
---
**Author**: Chris Walsh

**Course**: EN.605.617

**Date**: October 04, 2026

---

### Project Description

This project implements each type of memory `global`, `register`, `const`, and `shared`. It parallelizes the detection of a ray starting from a camera position, propagating through a pixel, and checking whether each ray intersects the triangle. This project uses a custom implementation of a vector struct to perform 3D math with functions implemented with the assistance of Chat GPT. It also uses a ray/triangle intersect function adapted from code implemented in a previous course EN605.767 Applied Computer Graphics.

Types of memory used:

* `host/global` - array of integers representing pixels, storing 0 on ray miss and 1 on ray hit
* `register` - each thread stores variables used to calculate the ray/triangle intersection
* `constant` - values like camera position and pixel sizes are shared between all threads
* `shared` - the triangle vertices are copied to shared memory for each block so all threads can quickly access vertex data 

The ray/triangle intersect kernel is planned to be reused in the final project 

### Building and running

The assignment is configured to work with both `make` and with `build.sh` and `run.sh` run via `run_assignments.sh` from this project's root.

* Option 1: make script:
    * run the command `make` from the `module5/assignment` folder
    * run the command ./assignment.exe to run the app
    * optional command line arguments are `blockSize`, `screenWidth`, and `screenHeight` (e.g. `./assignment.exe 256 512 512`)
* Option 2: `run_assignments.sh`
    * run `./run_assignments.sh` from the root of the project
