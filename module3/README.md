# Module 3 Project: CUDA Threads and Blocks Assignment
---
**Author**: Chris Walsh

**Course**: EN.605.617

**Date**: September 20, 2026

---

### Project Description

The `assignment.cu` file implements two different algorithms on both the CPU and GPU. The first algorithm takes an array of RGB "pixel" values in a flat array and maps the color to a grayscale value between 0 and 255. The second maps a color calculated from RGB values of "pixels" to a black and white image based on some threshold value. All values above a certain number are set to white and below are set to black.

Output from the project is four total time calculations, 2 for each of the algorithms when run on the GPU or CPU. The GPU time calculation is broken up into pieces to take into account memory transfer time as well as GPU calculation time. CPU Time is presented alone as it does not need the same memory copy steps that GPU calculations do.

### Building and running

The assignment is configured to work with both `make` and with `build.sh` and `run.sh` run via `run_assignments.sh` from this project's root.

* Option 1: make script:
    * run the command `make` from the `module3` folder
    * run the command ./assignment.exe to run the app
    * optional command line arguments are `totalThreads` and `blockSize` (e.g. `./assignment.exe 512 256`)
* Option 2: `run_assignments.sh`
    * run `./run_assignments.sh` from the root of the project

### Project results

**No Branching**
| Run | Total Threads | Block Size | GPU Total (ns) | Transfer In (ns) | Transfer Out (ns) | GPU Compute (ns) | CPU Total (ns) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 512 | 32 | 740,838 | 655,466 | 56,567 | 28,805 | 1,369,972 |
| 2 | 1,024 | 32 | 526,080 | 459,634 | 37,241 | 29,205 | 1,149,293 |
| 3 | 2,048 | 64 | 604,559 | 516,211 | 56,127 | 32,221 | 1,180,623 |
| 4 | 4,096 | 64 | 581,860 | 507,459 | 46,017 | 28,384 | 1,181,314 |
| 5 | 8,192 | 128 | 582,507 | 476,245 | 77,998 | 28,264 | 1,130,939 |
| 6 | 16,384 | 128 | 648,843 | 500,110 | 120,349 | 28,384 | 1,260,414 |
| 7 | 32,768 | 256 | 829,215 | 610,429 | 178,830 | 39,956 | 1,097,135 |
| 8 | 65,536 | 256 | 1,023,860 | 658,376 | 332,151 | 33,333 | 1,232,221 |
| 9 | 131,072 | 512 | 1,591,023 | 1,023,324 | 538,473 | 29,226 | 1,343,387 |
| 10 | 262,144 | 512 | 2,467,336 | 1,415,899 | 1,019,597 | 31,840 | 1,417,674 |


**Branching**
| Run | Total Threads | Block Size | GPU Total (ns) | Transfer In (ns) | Transfer Out (ns) | GPU Compute (ns) | CPU Total (ns) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 512 | 32 | 730,809 | 655,466 | 49,414 | 25,929 | 779,260 |
| 2 | 1,024 | 32 | 539,877 | 459,634 | 51,067 | 29,176 | 984,049 |
| 3 | 2,048 | 64 | 588,257 | 516,211 | 38,232 | 33,814 | 899,279 |
| 4 | 4,096 | 64 | 586,199 | 507,459 | 42,881 | 35,859 | 918,425 |
| 5 | 8,192 | 128 | 552,710 | 476,245 | 50,455 | 26,010 | 723,245 |
| 6 | 16,384 | 128 | 627,472 | 500,110 | 96,733 | 30,629 | 784,239 |
| 7 | 32,768 | 256 | 761,757 | 610,429 | 111,031 | 40,297 | 738,433 |
| 8 | 65,536 | 256 | 931,044 | 658,376 | 243,363 | 29,305 | 937,992 |
| 9 | 131,072 | 512 | 1,550,195 | 1,023,324 | 482,357 | 44,514 | 909,378 |
| 10 | 262,144 | 512 | 2,422,000 | 1,415,899 | 971,706 | 34,395 | 991,394 |


**Branching vs No Branching Comparison GPU**
| Total Threads | Block Size | No Branching (ns) | Branching (ns) | Difference (ns) |
|---:|---:|---:|---:|---:|
| 512 | 32 | 28,805 | 25,929 | -2,876 |
| 1,024 | 32 | 29,205 | 29,176 | -29 |
| 2,048 | 64 | 32,221 | 33,814 | +1,593 |
| 4,096 | 64 | 28,384 | 35,859 | +7,475 |
| 8,192 | 128 | 28,264 | 26,010 | -2,254 |
| 16,384 | 128 | 28,384 | 30,629 | +2,245 |
| 32,768 | 256 | 39,956 | 40,297 | +341 |
| 65,536 | 256 | 33,333 | 29,305 | -4,028 |
| 131,072 | 512 | 29,226 | 44,514 | +15,288 |
| 262,144 | 512 | 31,840 | 34,395 | +2,555 |


**CPU vs GPU No Branching**
| Total Threads | Block Size | GPU Total (ns) | CPU Total (ns) | CPU - GPU (ns) |
|---:|---:|---:|---:|---:|
| 512 | 32 | 740,838 | 1,369,972 | 629,134 |
| 1,024 | 32 | 526,080 | 1,149,293 | 623,213 |
| 2,048 | 64 | 604,559 | 1,180,623 | 576,064 |
| 4,096 | 64 | 581,860 | 1,181,314 | 599,454 |
| 8,192 | 128 | 582,507 | 1,130,939 | 548,432 |
| 16,384 | 128 | 648,843 | 1,260,414 | 611,571 |
| 32,768 | 256 | 829,215 | 1,097,135 | 267,920 |
| 65,536 | 256 | 1,023,860 | 1,232,221 | 208,361 |
| 131,072 | 512 | 1,591,023 | 1,343,387 | -247,636 |
| 262,144 | 512 | 2,467,336 | 1,417,674 | -1,049,662 |


**CPU vs GPU Branching**
| Total Threads | Block Size | GPU Total (ns) | CPU Total (ns) | CPU - GPU (ns) |
|---:|---:|---:|---:|---:|
| 512 | 32 | 730,809 | 779,260 | 48,451 |
| 1,024 | 32 | 539,877 | 984,049 | 444,172 |
| 2,048 | 64 | 588,257 | 899,279 | 311,022 |
| 4,096 | 64 | 586,199 | 918,425 | 332,226 |
| 8,192 | 128 | 552,710 | 723,245 | 170,535 |
| 16,384 | 128 | 627,472 | 784,239 | 156,767 |
| 32,768 | 256 | 761,757 | 738,433 | -23,324 |
| 65,536 | 256 | 931,044 | 937,992 | 6,948 |
| 131,072 | 512 | 1,550,195 | 909,378 | -640,817 |
| 262,144 | 512 | 2,422,000 | 991,394 | -1,430,606 |

**Results Commentary**

The dataset presented contains a number of results worth pointing out including an analysis of CPU and GPU *total* time, CPU *total* time and GPU *compute* time, and GPU *compute* time on a kernel that includes branching.

In both the no branching and branching kernels, the GPU compute time when considered in isolation is faster than the CPU compute on every run. This result is unsurprising. However, as the total number of threads increases, the amount of data needing to be transferred to GPU memory so with larger datasets the total GPU time is actually slower than the total CPU time when using these kernels. The problem becomes bounded by memory transfer time, not by compute time. This is a result I did not expect before this project, but the result is logical. A lesson here is to minimize data transfers between host and device, and do more with data when it is transferred.

The results for the no branching and branching kernels when executed on the GPU are mixed and do not exactly line up with my expectations. While it is true that generally the branching kernel takes longer than the no branching kernel, I think the randomness of the data and measurement noise contribute to a less uniform result. I believe the results still show the slowdown in execution expected with a branching kernel, but not to the extent I initially expected.

### Previous solution Commentary

The previous submission to this assignment has a couple of subtle issues in variable naming and misses an important piece of application timing.

The variables read in are named `blocks` and `threads` and are used when invoking the `add` kernel, but a more accurate name for each should be `blocks` and `blockSize` where the `blockSize` represents the number of threads per block. The input to this assignment could be misunderstood as the total number of threads to run, not the number per block. 

The larger issue in evaluating runtime is the lack of timing around the GPU transfer from the CPU. In my experience, this transfer time had a major impact on the overall execution time of the same application running on the GPU and CPU. With larger data input sizes, memory transfer time made the overall GPU operation longer than the CPU. I believe this is likely due to how simple the kernel is, and with more complex operations a GPU has the power to be much faster than a CPU. However, it is best to minimize data transfer if possible and do more with what data the GPU has, instead of constantly transferring data to and from GPU Memory.