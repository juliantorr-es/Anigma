# MLWorkerExecutable

**Machine learning inference service for local and cloud backends.**

`MLWorkerExecutable` (aliased as `ml-worker`) is a specialized service that executes machine learning tasks—such as text generation and vector embeddings—using several supported backends. It is designed to be orchestrated by `AccessumFlow` or used independently for diagnostic purposes.

## Role in the Ecosystem

This executable provides the "brain power" for semantic operations. It abstracts different ML inference engines (MLX, llama.cpp, DeepSeek) behind a unified CLI interface, allowing the rest of the Anigma system to perform intelligent tasks without being tied to a specific local or cloud provider.

## Usage

### Process a Request
The worker typically communicates via NDJSON (Newline Delimited JSON) on standard input, emitting responses on standard output.

```bash
echo '{"requestId": "req1", "engine": "mlx", "task": "embed", "inputs": [{"path": "plain.txt", "hash": "..."}]}' | swift run ml-worker --engine mlx
```

### Mock Mode
For testing in environments without specialized hardware:
```bash
export ML_WORKER_MOCK_MODE=true
swift run ml-worker --engine mlx
```

## Supported Engines

- **MLX**: High-performance Apple Silicon backend for local inference.
- **Llama**: `llama.cpp` based backend for cross-platform local inference.
- **DeepSeek**: OpenAI-compatible cloud backend for large-scale reasoning.
- **Mock**: Deterministic mock engine for CI/CD and integration testing.

## Key Tasks

- **Chat**: Conversational reasoning and text transformation.
- **Embed**: Generating fixed-width vector embeddings for semantic search.
- **Summarize**: High-compression document summarization.

## Configuration

| Environment Variable | Description |
|----------------------|-------------|
| `ML_WORKER_MOCK_MODE`| Set to `true` to use the deterministic mock engine. |
| `MLX_MODEL_ID` | Default HuggingFace model ID for MLX tasks. |
| `DEEPSEEK_API_KEY` | API key for the DeepSeek cloud backend. |
| `LLAMA_BACKEND_BINARY`| Path to the `llama-cli` executable. |

## Provenance and Security

Every response emitted by `MLWorkerExecutable` includes:
- **Binary Hash**: A cryptographic digest of the worker binary itself.
- **Model Metadata**: Hashes and identifiers for the specific model weights used.
- **Argv Trace**: The exact command-line arguments passed to the underlying backend (if applicable).

## Dependencies

- **MLWorkerCommon**: Shared types and protocols.
- **MLX / MLXLMCommon**: Local inference for Apple Silicon.
- **ArgumentParser**: CLI interface.
- **CryptoKit**: Provenance hashing.

## License

Part of the Anigma project. See LICENSE for details.
