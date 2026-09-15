# Module 3 Project: CUDA Threads and Blocks Assignment
---
**Author**: Chris Walsh

**Course**: EN.605.617

**Date**: September 20, 2026

---

#### Project Description

The `assignment.cu` file implements two different algorithms on both the CPU and GPU. The first algorithm takes an array of RGB "pixel" values in a flat array and maps the color to a grayscale value between 0 and 255. The second maps a color calculated from RGB values of "pixels" to a black and white image based on some threshold value. All values above a certain number are set to white and below are set to black.

Output from the project is four total time calculations, 2 for each of the algorithms when run on the GPU or CPU. The GPU time calculation is broken up into pieces to take into account memory transfer time as well as GPU calculation time. CPU Time is presented alone as it does not need the same memory copy steps that GPU calculations do.

#### Building and running

The assignment is configured to work with both `make` and with `build.sh` and `run.sh` run via `run_assignments.sh` from this project's root.

* Option 1: make script:
    * run the command `make` from the `module3` folder
    * run the command ./assignment.exe to run the app
    * optional command line arguments are `totalThreads` and `blockSize` (e.g. `./assignment.exe 512 256`)
* Option 2: `run_assignments.sh`
    * run `./run_assignments.sh` from the root of the project

#### Project results

#### Previous solution Commentary