# TurboQuant Research Note for Local Inference

Status: research input only. TD remains the source of truth for implementation status and priority.

Last reviewed: 2026-04-10

## Summary

TurboQuant is a Google Research vector quantization technique announced on 2026-03-24 for compressing high-dimensional vectors used in KV caches and vector search. It should not be confused with ordinary model-weight quantization such as GGUF Q4/Q5, MLX quantized weights, or Core ML precision choices.

The practical implication for Anigma is narrower and more useful:

- Use TurboQuant-style research to shape how Anigma evaluates long-context local inference.
- Treat KV-cache quantization and vector-index quantization as explicit runtime knobs.
- Gate adoption on benchmarks for recall, grounding, latency, memory use, and bookkeeping/numeric accuracy.
- Do not make it a prerequisite for backend completion unless a supported implementation exists in one of Anigma's inference backends.

## What TurboQuant Appears To Solve

Google Research describes TurboQuant as an algorithm for reducing memory overhead in vector quantization. Its target surfaces are:

- KV-cache compression for long-context LLM inference.
- High-dimensional vector search compression.
- Lower memory footprint while preserving attention-score and retrieval quality.

The blog reports evaluation on long-context benchmarks including LongBench, Needle In A Haystack, ZeroSCROLLS, RULER, and L-Eval with open-source models such as Gemma and Mistral. It also reports 3-bit KV-cache quantization without training or fine-tuning and at least 6x key/value memory reduction on needle-in-haystack tasks.

The relevant distinction for Anigma is that this operates on runtime vectors/caches, not just static model files. A Q4 model can still exhaust memory during long runs because the KV cache grows with context length and generated tokens.

## Why This Matters To Anigma

Anigma's target architecture has several memory-pressure points:

- Long-running assistant sessions with recursive context modeling.
- Personal context retrieval over a growing local memory database.
- Small-business workflows that may require long evidence trails, invoices, receipts, emails, CRM history, and project notes.
- Local-first inference on Apple devices where unified memory is shared across UI, daemon services, indexing, and model execution.

TurboQuant-style compression could eventually let Anigma keep larger working contexts and larger vector indexes local without forcing everything through cloud inference. The value is not "bigger model at any cost"; it is controlled local reasoning over more trusted evidence.

## Candidate Integration Points

### 1. Model Selection Policy

Model selection should separate these dimensions:

- Weight quantization: model artifact precision, such as GGUF Q4/Q5 or MLX quantized weights.
- KV-cache policy: dynamic, static, offloaded, quantized, or backend-native cache behavior.
- Context budget: maximum prompt tokens, generated tokens, preserved memory slices, and recursive summaries.
- Retrieval index precision: vector dimensions, embedding model, index type, and vector compression.

This prevents the model registry from saying "quantized model selected" while ignoring the runtime cache behavior that determines whether long-context work survives on-device.

### 2. ModelSpec and RunSpec

The model-run contract should include cache and vector-compression metadata in RunSpec, because these are runtime knobs that can affect output quality, latency, memory use, and cache reuse.

Suggested RunSpec fields:

```json
{
  "cache": {
    "kind": "kv",
    "policy": "quantized",
    "algorithm": "backend-native",
    "bits": 4,
    "scope": "session"
  },
  "retrieval": {
    "vector_compression": "none",
    "bits": null,
    "recall_floor": 0.98
  }
}
```

If a future backend exposes TurboQuant or a comparable technique, it should be represented as a runtime capability and hashed into RunSpec. It should not be hidden inside a backend-specific option string.

### 3. Personal Context Database

Vector compression is attractive for a local personal context database, but it must not degrade evidence retrieval silently. For Anigma, compressed vector indexes need explicit quality gates:

- Top-k recall against an uncompressed index.
- Source diversity retention.
- Temporal recall for stale-but-important facts.
- Receipt/invoice/entity retrieval accuracy.
- Abstention behavior when compressed retrieval misses evidence.

### 4. Observability

Any cache or vector compression policy should emit metrics:

- Prompt tokens, generated tokens, and effective context length.
- KV-cache memory footprint.
- Time to first token and tokens per second.
- Retrieval latency and recall evaluation results.
- Fallback reason when compressed cache/index is disabled.
- Quality/regression labels from assistant eval fixtures.

## Evaluation Matrix Before Adoption

| Surface | What To Measure | Acceptance Direction |
| --- | --- | --- |
| Long-context QA | Needle retrieval, citation correctness, source grounding | No material grounding regression versus baseline |
| Small-business workflows | Invoice, receipt, reconciliation, CRM follow-up, project evidence tasks | No numeric/bookkeeping regression |
| Memory footprint | Peak daemon + inference memory during long runs | Meaningful reduction versus uncompressed cache/index |
| Latency | Time to first token, tokens/sec, retrieval latency | Improvement or acceptable tradeoff |
| Determinism/replay | Same RunSpec and inputs reproduce expected cache/index behavior | RunSpec captures compression knobs |
| Fallback | Unsupported backend, short context, or quality regression | Disable compression cleanly and log reason |

## Recommendation

Add TurboQuant-style cache/vector quantization as a research-backed evaluation track under local model selection. It should influence Anigma's architecture now by forcing better contracts around KV-cache policy and vector-index compression, but implementation should wait until a supported backend exposes the capability or a scoped native prototype is justified by benchmarks.

For the current backend roadmap, this is not a new P0 blocker. The production-ready move is to ensure Anigma can describe, select, observe, and evaluate cache/vector compression policies before trying to implement an experimental quantizer.

## Sources

- [Google Research: TurboQuant: Redefining AI efficiency with extreme compression](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/)
- [PolarQuant: Quantizing KV Caches with Polar Transformation](https://ar5iv.labs.arxiv.org/html/2502.02617)
- [Hugging Face Transformers: Cache strategies](https://huggingface.co/docs/transformers/main/en/kv_cache)
