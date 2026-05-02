# Inference Provider Landscape

Anigma/Harmonia treats inference as a governed capability surface. Each platform gets a curated provider stack, but all of them sit behind the same engine contract (artifact envelope, reuse gate, action bridge).

## Windows

- **MLX-like runtimes:** ONNX Runtime with DirectML (and vendor execution providers such as OpenVINO, TensorRT, Qualcomm QNN) is the Windows center of gravity. Export models to ONNX and choose the proper EP for the GPU/CPU you have.
- **LLM-focused runtimes:** `llama.cpp` runs on Windows with CUDA, Vulkan, SYCL backends. `MLC LLM` targets Vulkan and mobile-friendly GPUs. Both are viable plug-ins behind Harmonia’s capability gating.

## Linux

- **MLX-like runtimes:** MLX itself now ships Linux packages (CUDA/CPU). ONNX Runtime, TensorRT, OpenVINO, ROCm, etc., remain available depending on hardware preferences.
- **LLM-focused runtimes:** `llama.cpp` is first-class with CUDA, HIP, Vulkan, SYCL backends. `MLC LLM` provides another Vulkan-targeted path.

## Android

- **General runtimes:** Lightweight mobile inference frameworks such as `ncnn`, `ExecuTorch` (mobile PyTorch) cover non-LLM workloads with Vulkan/CPU backends.
- **LLM runtimes:** `llama.cpp` (Vulkan, quantized models), `MLC LLM` both target Android.

## iOS

- **General runtimes:** Core ML is the native path; `ncnn` and `ExecuTorch` also provide portable inference.
- **LLM runtimes:** `llama.cpp` runs on Apple hardware with Metal or alternative backends, and `MLC LLM` explicitly supports iOS/iPadOS tipping points.

## Anigma strategy

Harmonia keeps inference provider diversity under one contract: model artifacts (GGUF for llama.cpp-style LLMs, ONNX for generic models, Core ML for Apple-native) plus a capability-gated tool surface. Backends (MLX, llama.cpp, MLC, ONNX Runtime, Core ML, etc.) plug into Harmonia ML Runtime Bridge and HarmoniaArtifacts. The UI/Accessum pipelines only see the inference capability they requested, so platform-specific drama never leaks into the rest of the system.
