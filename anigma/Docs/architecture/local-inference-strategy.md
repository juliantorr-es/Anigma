# Anigma's Local Inference Strategy: MLX, llama.cpp, and Ollama

Anigma's power lies in its ability to run sophisticated AI models directly on-device, ensuring privacy, control, and performance. Our local inference strategy is not monolithic; it leverages a multi-backend approach, selecting the best tool for the job. This guide details the roles of our primary local backends: **MLX**, **`llama.cpp`**, and **Ollama**.

## 1. The Multi-Backend Philosophy

Instead of committing to a single framework, Anigma's Harmonia orchestrator treats local inference engines as swappable providers. This allows us to:

*   **Optimize for Performance:** Use the best-performing engine for a specific model or hardware feature (e.g., MLX for the Neural Engine, `llama.cpp` for its CPU quantization).
*   **Maximize Model Compatibility:** Access the vast ecosystem of `llama.cpp`-compatible GGUF models while also leveraging Apple-native Core ML and MLX formats.
*   **Provide User Flexibility:** Support users who already have an existing setup, like an Ollama server, without forcing them into a single-vendor ecosystem.

This strategy must distinguish model-weight quantization from runtime memory policy. Weight quantization controls the stored model artifact. KV-cache and vector-index quantization control long-context inference memory and retrieval footprint. Research such as TurboQuant is relevant to the second category, so model selection should evaluate cache/index compression separately from GGUF, MLX, or Core ML weight precision.

## 2. MLX: The Apple-Native Powerhouse

*   **Role:** MLX is Anigma's first-class citizen for tight integration with Apple hardware and Swift. It is the preferred backend for custom-trained models, multimodal tasks, and performance-critical operations that can be highly optimized for the Apple Neural Engine (ANE).
*   **Best For:**
    *   **Expressive TTS & Audio:** Models like Kokoro TTS that are built with MLX can leverage the ANE for real-time, low-latency voice generation.
    *   **Vision-Language Models (VLMs):** Running multimodal models for image captioning and Visual Q&A with direct access to Apple's hardware stack.
    *   **Custom Adapters & Fine-Tuning:** Training and deploying small, efficient LoRA-style adapters for domain-specific tasks.
    *   **Core AI Features:** Building Anigma's own "watchdog" models for governance and compliance checks.

## 3. `llama.cpp`: The Universal Workhorse

*   **Role:** `llama.cpp` is our universal engine for running the vast majority of open-source Large Language Models (LLMs). Its highly optimized CPU and Metal performance, combined with the universal GGUF format, makes it indispensable.
*   **Best For:**
    *   **Broad Model Support:** Running thousands of community-provided LLMs that are available in GGUF format.
    *   **Efficient Quantization:** Leveraging `llama.cpp`'s best-in-class quantization methods (e.g., 2-bit, 4-bit) to run large models on devices with limited RAM.
    *   **Reliable Text Generation:** Serving as the primary backend for general-purpose text generation, summarization, and RAG-based Q&A where a specific MLX-native model isn't required.
*   **Integration:** Anigma manages a `llama-server` process directly, providing a dedicated, governed entry point for running GGUF models.

## 4. Ollama: The User-Friendly Entry Point

*   **Role:** Ollama is a popular, easy-to-use tool for running local LLMs. Anigma recognizes and supports Ollama as a user-managed backend. If a user already has an Ollama server running, Anigma can connect to it as another available inference provider.
*   **Best For:**
    *   **Zero-Configuration Setup:** For users who are less technical or already invested in the Ollama ecosystem, Anigma can use their existing models without requiring any manual setup of `llama.cpp` or MLX models.
    *   **Simplified Model Management:** Leveraging Ollama's simple command-line interface for downloading and managing models.
*   **Integration:** The Harmonia daemon probes for a running Ollama instance on `localhost` and, if found, adds its available models to the list of routable inference targets.

## 5. Cache and Vector Compression

Long-context local inference can fail even when model weights fit in memory because the key-value (KV) cache grows with context length and generation. Anigma should track cache policy as part of model routing:

*   **KV-cache policy:** dynamic, static, offloaded, quantized, or backend-native.
*   **Compression metadata:** algorithm, bit width, backend support, and session/durable scope.
*   **Vector-index precision:** embedding model, dimensions, index type, compression policy, and recall floor.
*   **Fallback behavior:** disable compression when unsupported, when context is short enough that compression hurts latency, or when evaluation shows grounding/numeric regressions.

TurboQuant-style research is useful because it shows where future gains may come from: compressing runtime vectors and KV caches rather than only shrinking model files. It is not a current backend requirement unless MLX, `llama.cpp`, Ollama, or a native capsule exposes a supported implementation.

## Orchestration Example: A User Query

When a user asks Anigma a question, the Harmonia Model Router uses this multi-backend strategy to choose the best path:

1.  **Is it a specialized, on-device task?** For example, "generate an audio summary of this text using the 'friendly' voice." Harmonia might route this to a custom TTS adapter running on an **MLX** model.
2.  **Is it a general knowledge or summarization task?** For example, "summarize this long document." Harmonia might select a powerful, quantized 13B parameter model and run it via the managed **`llama.cpp`** server for a high-quality response.
3.  **Does the user have Ollama running with a suitable model?** If the user's policy prefers their existing setup, Harmonia can route the same summarization task to the **Ollama** server instead.

This flexible, intelligent routing ensures that Anigma always uses the right tool for the job, balancing performance, model availability, and user preference, all within our governed, local-first framework.
