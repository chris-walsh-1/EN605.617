//Based on the work of Andrew Krepps
#include <stdio.h>
#include <stdlib.h>
#include <random>
#include <iostream>
#include <chrono>
#include <thread>
#include <cassert>

__global__ void toGrayscaleGPU(int *r, int *g, int *b, int *gr) {
	const unsigned int thread_idx = (blockIdx.x * blockDim.x) + threadIdx.x;
	gr[thread_idx] = (r[thread_idx]+g[thread_idx]+b[thread_idx])/3.0f;
}

__global__ void blackWhiteMapGPU(int *r, int *g, int *b, int *gr, int threshold) {
	const unsigned int thread_idx = (blockIdx.x * blockDim.x) + threadIdx.x;
	int color = (r[thread_idx]+g[thread_idx]+b[thread_idx])/3.0f;

	if(color > threshold) {
		gr[thread_idx] = 255;
	} else {
		gr[thread_idx] = 0;
	}
}

void toGrayscaleCPU(int *r, int *g, int *b, int *gr, int start_thread_idx, int end_thread_idx) {
	for(int thread_idx = start_thread_idx; thread_idx <= end_thread_idx; ++thread_idx)
    {
		gr[thread_idx] = (r[thread_idx]+g[thread_idx]+b[thread_idx])/3.0f;
	}
}

void blackWhiteMapCPU(int *r, int *g, int *b, int *gr, int start_thread_idx, int end_thread_idx, int threshold) {
	for(int thread_idx = start_thread_idx; thread_idx <= end_thread_idx; ++thread_idx)
    {
		int color = (r[thread_idx]+g[thread_idx]+b[thread_idx])/3.0f;

		if(color > threshold) {
			gr[thread_idx] = 255;
		} else {
			gr[thread_idx] = 0;
		}
	}
}

int main(int argc, char** argv)
{
	/****** PART 1: Read command line and execution configuration *****/
	// read command line arguments
	int totalThreads = (1 << 26);
	int blockSize = 256;
	
	if (argc >= 2) {
		totalThreads = atoi(argv[1]);
	}
	if (argc >= 3) {
		blockSize = atoi(argv[2]);
	}

	int numBlocks = totalThreads/blockSize;

	// validate command line arguments
	if (totalThreads % blockSize != 0) {
		++numBlocks;
		totalThreads = numBlocks*blockSize;
		
		printf("Warning: Total thread count is not evenly divisible by the block size\n");
		printf("The total number of threads will be rounded up to %d\n", totalThreads);
	}
	/***** END PART 1 *****/

	/***** Part 2: Array generation and GPU Memory setup *****/
	int *r = (int *)malloc(totalThreads * sizeof(int)); //pixel "red" value
	int *g = (int *)malloc(totalThreads * sizeof(int)); //pixel "green" value
	int *b = (int *)malloc(totalThreads * sizeof(int)); //pixel "blue" value
	int *gr_gpu = (int *)malloc(totalThreads * sizeof(int)); //result grayscale value from GPU
	int *gr_cpu = (int *)malloc(totalThreads * sizeof(int)); //result grayscale value from CPU
	int *bw_gpu = (int *)malloc(totalThreads * sizeof(int)); //result black-white mapping from GPU
	int *bw_cpu = (int *)malloc(totalThreads * sizeof(int)); //result black-white mapping from CPU
	int *dev_r, *dev_g, *dev_b, *dev_gr, *dev_bw; //device-side variables for data above

	cudaMalloc((void**)&dev_r, totalThreads * sizeof(int));
	cudaMalloc((void**)&dev_g, totalThreads * sizeof(int));
	cudaMalloc((void**)&dev_b, totalThreads * sizeof(int));
	cudaMalloc((void**)&dev_gr, totalThreads * sizeof(int));
	cudaMalloc((void**)&dev_bw, totalThreads * sizeof(int));

	//Random number generator code obtained from google search: "c++ random integer between 0 and 255"
	std::random_device rd; // Non-deterministic seed
	std::mt19937 gen(rd()); // Mersenne Twister engine
	std::uniform_int_distribution<int> dist(0, 255);

	for (int i = 0; i < totalThreads; i++) {
		r[i] = dist(gen);
		g[i] = dist(gen);
		b[i] = dist(gen);
	}

	auto startTransferToGPU = std::chrono::high_resolution_clock::now();
	cudaMemcpy(dev_r, r, totalThreads * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_g, g, totalThreads * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(dev_b, b, totalThreads * sizeof(int), cudaMemcpyHostToDevice);
	auto stopTransferToGPU = std::chrono::high_resolution_clock::now();
	/***** END PART 2 *****/

	/***** PART 3: COLOR TO GRAYSCALE GPU AND CPU *****/
	auto startGPU = std::chrono::high_resolution_clock::now();
	toGrayscaleGPU<<<numBlocks,blockSize>>> (dev_r, dev_g, dev_b, dev_gr); //Run our color-to-grayscale conversion on GPU
	auto stopGPU = std::chrono::high_resolution_clock::now();

	auto startTransferFromGPU = std::chrono::high_resolution_clock::now();
	cudaMemcpy(gr_gpu, dev_gr, totalThreads*sizeof(int), cudaMemcpyDeviceToHost);
	auto stopTransferFromGPU = std::chrono::high_resolution_clock::now();

	//CPU concurrency via threads inspired by code from EN.605.767 - Applied Computer Graphics course source code
	//Credit for the following lines of code setting up threads goes to Professor Brian Russin
	int num_cpu_threads = std::thread::hardware_concurrency() - 1; //get number of threads available
    num_cpu_threads = num_cpu_threads > 0 ? num_cpu_threads : 1; //fallback
	std::thread *threads = new std::thread[num_cpu_threads];
	int      start_row = 0;

	auto startCPU = std::chrono::high_resolution_clock::now();
	for(int t_i = 0; t_i < num_cpu_threads; ++t_i)
	{
		int end_row = std::min((t_i + 1) * totalThreads / num_cpu_threads, totalThreads - 1);
		threads[t_i] = std::thread(toGrayscaleCPU, &r[0], &g[0], &b[0], &gr_cpu[0], start_row, end_row); //spin up a thread to calculate color-to-grayscale conversion on a portion of our pixel array on CPU
		start_row = end_row + 1;
	}
	for(int32_t t_i = 0; t_i < num_cpu_threads; ++t_i) { threads[t_i].join(); } // Wait for CPU threads to complete
	auto stopCPU = std::chrono::high_resolution_clock::now();

	for(int i = 0; i < totalThreads; i++) {
		assert(gr_gpu[i] == gr_cpu[i]); //Check that the results from GPU and CPU calculations are the same
	}
	/***** END PART 3 *****/

	/***** PART 4: BLACK/WHITE THRESHOLD MAPPING GPU AND CPU *****/
	int blackWhiteThreshold = 128;

	auto startGPU2 = std::chrono::high_resolution_clock::now();
	blackWhiteMapGPU<<<numBlocks,blockSize>>> (dev_r, dev_g, dev_b, dev_bw, blackWhiteThreshold); //run our color to black-white map on GPU
	auto stopGPU2 = std::chrono::high_resolution_clock::now();

	auto startTransferFromGPU2 = std::chrono::high_resolution_clock::now();
	cudaMemcpy(bw_gpu, dev_bw, totalThreads*sizeof(int), cudaMemcpyDeviceToHost);
	auto stopTransferFromGPU2 = std::chrono::high_resolution_clock::now();

	start_row = 0; //reset row counter

	auto startCPU2 = std::chrono::high_resolution_clock::now();
	for(int t_i = 0; t_i < num_cpu_threads; ++t_i)
	{
		int end_row = std::min((t_i + 1) * totalThreads / num_cpu_threads, totalThreads - 1);
		threads[t_i] = std::thread(blackWhiteMapCPU, &r[0], &g[0], &b[0], &bw_cpu[0], start_row, end_row, blackWhiteThreshold); //spin up a thread to calculate black-white mapping on a portion of our pixel array on CPU
		start_row = end_row + 1;
	}
	for(int32_t t_i = 0; t_i < num_cpu_threads; ++t_i) { threads[t_i].join(); } // Wait for CPU threads to complete
	auto stopCPU2 = std::chrono::high_resolution_clock::now();

	for(int i = 0; i < totalThreads; i++) {
		assert(bw_gpu[i] == bw_cpu[i]); //Check that the results from GPU and CPU calculations are the same
	}
	/***** END PART 4 *****/

	/***** PART 5: CLEANUP AND REPORT *****/
	cudaFree(dev_r);
	cudaFree(dev_g);
	cudaFree(dev_b);
	cudaFree(dev_gr);
	cudaFree(dev_bw);
	free(r);
	free(g);
	free(b);
	free(gr_gpu);
	free(gr_cpu);
	free(bw_gpu);
	free(bw_cpu);
	delete[] threads;

	std::chrono::duration<int64_t, std::nano>::rep transferToGPUTime = std::chrono::duration_cast<std::chrono::nanoseconds>(stopTransferToGPU - startTransferToGPU).count();
	std::chrono::duration<int64_t, std::nano>::rep transferFromGPUTime = std::chrono::duration_cast<std::chrono::nanoseconds>(stopTransferFromGPU - startTransferFromGPU).count();
	std::chrono::duration<int64_t, std::nano>::rep calculateGPUTime = std::chrono::duration_cast<std::chrono::nanoseconds>(stopGPU - startGPU).count();

	std::chrono::duration<int64_t, std::nano>::rep transferFromGPUTime2 = std::chrono::duration_cast<std::chrono::nanoseconds>(stopTransferFromGPU2 - startTransferFromGPU2).count();
	std::chrono::duration<int64_t, std::nano>::rep calculateGPUTime2 = std::chrono::duration_cast<std::chrono::nanoseconds>(stopGPU2 - startGPU2).count();

	std::cout << std::endl << " Time elapsed GPU = " << transferToGPUTime + transferFromGPUTime + calculateGPUTime << "ns\n";
	std::cout << "     Transfer to GPU = " << transferToGPUTime << "ns\n";
	std::cout << "     Transfer from GPU = " << transferFromGPUTime << "ns\n";
	std::cout << "     Calculate time GPU = " << calculateGPUTime << "ns\n";
	std::cout << " Time elapsed CPU = " << std::chrono::duration_cast<std::chrono::nanoseconds>(stopCPU - startCPU).count() << "ns\n";

	std::cout << std::endl << " Time elapsed GPU = " << transferToGPUTime + transferFromGPUTime2 + calculateGPUTime2 << "ns\n";
	std::cout << "     Transfer to GPU = " << transferToGPUTime << "ns\n";
	std::cout << "     Transfer from GPU = " << transferFromGPUTime2 << "ns\n";
	std::cout << "     Calculate time GPU = " << calculateGPUTime2 << "ns\n";
	std::cout << " Time elapsed CPU = " << std::chrono::duration_cast<std::chrono::nanoseconds>(stopCPU2 - startCPU2).count() << "ns\n";
	/***** END PART 5 *****/

	return 0;
}
