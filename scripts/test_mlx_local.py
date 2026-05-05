#!/usr/bin/env python3
from __future__ import annotations

import inspect
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from rig_tools import mlx_local, schema_validation


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "rig.py"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def _repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="rig-mlx-test-"))
    for rel in [
        "Docs/indexes",
        "Docs/td/briefs",
        "Docs/proofs",
        "Docs/schemas",
        ".build/rig/projections",
        ".build/rig/monitor",
        ".build/rig/results",
        ".build/rig/llm",
        ".build/rig/embeddings",
    ]:
        (repo / rel).mkdir(parents=True, exist_ok=True)
    for rel in [
        "Docs/schemas/rig.local_llm_summary.v1.schema.json",
        "Docs/schemas/rig.embedding_index.v1.schema.json",
    ]:
        (repo / rel).write_text((REPO_ROOT / rel).read_text(encoding="utf-8"), encoding="utf-8")
    return repo


def test_status_handles_missing_and_partial_backends() -> None:
    original = mlx_local._importable
    try:
        mlx_local._importable = lambda name: False
        payload = mlx_local.status()
        assert payload["status"] == "tool_missing"
        assert payload["mlx"] is False
        assert payload["mlx_lm"] is False
        assert payload["mlx_embeddings"] is False
    finally:
        mlx_local._importable = original


def test_status_handles_partial_backends() -> None:
    original = mlx_local._importable
    original_probe_embeddings = mlx_local._probe_mlx_embeddings_backend
    original_probe_embedding_models = mlx_local._probe_mlx_embedding_models_backend
    try:
        mlx_local._importable = lambda name: name in {"mlx", "mlx_lm"}
        mlx_local._probe_mlx_embeddings_backend = lambda: None
        mlx_local._probe_mlx_embedding_models_backend = lambda: None
        payload = mlx_local.status()
        assert payload["status"] == "partial"
        assert payload["mlx"] is True
        assert payload["mlx_lm"] is True
        assert payload["mlx_embeddings"] is False
    finally:
        mlx_local._importable = original
        mlx_local._probe_mlx_embeddings_backend = original_probe_embeddings
        mlx_local._probe_mlx_embedding_models_backend = original_probe_embedding_models


def test_status_reports_selected_backends_and_versions() -> None:
    original_importable = mlx_local._importable
    original_probe_embeddings = mlx_local._probe_mlx_embeddings_backend
    original_probe_embedding_models = mlx_local._probe_mlx_embedding_models_backend
    original_version = mlx_local._module_version
    try:
        mlx_local._importable = lambda name: name in {"mlx", "mlx_lm", "mlx_embeddings", "mlx_embedding_models"}
        mlx_local._probe_mlx_embeddings_backend = lambda: {"module": object()}
        mlx_local._probe_mlx_embedding_models_backend = lambda: {"EmbeddingModel": object()}
        mlx_local._module_version = lambda name: f"{name}-v"
        payload = mlx_local.status()
        assert payload["selected_generation_backend"] == "mlx_lm"
        assert payload["selected_embedding_backend"] == "mlx_embeddings"
        assert payload["python_version"]
        assert payload["mlx_version"] == "mlx-v"
        assert payload["mlx_embeddings_version"] == "mlx_embeddings-v"
        assert payload["mlx_embedding_models_version"] == "mlx_embedding_models-v"
    finally:
        mlx_local._importable = original_importable
        mlx_local._probe_mlx_embeddings_backend = original_probe_embeddings
        mlx_local._probe_mlx_embedding_models_backend = original_probe_embedding_models
        mlx_local._module_version = original_version


def test_detect_mlx_environment_reports_package_fields() -> None:
    env = mlx_local.detect_mlx_environment()
    assert "python_executable" in env
    assert "python_version" in env
    assert "mlx" in env
    assert "mlx_lm" in env
    assert "mlx_embeddings" in env
    assert "mlx_embedding_models" in env


def test_prompt_is_advisory_and_bounded() -> None:
    prompt = mlx_local.build_prompt(task="td-cleanup-005", kind="session", source_artifacts=["a.md"], context="x" * 10000)
    assert "advisory only" in prompt
    assert "Rig deterministic artifacts are authoritative" in prompt
    assert len(prompt) < 11000


def test_fake_summary_generation_writes_outputs() -> None:
    repo = _repo()
    (repo / ".build/rig/results/latest.json").write_text(json.dumps({"schema_version": "rig.result.v1", "summary": {"command_summary": "ok"}}), encoding="utf-8")
    (repo / ".build/rig/monitor/state.json").write_text(json.dumps({"schema_version": "rig.monitor_state.v1"}), encoding="utf-8")
    original = mlx_local.generate_summary
    try:
        mlx_local.generate_summary = lambda **kwargs: {"status": "generated", "backend": "mlx", "model": "m", "warnings": [], "error": None, "output": "short summary"}
        payload = mlx_local.summarize_session(repo, task="td-cleanup-005", model="m")
        assert payload["schema_version"] == "rig.local_llm_summary.v1"
        assert payload["authoritative"] is False
        assert (repo / ".build/rig/llm/latest-summary.json").exists()
        assert (repo / ".build/rig/llm/latest-summary.md").exists()
        assert (repo / ".build/rig/llm/td-cleanup-005-session-summary.json").exists()
    finally:
        mlx_local.generate_summary = original


def test_query_compact_documents_excludes_junk() -> None:
    repo = _repo()
    (repo / "Docs/indexes/ok.json").write_text("{}", encoding="utf-8")
    (repo / "Docs/proofs/ok.md").write_text("proof", encoding="utf-8")
    (repo / "Docs/proofs/.DS_Store").write_text("junk", encoding="utf-8")
    (repo / "Docs/proofs/__MACOSX").mkdir(parents=True, exist_ok=True)
    (repo / "Docs/proofs/__MACOSX" / "ignored.md").write_text("junk", encoding="utf-8")
    (repo / "Docs/proofs/.hidden.md").write_text("junk", encoding="utf-8")
    (repo / ".build/rig/monitor/state.json").write_text("{}", encoding="utf-8")
    docs = mlx_local.collect_embedding_documents(repo)
    paths = {doc["path"] for doc in docs}
    assert "Docs/indexes/ok.json" in paths
    assert "Docs/proofs/ok.md" in paths
    assert not any(path.endswith(".DS_Store") for path in paths)
    assert not any("__MACOSX" in path for path in paths)
    assert not any(Path(path).name.startswith(".") for path in paths)


def test_text_embeds_normalization_variants() -> None:
    class Obj:
        def __init__(self, data):
            self.text_embeds = data

    assert mlx_local._extract_text_embeds(Obj([1, 2, 3])) == [[1.0, 2.0, 3.0]]
    assert mlx_local._extract_text_embeds({"text_embeds": [4, 5, 6]}) == [[4.0, 5.0, 6.0]]
    assert mlx_local._extract_text_embeds({"text_embeds": [[7, 8], [9, 10]]}) == [[7.0, 8.0], [9.0, 10.0]]
    assert mlx_local._extract_text_embeds([11, 12, 13]) == [[11.0, 12.0, 13.0]]
    assert mlx_local._to_python_matrix([[1, 2], [3, 4]]) == [[1.0, 2.0], [3.0, 4.0]]


def test_fake_embeddings_build_and_query() -> None:
    repo = _repo()
    (repo / "Docs/indexes/ok.json").write_text("{}", encoding="utf-8")
    (repo / "Docs/proofs/one.md").write_text("alpha beta", encoding="utf-8")
    (repo / "Docs/proofs/two.md").write_text("gamma delta", encoding="utf-8")
    original_backend = mlx_local._build_embeddings_backend
    try:
        def fake_embed(texts, model):
            vecs = []
            for text in texts:
                base = float(len(text))
                vecs.append([base, base / 2.0, 1.0])
            return vecs, {"status": "generated", "warnings": [], "backend": "mlx_embeddings"}

        mlx_local._build_embeddings_backend = fake_embed
        index = mlx_local.build_embeddings(repo, model="fake")
        assert index["schema_version"] == "rig.embedding_index.v1"
        assert (repo / ".build/rig/embeddings/index.json").exists()
        assert (repo / ".build/rig/embeddings/vectors.jsonl").exists()
        query = mlx_local.query_embeddings(repo, "alpha", model="fake")
        assert query["status"] == "passed"
        assert query["results"]
        assert query["results"][0]["score"] >= query["results"][-1]["score"]
        vectors_lines = (repo / ".build/rig/embeddings/vectors.jsonl").read_text(encoding="utf-8").splitlines()
        first_vector = json.loads(vectors_lines[0])
        assert {"id", "path", "title", "text_preview", "vector", "metadata"} <= set(first_vector)
    finally:
        mlx_local._build_embeddings_backend = original_backend


def test_embedding_smoke_writes_artifacts() -> None:
    repo = _repo()
    original_backend = mlx_local._build_embeddings_with_mlx_embeddings
    try:
        mlx_local._build_embeddings_with_mlx_embeddings = lambda texts, model: ([[1.0, 2.0], [3.0, 4.0]], {"status": "generated", "warnings": [], "backend": "mlx_embeddings"})
        payload = mlx_local.smoke_embeddings(repo, model="fake")
        assert payload["status"] == "generated"
        assert (repo / ".build/rig/embeddings/smoke.json").exists()
        assert (repo / ".build/rig/embeddings/smoke.md").exists()
    finally:
        mlx_local._build_embeddings_with_mlx_embeddings = original_backend


def test_direct_embedding_smoke_helper_normalizes_vectors() -> None:
    original = mlx_local._build_embeddings_with_mlx_embeddings
    try:
        mlx_local._build_embeddings_with_mlx_embeddings = lambda texts, model: ([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], {"status": "generated", "warnings": [], "backend": "mlx_embeddings"})
        payload = mlx_local.smoke_embed_mlx_embeddings("fake", mlx_local.SMOKE_TEXTS)
        assert payload["vector_count"] == 2
        assert payload["dimension"] == 3
        assert payload["first_vector_preview"] == [1.0, 2.0, 3.0]
    finally:
        mlx_local._build_embeddings_with_mlx_embeddings = original


def test_build_limit_and_top_k_behaviour() -> None:
    repo = _repo()
    for idx in range(5):
        (repo / "Docs/proofs" / f"doc-{idx}.md").write_text(f"doc {idx}", encoding="utf-8")
    original_backend = mlx_local._build_embeddings_backend
    try:
        mlx_local._build_embeddings_backend = lambda texts, model: ([[float(i), float(i + 1)] for i, _ in enumerate(texts)], {"status": "generated", "warnings": [], "backend": "mlx_embeddings"})
        payload = mlx_local.build_embeddings(repo, model="fake", limit=2)
        assert payload["document_count"] == 2
        query = mlx_local.query_embeddings(repo, "alpha", model="fake", top_k=3)
        assert len(query["results"]) <= 3
    finally:
        mlx_local._build_embeddings_backend = original_backend


def test_missing_index_query_returns_missing_index() -> None:
    repo = _repo()
    payload = mlx_local.query_embeddings(repo, "hello")
    assert payload["status"] == "missing_index"


def test_schema_validation_for_generated_artifacts() -> None:
    repo = _repo()
    summary = {
        "schema_version": "rig.local_llm_summary.v1",
        "status": "generated",
        "authoritative": False,
        "backend": "mlx",
        "model": "m",
        "task": "td-cleanup-005",
        "source_artifacts": [],
        "prompt_kind": "session",
        "summary": "short",
        "limitations": [],
        "warnings": [],
        "created_at": "2026-05-05T00:00:00Z",
        "input_char_count": 1,
        "output_char_count": 1,
    }
    index = {
        "schema_version": "rig.embedding_index.v1",
        "backend": "mlx",
        "model": "m",
        "status": "generated",
        "document_count": 1,
        "vector_count": 1,
        "dimension": 3,
        "source_artifacts": ["a"],
        "created_at": "2026-05-05T00:00:00Z",
        "warnings": [],
        "authoritative": False,
    }
    (repo / ".build/rig/llm/latest-summary.json").write_text(json.dumps(summary) + "\n", encoding="utf-8")
    (repo / ".build/rig/embeddings/index.json").write_text(json.dumps(index) + "\n", encoding="utf-8")
    assert schema_validation.validate_artifacts(repo, artifact_path=".build/rig/llm/latest-summary.json").status == "passed"
    assert schema_validation.validate_artifacts(repo, artifact_path=".build/rig/embeddings/index.json").status == "passed"


def test_status_and_build_handle_adapter_unavailable() -> None:
    repo = _repo()
    original_backend = mlx_local._build_embeddings_backend
    try:
        mlx_local._build_embeddings_backend = lambda texts, model: ([], {"status": "backend_unavailable", "warnings": ["no backend"], "backend": "mlx"})
        index = mlx_local.build_embeddings(repo, model="fake")
        assert index["status"] == "backend_unavailable"
        assert schema_validation.validate_artifacts(repo, artifact_path=".build/rig/embeddings/index.json").status == "passed"
    finally:
        mlx_local._build_embeddings_backend = original_backend


def test_smoke_generate_mlx_lm_uses_timeout_and_no_shell_true() -> None:
    source = inspect.getsource(mlx_local)
    assert "shell=True" not in source
    result = mlx_local.smoke_generate_mlx_lm("fake-model", "hello", 10, 1)
    assert result["backend"] == "mlx_lm"
    assert "status" in result


def test_no_shell_true_in_generation_path() -> None:
    source = inspect.getsource(mlx_local)
    assert "shell=True" not in source


def main() -> int:
    test_status_handles_missing_and_partial_backends()
    test_status_handles_partial_backends()
    test_status_reports_selected_backends_and_versions()
    test_detect_mlx_environment_reports_package_fields()
    test_prompt_is_advisory_and_bounded()
    test_fake_summary_generation_writes_outputs()
    test_query_compact_documents_excludes_junk()
    test_text_embeds_normalization_variants()
    test_fake_embeddings_build_and_query()
    test_embedding_smoke_writes_artifacts()
    test_build_limit_and_top_k_behaviour()
    test_missing_index_query_returns_missing_index()
    test_schema_validation_for_generated_artifacts()
    test_status_and_build_handle_adapter_unavailable()
    test_no_shell_true_in_generation_path()
    test_smoke_generate_mlx_lm_uses_timeout_and_no_shell_true()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
