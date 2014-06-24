/*
 * Copyright 1993-2013 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

/* Template project which demonstrates the basics on how to setup a project
* example application, doesn't use cutil library.
*/

#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <igraph.h>
#include <iostream>

int numNodos = 0;
#define INT_MAX2 100

using namespace std;

#ifdef _WIN32
#define STRCASECMP  _stricmp
#define STRNCASECMP _strnicmp
#else
#define STRCASECMP  strcasecmp
#define STRNCASECMP strncasecmp
#endif

#define ASSERT(x, msg, retcode) \
    if (!(x)) \
    { \
        cout << msg << " " << __FILE__ << ":" << __LINE__ << endl; \
        return retcode; \
    }

__global__ void sequence_gpu(int *d_ptr, int length)
{
    int elemID = blockIdx.x * blockDim.x + threadIdx.x;

    if (elemID < length)
    {
        d_ptr[elemID] = elemID;
    }
}

__global__ void init_stp(int *d_stp, int numNodos)
{
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;


	if (i < numNodos) {
		if (j < numNodos) {
			d_stp[i+numNodos*j] = INT_MAX2;
		}
	}

}

__global__ void init_boolean_vector(bool *d_boolean_vector, int numNodos)
{
	int i = blockIdx.x * blockDim.x + threadIdx.x;

	if (i<numNodos){
		d_boolean_vector[i] = false;
	}

}

void sequence_cpu(int *h_ptr, int length)
{
    for (int elemID=0; elemID<length; elemID++)
    {
        h_ptr[elemID] = elemID;
    }
}

int print_boolean_vector(bool *vector){

	int i;
	for (i = 0; i < numNodos; ++i) {
			cout<<" "<<vector[i];
	}

	return EXIT_SUCCESS;
}

int printMatrix(int *matrix){

	int i,j;
	for (i = 0; i < numNodos; ++i) {
		for (j = 0; j < numNodos; ++j) {
			cout<<" "<<matrix[i+numNodos*j];
		}
		cout<<endl;
	}

	return EXIT_SUCCESS;
}

int stpPrim(int *grafo){
	int *h_stp;
	int *d_grafo, *d_stp;

	bool *h_boolean_vector, *d_boolean_vector;

	ASSERT(cudaSuccess == cudaMallocHost(&h_boolean_vector, numNodos * sizeof(bool)), "Host allocation of "   << numNodos << " booleans failed", -1);

	ASSERT(cudaSuccess == cudaMallocHost(&h_stp, numNodos*numNodos * sizeof(int)), "Host allocation of "   << numNodos*numNodos << " ints failed", -1);

	ASSERT(cudaSuccess == cudaMalloc(&d_grafo, numNodos*numNodos * sizeof(int)), "Device allocation of " << numNodos*numNodos << " ints failed", -1);

	ASSERT(cudaSuccess == cudaMalloc(&d_boolean_vector, numNodos * sizeof(bool)), "Device allocation of " << numNodos << " booleans failed", -1);

	ASSERT(cudaSuccess == cudaMalloc(&d_stp, numNodos*numNodos * sizeof(int)), "Device allocation of " << numNodos*numNodos << " ints failed", -1);

	ASSERT(cudaSuccess == cudaMemcpy(d_grafo, grafo, numNodos*numNodos*sizeof(int), cudaMemcpyHostToDevice), "Copy of " << numNodos*numNodos << " ints from host to device failed", -1);

	////////inicialización STP///////////////////////////////////////////////////////////////////
	dim3 cudaBlockSize(32,32,1);
	dim3 cudaGridSize((numNodos + cudaBlockSize.x - 1) / cudaBlockSize.x, (numNodos + cudaBlockSize.y - 1) / cudaBlockSize.y, 1);
	init_stp<<<cudaGridSize, cudaBlockSize>>>(d_stp, numNodos);
	ASSERT(cudaSuccess == cudaGetLastError(), "Kernel launch failed", -1);
	ASSERT(cudaSuccess == cudaDeviceSynchronize(), "Kernel synchronization failed", -1);
	ASSERT(cudaSuccess == cudaMemcpy(h_stp, d_stp, numNodos*numNodos *sizeof(int), cudaMemcpyDeviceToHost), "Copy of " << numNodos*numNodos << " ints from device to host failed", -1);
	//printMatrix(h_stp);
	//////////////////////////////////////////////////////////////////////////////////////////////////////


	////////inicialización BOOLEAN VECTOR///////////////////////////////////////////////////////////////////
	dim3 cudaBlockSize2(32,1,1);
	dim3 cudaGridSize2((numNodos + cudaBlockSize.x - 1) / cudaBlockSize.x, 1, 1);
	init_boolean_vector<<<cudaGridSize2, cudaBlockSize2>>>(d_boolean_vector, numNodos);
	ASSERT(cudaSuccess == cudaGetLastError(), "Kernel launch failed", -1);
	ASSERT(cudaSuccess == cudaDeviceSynchronize(), "Kernel synchronization failed", -1);
	ASSERT(cudaSuccess == cudaMemcpy(h_boolean_vector, d_boolean_vector, numNodos *sizeof(bool), cudaMemcpyDeviceToHost), "Copy of " << numNodos*numNodos << " ints from device to host failed", -1);
	print_boolean_vector(h_boolean_vector);
	//////////////////////////////////////////////////////////////////////////////////////////////////////

	ASSERT(cudaSuccess == cudaFreeHost(h_stp),   "Host deallocation failed",   -1);
	ASSERT(cudaSuccess == cudaFree(d_stp),   "Device stp deallocation failed",   -1);
	ASSERT(cudaSuccess == cudaFree(d_grafo),   "Device grafo deallocation failed",   -1);

	return EXIT_SUCCESS;
}

int* readGrafo(){

	int *grafo;
	igraph_matrix_t gMatrix;
	igraph_t g;
	igraph_i_set_attribute_table(&igraph_cattribute_table);
	FILE *ifile;
	ifile=fopen("/home/john/Documents/celegansneural.gml"/*"/home/john/git/primAlgorithm/grafo.gml"*/, "r");
	if (ifile==0) {
		printf("Problema abriendo archivo de grafo\n");
		return NULL;
	}
	igraph_read_graph_gml(&g, ifile);

	fclose(ifile);
	numNodos = igraph_vcount(&g);
	grafo = (int *)malloc(numNodos*numNodos*sizeof(int));
	igraph_matrix_init(&gMatrix,numNodos,numNodos);
	igraph_get_adjacency(&g,&gMatrix,IGRAPH_GET_ADJACENCY_BOTH,1);

	igraph_vector_t el;
	int ii, jj, n;
	igraph_vector_init(&el, 0);
	igraph_get_edgelist(&g, &el, 0);
	n = igraph_ecount(&g);

	memset(grafo,INT_MAX2,numNodos*numNodos*sizeof(int));

	  for (ii=0, jj=0; ii<n; ii++, jj+=2) {
	    grafo[((long)VECTOR(el)[jj])+numNodos*((long)VECTOR(el)[jj+1])] = (int)EAN(&g, "weight", ii);
	    grafo[((long)VECTOR(el)[jj+1])+numNodos*((long)VECTOR(el)[jj])] =  (int)EAN(&g, "weight", ii);
	  }

	printf("\nNumero de nodos %d\n",numNodos);

	igraph_vector_destroy(&el);
	igraph_destroy(&g);
	return grafo;

}


int main(int argc, char **argv)
{
    printf("%s Starting...\n\n", argv[0]);

    cout << "CUDA Runtime API template" << endl;
    cout << "=========================" << endl;
    cout << "Self-test started" << endl;

    const int N = 100;

    int *d_ptr;
    ASSERT(cudaSuccess == cudaMalloc(&d_ptr, N * sizeof(int)), "Device allocation of " << N << " ints failed", -1);

    int *h_ptr;
    ASSERT(cudaSuccess == cudaMallocHost(&h_ptr, N * sizeof(int)), "Host allocation of "   << N << " ints failed", -1);

    cout << "Memory allocated successfully" << endl;

    dim3 cudaBlockSize(32,1,1);
    dim3 cudaGridSize((N + cudaBlockSize.x - 1) / cudaBlockSize.x, 1, 1);
    sequence_gpu<<<cudaGridSize, cudaBlockSize>>>(d_ptr, N);
    ASSERT(cudaSuccess == cudaGetLastError(), "Kernel launch failed", -1);
    ASSERT(cudaSuccess == cudaDeviceSynchronize(), "Kernel synchronization failed", -1);

    sequence_cpu(h_ptr, N);

    cout << "CUDA and CPU algorithm implementations finished" << endl;

    int *h_d_ptr;
    ASSERT(cudaSuccess == cudaMallocHost(&h_d_ptr, N *sizeof(int)), "Host allocation of " << N << " ints failed", -1);
    ASSERT(cudaSuccess == cudaMemcpy(h_d_ptr, d_ptr, N *sizeof(int), cudaMemcpyDeviceToHost), "Copy of " << N << " ints from device to host failed", -1);
    bool bValid = true;

    for (int i=0; i<N && bValid; i++)
    {
        if (h_ptr[i] != h_d_ptr[i])
        {
            bValid = false;
        }
    }

    ASSERT(cudaSuccess == cudaFree(d_ptr),       "Device deallocation failed", -1);
    ASSERT(cudaSuccess == cudaFreeHost(h_ptr),   "Host deallocation failed",   -1);
    ASSERT(cudaSuccess == cudaFreeHost(h_d_ptr), "Host deallocation failed",   -1);

    cout << "Memory deallocated successfully" << endl;
    cout << "TEST Results " << endl;

    int *grafo;
    grafo = readGrafo();
    stpPrim(grafo);
    free(grafo);
    exit(bValid ? EXIT_SUCCESS : EXIT_FAILURE);
}
