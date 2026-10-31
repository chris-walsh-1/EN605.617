//Based on the work of Andrew Krepps
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <curand.h>
#include <curand_kernel.h>

#include <thrust/execution_policy.h>
#include <thrust/reduce.h>
#include <thrust/functional.h>
#include <thrust/sort.h>
#include <thrust/count.h>

/***** Set up constant parameters. *****/
//Number of assets, number of days, starting portfolio value
//asset weights, mean daily returns, and volatilities of daily returns
__constant__ const int NUM_ASSETS = 3;
__constant__ const int NUM_DAYS = 252;
const float PORTFOLIO_VALUE = 10000.0f;
__constant__ float PORTFOLIO_VALUE_GPU;

__constant__ float weights[NUM_ASSETS] = {
    0.50f, 0.30f, 0.20f
};

__constant__ float means[NUM_ASSETS] = {
    0.0004f, 0.0003f, 0.0002f
};

__constant__ float volatilities[NUM_ASSETS] = {
    0.015f, 0.010f, 0.020f
};
/**********/

/***** Set up GPU kernels *****/
/* this GPU kernel function is used to initialize the random states */
__global__ void init(unsigned int seed, curandState_t* states, int numStates) {

    const unsigned int thread_idx = (blockIdx.x * blockDim.x) + threadIdx.x;

	if (thread_idx >= numStates) {
        return;
    }

  /* we have to initialize the state */
  	curand_init(seed, /* the seed can be the same for each core, here we pass the time in from the CPU */
		thread_idx, /* the sequence number should be different for each core (unless you want all
						cores to get the same sequence of numbers for some reason - use thread id! */
		0, /* the offset is how much extra we advance in the sequence for each call, can be 0 */
		&states[thread_idx]);
}

/* this GPU kernel function is used to calculate the portfolio returns for each scenario */
__global__ void calculatePortfolioReturns(curandState_t* states, float* portfolioReturns, int numScenarios) {
  	const unsigned int thread_idx = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (thread_idx >= numScenarios) {
        return;
    }

	//Set up initial asset values based on weights and portfolio value
	float assetValues[NUM_ASSETS];
    for (int i = 0; i < NUM_ASSETS; ++i) {
        assetValues[i] = weights[i] * PORTFOLIO_VALUE_GPU;
    }
	
	//Simulate daily returns for each asset over the number of days specified
	for (int day = 0; day < NUM_DAYS; ++day) {
		for (int i = 0; i < NUM_ASSETS; ++i) {
			float assetReturn = means[i] + volatilities[i] * curand_normal(&states[thread_idx]);
			
			assetValues[i] *= (1.0f + assetReturn);
		}
	}

	//Calculate the final portfolio value after all days have been simulated
	float portfolioValue = 0.0f;
	for (int i = 0; i < NUM_ASSETS; ++i) {
        portfolioValue += assetValues[i];
    }

    portfolioReturns[thread_idx] = portfolioValue;
}
/**********/

/***** Functors for Thrust algorithms *****/
struct if_counter {
	__device__ bool operator()(float x) { 
		return x < PORTFOLIO_VALUE_GPU; 
	}
};

struct variance_reducer {
	float mean;

	__device__ float operator()(float x) {
		float diff = x - mean;
		return diff * diff;
	}
};
/**********/

/***** Initialize cuRAND states for portfolio return simulation *****/
curandState_t* prepareCurandStates(int totalThreads, int numBlocks, int blockSize) {
	curandState_t* states;
	
	/* allocate space on the GPU for the random states */
	cudaMalloc((void**) &states, totalThreads * sizeof(curandState_t));

	/* invoke the GPU to initialize all of the random states */
	init<<<numBlocks, blockSize>>>(time(0), states, totalThreads);
	
	return states;
}

/***** Calculate portfolio returns using the prepared cuRAND states. One random scenario per thread *****/
float* calculatePortfolioReturns(curandState_t* states,int totalThreads, int numBlocks, int blockSize) {
	float* gpu_returns;
	
	cudaMalloc((void**) &gpu_returns, totalThreads * sizeof(float));
	
	calculatePortfolioReturns<<<numBlocks, blockSize>>>(states, gpu_returns, totalThreads);

	return gpu_returns;
}

/***** Calculate portfolio statistics from the simulated portfolio returns *****/
void calculatePortfolioStatistics(float* gpu_returns, int totalThreads) {
	//Calculate the sum of all portfolio returns and calculate mean
	float sum = thrust::reduce(
		thrust::device,
		gpu_returns,
		gpu_returns + totalThreads,
		0.0f,
		cuda::std::plus<float>() //NOTE: Use cuda::std::plus not thrust::plus because it is deprecated
	); 
	float gpuMean = sum / totalThreads;
	printf("Mean Portfolio Value: $%.2f\n", gpuMean);

	//Sort portfolio returns to calculate more statistics
	thrust::sort(
		thrust::device,
		gpu_returns,
		gpu_returns + totalThreads
	);

	//Select median value from sorted array (middle element)
	int medianIndex = totalThreads / 2;
	float median = 0.0f;
	cudaMemcpy(&median, gpu_returns + medianIndex, sizeof(float), cudaMemcpyDeviceToHost);
	printf("Median Portfolio Value: $%.2f\n", median);

	//Calculate standard deviation of portfolio returns
	float variance = thrust::transform_reduce(
		thrust::device,
		gpu_returns,
		gpu_returns + totalThreads,
		variance_reducer{gpuMean},
		0.0f,
		cuda::std::plus<float>() //NOTE: Use cuda::std::plus not thrust::plus because it is deprecated
	) / totalThreads;
	float stddev = sqrtf(variance);
	printf("Portfolio Standard Deviation: $%.2f\n", stddev);

	//Calculate Value at Risk (VaR) at the 95th percentile
	//The 95th percentile corresponds to the 5th element from the bottom in the sorted array
	//VaR represents the maximum loss that is not exceeded with a certain probability (95% in this case)
	float var95;
	cudaMemcpy(&var95, gpu_returns + (size_t)(0.05 * totalThreads), sizeof(float), cudaMemcpyDeviceToHost);
	var95 = PORTFOLIO_VALUE - var95;
	printf("Value at Risk (VaR) 95th Percentile Value: $%.2f\n", var95);

	//Count the number of losses (returns below the initial portfolio value)
	int losses = thrust::count_if(
		thrust::device,
		gpu_returns,
		gpu_returns + totalThreads,
		if_counter()
	);
	float probabilityOfLoss = (float)losses / totalThreads * 100.0f;
	printf("Probability of Loss: %.2f\n", probabilityOfLoss);
}

int main(int argc, char** argv)
{
	// read command line arguments
	int totalThreads = (1 << 20); //Threads represent number of simulated scenarios
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

	//Ensure both GPU and CPU have access to PORTFOLIO_VALUE contstant
	cudaMemcpyToSymbol(PORTFOLIO_VALUE_GPU, &PORTFOLIO_VALUE, sizeof(float));

	/* CUDA's random number library uses curandState_t to keep track of the seed value
     we will store a random state for every thread  */
	curandState_t* states = prepareCurandStates(totalThreads, numBlocks, blockSize);
	
	//Prepare and run parallel portfolio returns calculation scenarios
	float* gpu_returns = calculatePortfolioReturns(states, totalThreads, numBlocks, blockSize);

	//Calculate and print statistics
	calculatePortfolioStatistics(gpu_returns, totalThreads);
	
	/* free the memory we allocated for the states and numbers */
	cudaFree(states);
	cudaFree(gpu_returns);
}