# CUDA Unified Memory

## Official Sources
- **CUDA Programming Guide**: [docs.nvidia.com](https://docs.nvidia.com/cuda/cuda-programming-guide/index.html)
- **CUDA Unified Memory**: [docs.nvidia.com](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/unified-memory.html)

## Findings
NVIDIA's Unified Memory provides a single memory space accessible from any CPU or GPU in a system.
- **Managed Memory**: Unlike Apple Silicon's physically shared memory, CUDA Unified Memory (`cudaMallocManaged`) often involves the driver automatically migrating pages on-demand between host (CPU) and device (GPU) memory.
- **Performance Characteristics**: While the pointer is shared, data may still be copied over the PCIe bus transparently. Thus, "Unified Memory" in discrete NVIDIA architectures does not guarantee "zero-copy" physical execution in the same way an integrated SoC might.

## Anigma Application
- Anigma must distinguish between "physically shared" (Apple Silicon) and "logically shared / page-migrated" (discrete CUDA).
- Fallback paths and native executors must model PCIe transfer overheads when operating on discrete GPUs.