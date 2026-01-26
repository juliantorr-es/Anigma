# Capsule Benchmarks

## Running Locally

From the repository root, use the BenchmarkHarness runner to execute the capsule suites.

```bash
swift run --package-path Anigma/Benchmarks/BenchmarkHarness anigma-capsule-bench --suite all --pretty
```

### Targeted Suites

```bash
swift run --package-path Anigma/Benchmarks/BenchmarkHarness anigma-capsule-bench --suite vector-index --pretty --output Benchmarks/sample_outputs/vector_index_capsule.json
swift run --package-path Anigma/Benchmarks/BenchmarkHarness anigma-capsule-bench --suite rank-fusion --pretty --output Benchmarks/sample_outputs/rank_fusion_capsule.json
swift run --package-path Anigma/Benchmarks/BenchmarkHarness anigma-capsule-bench --suite text-chunking --pretty --output Benchmarks/sample_outputs/text_chunking_capsule.json
swift run --package-path Anigma/Benchmarks/BenchmarkHarness anigma-capsule-bench --suite pdf --pretty --output Benchmarks/sample_outputs/pdf_capsule.json
swift run --package-path Anigma/Benchmarks/BenchmarkHarness anigma-capsule-bench --suite layout-engine --pretty --output Benchmarks/sample_outputs/layout_engine_capsule.json
```

### Iteration Overrides

```bash
swift run --package-path Anigma/Benchmarks/BenchmarkHarness anigma-capsule-bench --suite vector-index --iterations 25 --pretty
```
