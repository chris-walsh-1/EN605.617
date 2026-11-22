# Module 12 Project: OpenCL
---
**Author**: Chris Walsh

**Course**: EN.605.617

**Date**: November 22, 2026

---

### Project Description

This project is an OpenCL adaptation of a portion of my final project surface location visibility detection. In this project, each camera is represented as a sub buffer of a camera buffer and each camera's occlusion check is run on a fixed number of queues. A cube model is hard coded instead of model loading for simplicity. The output is a list of each camera position and whether or not the point of interest is occluded.  

### Building and running

The assignment is configured to work with both `make` and with `build.sh` and `run.sh` run via `run_assignments.sh` from this project's root.

* Option 1: make script:
    * run the command `make` from the `module12` folder
    * run the command ./assignment.exe to run the app
    * optional command line arguments are `number of points in azimuth and elevation` and `number of queues` (e.g. `./assignment.exe 10 10`)
* Option 2: `run_assignments.sh`
    * run `./run_assignments.sh` from the root of the project
