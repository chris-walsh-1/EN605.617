# Module 6 Project: Streams and Events
---
**Author**: Chris Walsh

**Course**: EN.605.617

**Date**: October 11, 2026

---

### Project Description

This project implements `events` and `streams` to further parallelize a ray tracing/triangle intersection test from multiple camera positions at once. Building on code implemented in module 5, this project creates a number of cameras and creates a stream for each one. It then allocates memory for each stream and runs asynchronous memory copy and kernel execution code to allow multiple camera's streams to be processed at once. By keeping the GPU busy and parallelizing memory copy operations, the multi-stream implementation produces a significant speedup, sometime up to 2x, as shown in the timing comparison between synchronous camera calculations using the default stream and asynchronous camera calculations using user-defined streams. Events are used to show timing of stream operations.

### Building and running

The assignment is configured to work with both `make` and with `build.sh` and `run.sh` run via `run_assignments.sh` from this project's root.

* Option 1: make script:
    * run the command `make` from the `module6` folder
    * run the command ./assignment.exe to run the app
    * optional command line arguments are `blockSize`, `screenWidth`, and `screenHeight` (e.g. `./assignment.exe 256 512 512`)
* Option 2: `run_assignments.sh`
    * run `./run_assignments.sh` from the root of the project
