################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CU_SRCS += \
../src/template_runtime.cu 

CU_DEPS += \
./src/template_runtime.d 

OBJS += \
./src/template_runtime.o 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.cu
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	/usr/local/cuda-5.5/bin/nvcc -I"/usr/local/cuda-5.5/samples/0_Simple" -I/usr/local/include/igraph -I"/usr/local/cuda-5.5/samples/common/inc" -I"/home/john/cuda-workspace/primCUDA" -G -g -O0 -m64 -gencode arch=compute_20,code=sm_20 -gencode arch=compute_20,code=sm_21 -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	/usr/local/cuda-5.5/bin/nvcc --compile -G -I"/usr/local/cuda-5.5/samples/0_Simple" -I/usr/local/include/igraph -I"/usr/local/cuda-5.5/samples/common/inc" -I"/home/john/cuda-workspace/primCUDA" -O0 -g -gencode arch=compute_20,code=compute_20 -gencode arch=compute_20,code=sm_21 -m64  -x cu -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


