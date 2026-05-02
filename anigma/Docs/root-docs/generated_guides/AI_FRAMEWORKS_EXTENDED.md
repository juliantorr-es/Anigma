# AI Frameworks on Apple Silicon: Extended Guide

**Date**: February 2026
**Hardware Focus**: M-Series Chips (Unified Memory Architecture)

## 1. MLX: The Researcher's Powerhouse

MLX is designed for raw performance on Apple Silicon. It is not just "NumPy for Mac"; it is a lazy-evaluated, composable graph compiler targeting Metal.

### Core Architecture: Unified Memory & Lazy Eval
- **Unified Memory**: MLX arrays live in shared memory. `mx.array([1, 2])` is accessible by CPU and GPU instantly.
- **Lazy Evaluation**:
  ```python
  import mlx.core as mx
  a = mx.random.uniform(shape=(1000, 1000))
  b = mx.random.uniform(shape=(1000, 1000))
  c = a @ b # Nothing happens here! Graph node created.
  mx.eval(c) # NOW computation triggers on GPU.
  ```
- **Implication**: You must explicitly `eval()` outputs if you are timing code, otherwise you are just timing graph construction.

### LoRA Fine-Tuning Example (Conceptual)
MLX is widely used for efficient LoRA (Low-Rank Adaptation) fine-tuning of LLMs locally.

```python
# Simplified Logic
model = load_model("llama-3-8b")
# Freeze base model
model.freeze()
# Inject LoRA adapters
lora_layers = create_lora_layers(model, rank=8)

def loss_fn(model, inputs, targets):
    logits = model(inputs)
    return nn.losses.cross_entropy(logits, targets)

# Optimizer
optimizer = optim.AdamW(learning_rate=1e-5)

# Training Step (Compiled!)
@mx.compile
def step(inputs, targets):
    loss, grads = mx.value_and_grad(loss_fn)(model, inputs, targets)
    optimizer.update(model, grads)
    return loss
```
*Note: The `@mx.compile` decorator fuses kernels, often resulting in 2-3x speedups over eager execution.*

## 2. llama.cpp: Production Inference

### Quantization Formats (GGUF)
Understanding "Q4_K_M" vs "Q8_0" is critical for balancing RAM vs Quality.

| Quantization | Bits/Weight | Perplexity Loss | RAM (7B Model) | Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **F16** | 16 | 0.00% | ~14 GB | Reference / Research |
| **Q8_0** | 8 | ~0.01% | ~7.5 GB | High Precision Apps |
| **Q5_K_M** | ~5.5 | ~0.1% | ~5.8 GB | **Sweet Spot** (Recommended) |
| **Q4_K_M** | ~4.5 | ~0.5% | ~4.8 GB | Standard Consumer |
| **Q2_K** | ~2.5 | High | ~3.0 GB | Emergency / Low-end |

*Tip: Always prefer "K-quants" (K_M, K_S) over legacy formats like Q4_0/Q4_1 as they better preserve attention head accuracy.*

### Server API (OpenAI Compatible)
Run `llama-server` to replace OpenAI in your apps locally.
```bash
./llama-server 
  -m models/mistral-7b-v0.3.Q5_K_M.gguf 
  --ctx-size 8192 
  --n-gpu-layers 99 
  --host 0.0.0.0 --port 8080
```
**Features:**
- `/v1/chat/completions`: Drop-in replacement for GPT-4.
- **Grammar Sampling**: Enforce JSON output schema rigidly.
  ```bash
  --grammar-file grammars/json.gbnf
  ```

## 3. CoreML: The App Deployer

### Neural Engine (ANE) vs GPU
- **ANE**: Specialized for heavy matrix math (Conv2D, MatMul). Extremely power efficient. Best for Vision/CNNs.
- **GPU**: Better for Transformer models (LLMs) with dynamic shapes or operations not supported by ANE.

### Optimization Tips
1.  **Batch Predictions**: If processing video frames, use `VNCoreMLRequest` or batch predict APIs. Sending one by one incurs massive overhead.
2.  **Fixed vs Dynamic Shapes**: ANE *hates* dynamic shapes. If possible, resize inputs to fixed dimensions (e.g., 512x512) before inference. Dynamic shapes force fallback to GPU/CPU.
3.  **Quantization**:
    ```python
    # CoreML Tools (Python)
    from coremltools.models.neural_network import quantization_utils
    model = ct.convert(torch_model, inputs=[ct.TensorType(shape=(1, 3, 512, 512))])
    # Quantize weights to 16-bit float (free 50% size reduction, usually 0 accuracy loss)
    model_fp16 = quantization_utils.quantize_weights(model, nbits=16)
    ```
