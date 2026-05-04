# ROCm Heterogeneous Compute

## Official Sources
- **ROCm Documentation**: [rocm.docs.amd.com](https://rocm.docs.amd.com/en/latest/)
- **ROCm Programming Guide**: [rocm.docs.amd.com](https://rocm.docs.amd.com/en/latest/how-to/programming_guide.html)

## Findings
AMD ROCm is an open software platform optimized for HPC and AI workloads. 
- It supports heterogeneous programs running across CPUs and AMD GPUs.
- It utilizes HIP (Heterogeneous-Compute Interface for Portability) to allow C++ code to run on both AMD and NVIDIA GPUs.
- Similar to CUDA, ROCm on discrete GPUs involves explicit memory management and data transfer over interconnects (PCIe/Infinity Fabric).

## Anigma Application
- **Portable Contract**: Anigma's upper layers must remain ignorant of whether HIP, Metal, or CUDA is executing the workload.
- **Native Executor**: ROCm-specific logic must be isolated behind a native executor boundary, ensuring the portable ECS-inspired component data can be serialized or transferred to the ROCm sidecar efficiently.