# AI Frameworks on Apple Silicon

This guide covers the three primary ways to run high-performance AI on macOS: **MLX**, **llama.cpp**, and **CoreML**.

## 1. MLX (Machine Learning eXplore)

**Developed by:** Apple Machine Learning Research
**Best for:** Researchers, custom model training/fine-tuning, and running massive models efficiently on Apple Silicon.

### Key Features
- **Unified Memory**: Arrays live in shared memory (CPU/GPU). No expensive data copying.
- **Lazy Evaluation**: Computations are only executed when results are needed, allowing for graph optimization.
- **NumPy-like API**: If you know `numpy`, you know `mlx.core`.
- **PyTorch-like API**: `mlx.nn` provides layers and optimizers similar to PyTorch.

### Installation
```bash
pip install mlx
```

### Quick Example (Python)
```python
import mlx.core as mx

# Create arrays (allocated lazily)
a = mx.array([1.0, 2.0, 3.0])
b = mx.array([4.0, 5.0, 6.0])

# Perform operation (compiles to Metal kernel)
c = a + b
mx.eval(c) # Trigger computation
print(c)
```

## 2. llama.cpp

**Developed by:** Community (Georgi Gerganov)
**Best for:** High-speed inference of LLMs (Llama, Mistral, Mixtral) using integer quantization.

### Key Features
- **No Dependencies**: Pure C/C++.
- **Apple Silicon Optimized**: Uses Metal (MPS) and NEON SIMD intrinsics extensively.
- **Quantization**: Supports 1.5-bit to 8-bit integer quantization (GGUF format), drastically reducing memory usage with minimal accuracy loss.
- **Server Mode**: Includes a production-ready HTTP server compatible with OpenAI's API.

### Usage
1.  **Download Model**: Get a `.gguf` file from HuggingFace (e.g., `TheBloke/Llama-2-7b-Chat-GGUF`).
2.  **Build**:
    ```bash
    git clone https://github.com/ggml-org/llama.cpp
    cd llama.cpp
    make
    ```
3.  **Run**:
    ```bash
    ./main -m ./models/llama-2-7b-chat.Q4_K_M.gguf -p "Hello, world!" -n 128
    ```

## 3. CoreML

**Developed by:** Apple
**Best for:** Production apps deploying standard models to iOS/macOS/watchOS/tvOS.

### Key Features
- **ANE Support**: Can target the Apple Neural Engine (ANE) for extreme efficiency, freeing up GPU/CPU.
- **Integration**: Seamlessly integrated into Xcode and Swift.
- **Model Format**: Uses `.mlpackage` or `.mlmodel`.

### Workflow
1.  **Convert**: Use `coremltools` (Python) to convert PyTorch/TensorFlow models to CoreML.
2.  **Import**: Drag the model into Xcode. Swift classes are auto-generated.
3.  **Predict**:
    ```swift
    // Auto-generated class
    let model = try MyImageClassifier(configuration: config)
    let output = try model.prediction(image: myCVPixelBuffer)
    ```

### Comparison Summary

| Feature | MLX | llama.cpp | CoreML |
| :--- | :--- | :--- | :--- |
| **Primary Language** | Python, C++, Swift | C++ | Swift, Obj-C |
| **Hardware Target** | GPU, CPU | GPU (Metal), CPU | ANE, GPU, CPU |
| **Flexibility** | High (Research) | Medium (LLMs specific) | Low (Fixed Graph) |
| **Ease of Use** | Moderate | Easy (CLI) | Very Easy (App Dev) |
