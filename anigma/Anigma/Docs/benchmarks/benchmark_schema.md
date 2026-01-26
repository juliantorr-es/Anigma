# Benchmark Result Schema

Benchmark results are emitted as JSON using a report envelope with per-benchmark metrics.

## BenchmarkReport

```json
{
  "generated_at": "2026-01-26T12:00:00Z",
  "results": [
    {
      "name": "string_join",
      "duration_seconds": 0.4821,
      "operations": 2000,
      "ops_per_second": 4148.2,
      "memory_bytes": 32768
    }
  ]
}
```

## Field definitions

- `generated_at` (string, ISO-8601): Timestamp when the benchmark run completed.
- `results` (array): Collection of benchmark results.

### BenchmarkResult

- `name` (string): Stable identifier for the benchmark case.
- `duration_seconds` (number): Total runtime for all iterations.
- `operations` (integer): Number of iterations executed.
- `ops_per_second` (number): Derived throughput, `operations / duration_seconds`.
- `memory_bytes` (integer, optional): Resident memory delta in bytes, if available.

## JSON Schema (draft-07)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "BenchmarkReport",
  "type": "object",
  "required": ["generated_at", "results"],
  "properties": {
    "generated_at": {
      "type": "string",
      "format": "date-time"
    },
    "results": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "duration_seconds", "operations", "ops_per_second"],
        "properties": {
          "name": {"type": "string"},
          "duration_seconds": {"type": "number"},
          "operations": {"type": "integer"},
          "ops_per_second": {"type": "number"},
          "memory_bytes": {"type": "integer"}
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```
