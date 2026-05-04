# Apple Silicon and Metal

## Official Sources
- **Metal `MTLStorageMode.shared`**: [developer.apple.com](https://developer.apple.com/documentation/metal/mtlstoragemode/shared)
- **Metal `makeBuffer(bytesNoCopy:...)`**: [developer.apple.com](https://developer.apple.com/documentation/metal/mtldevice/makebuffer(bytesnocopy:length:options:deallocator:))
- **Apple Silicon Unified Memory**: [WWDC 2020](https://developer.apple.com/videos/play/wwdc2020/10686/)
- **MPSGraph**: [WWDC 2021](https://developer.apple.com/videos/play/wwdc2021/10152/)

## Findings
1. **Unified Memory**: Apple Silicon features a unified memory architecture, meaning the CPU, GPU, and Neural Engine share the same physical memory pool.
2. **Storage Modes**:
   - `MTLStorageMode.shared`: Memory accessible by both CPU and GPU. Default for Apple Silicon.
   - `MTLStorageMode.private`: GPU-only memory (useful for discrete GPUs or highly optimized on-chip resident data).
3. **No-Copy Buffer Wrapping**: The `makeBuffer(bytesNoCopy:...)` API allows Metal to wrap an existing contiguous CPU allocation without allocating new memory or copying data. This is a true zero-copy primitive *if* the backing memory is page-aligned and managed correctly.
4. **MPSGraph**: Provides high-performance execution of multidimensional graphs, automatically dispatching to the optimal compute substrate (CPU, GPU, ANE).

## Anigma Application
- **Zero-Copy**: Anigma can claim zero-copy for Metal execution *only* when `bytesNoCopy` or shared buffers are verifiably used without intermediate materialization.
- **Hardware-Resident**: Data loaded into `MTLStorageMode.private` is hardware-resident and requires explicit copies to return to the CPU.