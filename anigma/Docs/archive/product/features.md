# Anigma Core Capabilities & Advanced Features

Anigma is designed as a powerful, versatile platform that combines robust architectural principles with cutting-edge, local-first AI. Its feature set spans core document processing to intelligent automation, all underpinned by strong governance.

## 1. Foundational Capabilities (Anigma Core)

These are the architectural strengths that enable Anigma's advanced features.

*   **Entity-Component-System (ECS) Architecture:** A modular, scalable, and flexible core that separates data (Components) from behavior (Systems), allowing for dynamic and extensible applications. This ensures Anigma can adapt to diverse workflows and data types.
*   **Robust Job & Workflow System:** Manages complex, multi-step tasks (e.g., OCR, alt-media conversion, summarization) efficiently. Features include priority scheduling, retry policies, and workflow definitions, ensuring reliable background processing.
*   **Comprehensive Alt-Media Generation:** Out-of-the-box capabilities to convert documents into various accessible formats:
    *   **EPUB:** For flexible digital reading.
    *   **Braille:** Ready for physical embossing.
    *   **High-Quality Audio:** Text-to-speech with adaptive voice capabilities.

## 2. Advanced AI Features (MLX-Powered Local Intelligence)

Leveraging Apple's MLX framework, Anigma brings powerful machine learning directly to your institution's hardware, ensuring privacy and control.

### 2.1 Intelligent Document Processing (Diaplasion on Steroids)

*   **Semantic Navigation:** Go beyond keyword search. MLX embeddings allow users to ask questions like "Jump to where this form talks about appeal deadlines," enabling intelligent content navigation.
*   **Local Summarization & Simplification:** On-device MLX LLMs generate:
    *   **Low-Reading-Level Versions:** Makes complex documents understandable for diverse audiences.
    *   **Actionable Checklists:** "What you actually need to do" summaries extracted from documents.
    *   **Risk Summaries:** Identify potential legal or financial risks within documents.
*   **On-Device Document Q&A (RAG):** An MLX-powered Q&A system provides instant answers to questions about documents, using their content as local context.
*   **Layout Intelligence:** Vision models classify structural elements (headings, tables, forms) from OCR, ensuring alt-media outputs reflect the document's original structure.

### 2.2 Adaptive & Engaging Audio Experiences

*   **Multi-Voice Personas:** MLX classifies document tone or identifies speakers, assigning different voices for various sections (e.g., narrator, warning voice, explain-mode voice) for richer audio experiences.
*   **Reading-Difficulty-Aware TTS:** MLX assesses sentence complexity and adapts TTS output, either simplifying text before synthesis or dynamically adjusting speed and emphasis for dense segments, creating "neurodivergent-friendly audiobooks."
*   **True Streaming & Interactive Reading:** Seamlessly stream audio content as users scroll, enabling highly responsive and interactive reading experiences driven by the ECS.

### 2.3 Governed Local Agents for Development & Explanation

Harmonia can orchestrate local MLX models to provide powerful, private AI assistance for various tasks.

*   **Local Code-Context Embedder:** An MLX embedding model indexes your monorepo, providing a local, private context engine for dev agents (e.g., for code explanation, refactoring, test generation).
*   **"Governed Assistant" Sandbox:** Run small, local MLX code models for low-risk tasks, with Anigma's governance enforcing "local-first" AI and escalating only when necessary and permitted.
*   **Offline Document Explainer:** Leverage local MLX LLMs to summarize and explain documents entirely on-device, without data leaving your system.

## 3. Robust Governance & Watchdog AI

Anigma uses MLX not just for direct tasks, but to ensure the entire system operates safely and compliantly.

*   **Agent Output Rater:** MLX models evaluate the output of other agents (human or AI), flagging potential risks (e.g., "Too Aggressive," "Unclear," "Missing Deadlines") before content is deployed.
*   **Compliance Tagger:** Automatically classifies incoming documents (e.g., `Financial`, `Medical`, `PII`), enabling the governance engine to enforce strict policies about which workflows and models can access them.
*   **Accessibility Policy Checker:** MLX heuristics quickly identify potential accessibility issues in alt-media outputs (e.g., "link text not descriptive," "summary missing") as a first line of defense.

## 4. Scalable & Distributed Intelligence (MLX Swarm)

Anigma is designed to leverage multiple Apple Silicon devices as a private, governed inference cluster.

*   **Node-Level Capability Discovery:** Anigma nodes announce their MLX model capabilities, allowing Harmonia to intelligently route jobs to the most suitable device.
*   **Priority Routing:** Batch jobs (e.g., pre-computing embeddings) can be scheduled on idle nodes, preserving active nodes for live, interactive agent sessions.
*   **Private Inference Fleet:** This creates a powerful, air-gapped MLX cluster, fully governed by Anigma's rules, providing enterprise-grade AI power with institutional control.

Anigma's features combine to deliver an unparalleled platform for secure, compliant, and intelligent document accessibility and workflow automation.
