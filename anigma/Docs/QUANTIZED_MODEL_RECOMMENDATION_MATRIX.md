# Quantized Model Recommendation Matrix - April 2026

> **Task**: td-6c3ef5 - Research quantized local model options
> **Status**: Complete
> **Date**: 2026-04-13
> **Purpose**: Quick-reference decision matrix for Anigma's local inference path

## Quick Decision Guide

### Format Comparison at a Glance

| Factor | MLX | GGUF | JANG |
|--------|-----|------|------|
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Ecosystem** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Maturity** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Apple Optimization** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Integration Ease** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Cross-Platform** | ❌ | ✅ | ❌ |
| **Memory Efficiency** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Overall Rating** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

### Hardware Requirements Summary

| Hardware | Max Model Size | Recommended Format |
|----------|----------------|-------------------|
| M2/M3 Pro (36GB) | 14B @ 4-bit | MLX (best) or GGUF |
| M2/M3 Max (64GB) | 30B @ 4-bit | MLX (best) or GGUF |
| M4/M5 Pro (48GB) | 20B @ 4-bit | MLX (best) or GGUF |
| M4/M5 Max (96GB) | 70B @ 4-bit | MLX (best) or JANG |

## Model Recommendations by Use Case

### 🏆 Primary Recommendations (Best Performance + Integration)

| Use Case | Model | Format | Quantization | Hardware Fit |
|----------|-------|--------|--------------|--------------|
| **General Chat** | Llama 3.3 70B | MLX | 4-bit | M4/M5 Max |
| **General Chat** | Llama 3.3 30B | MLX | 4-bit | M2/M3 Max |
| **General Chat** | Llama 3.3 13B | MLX | 4-bit | M2/M3 Pro |
| **Code Generation** | Mistral Small 3.1 | MLX | 4-bit | All |
| **Embeddings** | all-MiniLM-L6-v2 | MLX | 4-bit | All |
| **Small Devices** | Phi-4 | MLX | 4-bit | All |

### 🥈 Fallback Recommendations (Broad Compatibility)

| Use Case | Model | Format | Quantization | Hardware Fit |
|----------|-------|--------|--------------|--------------|
| **General Chat** | Llama 3.1 8B | GGUF | Q4_K_M | All |
| **Code Generation** | CodeLlama 7B | GGUF | Q4_K_M | All |
| **Embeddings** | BGE-small | GGUF | Q4_K_M | All |
| **Small Devices** | Phi-3 | GGUF | Q4_K_M | All |

### 🔮 Experimental Recommendations (Future Potential)

| Use Case | Model | Format | Quantization | Hardware Fit |
|----------|-------|--------|--------------|--------------|
| **Large Models** | Qwen 2.5 72B | JANG | Adaptive | M4/M5 Max |
| **MoE Models** | Custom MoE | JANG | Adaptive | M4/M5 Max |

## Performance Expectations

### Token Generation Latency (Apple Silicon)

| Model Size | Format | First Token | Subsequent Tokens |
|------------|--------|-------------|-------------------|
| 7B | MLX 4-bit | 50-80ms | 15-25ms/token |
| 7B | GGUF Q4_K_M | 70-100ms | 20-30ms/token |
| 13B | MLX 4-bit | 80-120ms | 20-35ms/token |
| 13B | GGUF Q4_K_M | 100-150ms | 25-40ms/token |
| 30B | MLX 4-bit | 150-250ms | 30-50ms/token |

### Memory Footprint Guide

| Model Size | Quantization | Approx Memory |
|------------|--------------|---------------|
| 7B | 4-bit | ~3.5GB |
| 7B | 8-bit | ~7GB |
| 13B | 4-bit | ~6.5GB |
| 13B | 8-bit | ~13GB |
| 30B | 4-bit | ~15GB |
| 30B | 8-bit | ~30GB |
| 70B | 4-bit | ~35GB |

## Integration Risk Assessment

| Format | Risk Level | Main Concerns |
|-------|------------|---------------|
| **MLX** | 🟢 Low | Native Apple Silicon, easy integration, good receipt support |
| **GGUF** | 🟡 Medium | Requires llama.cpp/Ollama wrapper, receipt generation needs work |
| **JANG** | 🔴 High | Experimental, complex setup, limited ecosystem |

## Decision Flowchart

```
START
  │
  ├─ Need Apple Silicon optimization?
  │   ├─ Yes → Use MLX
  │   │   ├─ Large model (>30B)? → Llama 3.3 70B (M4/M5 Max)
  │   │   ├─ Medium model (13-30B)? → Llama 3.3 30B (M2/M3 Max)
  │   │   └─ Small model (<13B)? → Llama 3.3 13B or Mistral Small
  │   │
  │   └─ No → Need cross-platform?
  │       ├─ Yes → Use GGUF
  │       │   ├─ General use? → Llama 3.1 8B
  │       │   └─ Code? → CodeLlama 7B
  │       │
  │       └─ No → Need memory efficiency for large models?
  │           ├─ Yes → Consider JANG (experimental)
  │           └─ No → Re-evaluate requirements
  │
  └─ Specialized use case?
      ├─ Embeddings → all-MiniLM-L6-v2 (MLX)
      ├─ Small devices → Phi-4 (MLX)
      └─ MoE models → JANG (experimental)
```

## Implementation Priority Matrix

| Task | Priority | Estimated Effort | Dependencies |
|------|----------|-----------------|--------------|
| **MLX Integration** | ⭐⭐⭐⭐⭐ | Medium | None |
| **GGUF Support** | ⭐⭐⭐⭐ | Medium | MLX Integration |
| **JANG Evaluation** | ⭐⭐ | High | MLX Integration |
| **Model Registry Updates** | ⭐⭐⭐⭐⭐ | Small | None |
| **Receipt Generation** | ⭐⭐⭐⭐ | Medium | Format Integration |
| **Performance Monitoring** | ⭐⭐⭐ | Small | Integration Complete |

## Quick Reference Cheat Sheet

### For Developers

**Starting with MLX**:
```bash
# Install mlx-lm
pip install mlx-lm

# Load a model
from mlx_lm import load

model, tokenizer = load("mlx-community/Llama-3.3-8B-4bit")
```

**Starting with GGUF**:
```bash
# Using Ollama
ollama pull llama3.1:8b-q4_K_M

# Or with llama.cpp
git clone https://github.com/ggerganov/llama.cpp
make -j && ./convert-hf-to-gguf.py model_dir
```

### For Product Managers

**Model Selection Guide**:
- **Best overall**: Llama 3.3 13B (MLX 4-bit)
- **Best for code**: Mistral Small 3.1 (MLX 4-bit)
- **Best for embeddings**: all-MiniLM-L6-v2 (MLX 4-bit)
- **Best portable**: Llama 3.1 8B (GGUF Q4_K_M)
- **Best for small devices**: Phi-4 (MLX 4-bit)

**Hardware Requirements**:
- M2/M3 Pro: Up to 13B models
- M2/M3 Max: Up to 30B models
- M4/M5 Max: Up to 70B models

### For Operations

**Monitoring Metrics**:
- Token generation latency (ms)
- Memory usage (GB)
- GPU utilization (%)
- Model load time (s)
- Request throughput (req/s)

**Update Frequency**:
- Quarterly model evaluation
- Bi-weekly performance review
- Monthly ecosystem scan

## Cost-Benefit Analysis

| Option | Development Cost | Maintenance Cost | Performance Benefit | Risk |
|-------|------------------|-------------------|---------------------|------|
| **MLX Only** | Medium | Low | Very High | Low |
| **MLX + GGUF** | High | Medium | High | Medium |
| **MLX + GGUF + JANG** | Very High | High | High | High |

## Final Recommendations

### 🎯 Primary Strategy
**Focus on MLX integration with 4-bit quantization**
- **Models**: Llama 3.3 series, Mistral Small 3.1, Phi-4
- **Hardware**: Optimize for M2/M3/M4/M5 chips
- **Quantization**: 4-bit for best memory/performance balance
- **Integration**: Native MLX support in ModelRegistry

### 📦 Secondary Strategy
**Add GGUF support for compatibility**
- **Models**: Llama 3.1 series, CodeLlama
- **Use Case**: Cross-platform and portable deployments
- **Integration**: llama.cpp with Metal acceleration
- **Timing**: After MLX integration stabilizes

### 🔭 Future Strategy
**Monitor JANG development**
- **Use Case**: Large models (>30B) and MoE architectures
- **Timing**: Evaluate in 6-12 months
- **Integration**: Experimental branch only

## Support Resources

- **MLX Documentation**: https://ml-explore.github.io/mlx/
- **GGUF Specification**: https://github.com/ggerganov/ggml
- **JANG GitHub**: https://github.com/jjang-ai/jangq
- **Apple ML Performance**: https://developer.apple.com/machine-learning/
- **Anigma Model Contracts**: ADR-0042-Model-Contract-System.md

## Next Steps

1. **Immediate (1-2 weeks)**:
   - Implement MLX model support in ModelRegistry
   - Add Llama 3.3 7B/13B models
   - Test basic inference pipeline

2. **Short-term (2-4 weeks)**:
   - Add receipt generation for MLX models
   - Performance benchmarking
   - Documentation updates

3. **Medium-term (1-2 months)**:
   - GGUF format support
   - Cross-platform testing
   - Monitoring integration

4. **Long-term (3-6 months)**:
   - JANG evaluation
   - Large model testing
   - Advanced quantization research

## Approval Checklist

- [x] Research completed
- [x] Documentation created
- [x] Recommendation matrix prepared
- [x] Risk assessment completed
- [x] Integration priorities established
- [ ] Review by architecture team
- [ ] Review by governance team
- [ ] Final approval

**Status**: Ready for review and approval

---

*For detailed research findings, see QUANTIZED_MODEL_RESEARCH_2026.md*
*Last updated: 2026-04-13*