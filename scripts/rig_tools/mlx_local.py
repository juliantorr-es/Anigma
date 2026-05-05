from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


SUMMARY_MODEL = "mlx-community/Qwen3-4B-Instruct-2507-4bit"
SUMMARY_MODEL_FALLBACK = "mlx-community/Qwen3-0.6B-4bit"
EMBEDDING_MODEL = "mlx-community/all-MiniLM-L6-v2-4bit"
SMOKE_TEXTS = ["RuntimeAuthority shutdown boundary", "Rig JSONL event stream"]


@dataclass
class BackendStatus:
    backend: str
    python_executable: str
    mlx: bool
    mlx_version: str | None
    mlx_lm: bool
    mlx_lm_version: str | None
    mlx_embeddings: bool
    mlx_embeddings_version: str | None
    mlx_embedding_models: bool
    mlx_embedding_models_version: str | None
    selected_generation_backend: str
    selected_embedding_backend: str
    summary_model: str
    fallback_summary_model: str
    embedding_model: str
    status: str
    warnings: list[str]

    def to_dict(self) -> dict[str, Any]:
        return {
            "backend": self.backend,
            "python_executable": self.python_executable,
            "python_version": sys.version.split()[0],
            "mlx": self.mlx,
            "mlx_version": self.mlx_version,
            "mlx_lm": self.mlx_lm,
            "mlx_lm_version": self.mlx_lm_version,
            "mlx_embeddings": self.mlx_embeddings,
            "mlx_embeddings_version": self.mlx_embeddings_version,
            "mlx_embedding_models": self.mlx_embedding_models,
            "mlx_embedding_models_version": self.mlx_embedding_models_version,
            "selected_generation_backend": self.selected_generation_backend,
            "selected_embedding_backend": self.selected_embedding_backend,
            "summary_model": self.summary_model,
            "fallback_summary_model": self.fallback_summary_model,
            "embedding_model": self.embedding_model,
            "status": self.status,
            "warnings": self.warnings,
        }


def _importable(name: str) -> bool:
    try:
        __import__(name)
    except Exception:
        return False
    return True


def _module_version(name: str) -> str | None:
    try:
        from importlib.metadata import version
        return version(name)
    except Exception:
        try:
            module = __import__(name)
            return getattr(module, "__version__", None)
        except Exception:
            return None


def detect_mlx_environment() -> dict[str, Any]:
    mlx = _importable("mlx")
    mlx_lm = _importable("mlx_lm")
    mlx_embeddings = _importable("mlx_embeddings")
    mlx_embedding_models = _importable("mlx_embedding_models")
    return {
        "python_executable": sys.executable,
        "python_version": sys.version.split()[0],
        "mlx": mlx,
        "mlx_version": _module_version("mlx") if mlx else None,
        "mlx_lm": mlx_lm,
        "mlx_lm_version": _module_version("mlx_lm") if mlx_lm else None,
        "mlx_embeddings": mlx_embeddings,
        "mlx_embeddings_version": _module_version("mlx_embeddings") if mlx_embeddings else None,
        "mlx_embedding_models": mlx_embedding_models,
        "mlx_embedding_models_version": _module_version("mlx_embedding_models") if mlx_embedding_models else None,
    }


def _selected_generation_backend() -> str:
    return "mlx_lm" if _importable("mlx_lm") else "backend_unavailable"


def _selected_embedding_backend() -> str:
    if _probe_mlx_embeddings_backend() is not None:
        return "mlx_embeddings"
    if _probe_mlx_embedding_models_backend() is not None:
        return "mlx_embedding_models"
    return "backend_unavailable"


def status(backend: str = "mlx") -> dict[str, Any]:
    mlx = _importable("mlx")
    mlx_lm = _importable("mlx_lm")
    mlx_embeddings = _importable("mlx_embeddings")
    mlx_embedding_models = _importable("mlx_embedding_models")
    selected_generation_backend = _selected_generation_backend()
    selected_embedding_backend = _selected_embedding_backend()
    warnings: list[str] = []
    if not mlx:
        warnings.append("mlx_unavailable")
    if not mlx_lm:
        warnings.append("mlx_lm_unavailable")
    if not mlx_embeddings:
        warnings.append("mlx_embeddings_unavailable")
    if not mlx_embedding_models:
        warnings.append("mlx_embedding_models_unavailable")
    state = "available" if selected_generation_backend != "backend_unavailable" and selected_embedding_backend != "backend_unavailable" else ("partial" if mlx or mlx_lm or mlx_embeddings or mlx_embedding_models else "tool_missing")
    return BackendStatus(
        backend=backend,
        python_executable=sys.executable,
        mlx=mlx,
        mlx_version=_module_version("mlx"),
        mlx_lm=mlx_lm,
        mlx_lm_version=_module_version("mlx_lm"),
        mlx_embeddings=mlx_embeddings,
        mlx_embeddings_version=_module_version("mlx_embeddings"),
        mlx_embedding_models=mlx_embedding_models,
        mlx_embedding_models_version=_module_version("mlx_embedding_models"),
        selected_generation_backend=selected_generation_backend,
        selected_embedding_backend=selected_embedding_backend,
        summary_model=os.environ.get("RIG_MLX_SUMMARY_MODEL", SUMMARY_MODEL),
        fallback_summary_model=SUMMARY_MODEL_FALLBACK,
        embedding_model=os.environ.get("RIG_MLX_EMBEDDING_MODEL", EMBEDDING_MODEL),
        status=state,
        warnings=warnings,
    ).to_dict()


def _sanitize_text(text: str, limit: int) -> str:
    cleaned = (text or "").replace("\r", " ").replace("\x00", " ")
    return cleaned[:limit]


def _read_text(path: Path, limit: int) -> str:
    try:
        return _sanitize_text(path.read_text(encoding="utf-8", errors="replace"), limit)
    except Exception:
        return ""


def _repo_relative(repo_root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(repo_root))
    except Exception:
        return path.as_posix()


def build_prompt(*, task: str | None, kind: str, source_artifacts: list[str], context: str) -> str:
    lines = [
        "You are assisting Rig, the repo-local Anigma development harness.",
        "Use only the provided Rig artifacts as evidence.",
        "Rig deterministic artifacts are authoritative; your output is advisory only.",
        "Do not invent validation results.",
        "Do not claim access to hidden state.",
        "Be concise and explicit about uncertainty.",
        f"Prompt kind: {kind}",
    ]
    if task:
        lines.append(f"Task: {task}")
    if source_artifacts:
        lines.append("Source artifacts:")
        lines.extend(f"- {item}" for item in sorted(source_artifacts))
    lines.extend(["", "Context:", context.strip(), "", "Return a concise advisory summary."])
    return "\n".join(lines).strip() + "\n"


def _load_generation_backend():
    try:
        from mlx_lm import generate, load  # type: ignore
        return load, generate
    except Exception:
        return None, None


def smoke_generate_mlx_lm(model: str, prompt: str, max_tokens: int, timeout_seconds: int) -> dict[str, Any]:
    load, generate = _load_generation_backend()
    warnings: list[str] = []
    if load and generate:
        try:
            model_obj, tokenizer = load(model)
            output = generate(model_obj, tokenizer, prompt=prompt, max_tokens=max_tokens)
            if isinstance(output, list):
                output = "".join(str(item) for item in output)
            return {
                "status": "generated",
                "backend": "mlx_lm",
                "model": model,
                "warnings": warnings,
                "error": None,
                "output": str(output).strip(),
            }
        except Exception as exc:
            warnings.append(f"python_api_failed:{exc}")
    cmd = [
        sys.executable,
        "-m",
        "mlx_lm.generate",
        "--model",
        model,
        "--prompt",
        prompt,
        "--max-tokens",
        str(max_tokens),
    ]
    try:
        proc = subprocess.run(cmd, text=True, capture_output=True, check=False, timeout=timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        return {
            "status": "failed",
            "backend": "mlx_lm",
            "model": model,
            "warnings": warnings + [f"subprocess_timeout:{timeout_seconds}"],
            "error": f"mlx_lm generate timed out after {timeout_seconds} seconds: {exc}",
            "output": "",
        }
    return {
        "status": "generated" if proc.returncode == 0 else "failed",
        "backend": "mlx_lm",
        "model": model,
        "warnings": warnings,
        "error": None if proc.returncode == 0 else (proc.stderr or "mlx_lm generate failed").strip(),
        "output": proc.stdout.strip(),
    }


def _run_mlx_lm_subprocess(model: str, prompt: str, max_tokens: int, timeout_seconds: int) -> tuple[int, str, str]:
    cmd = [
        sys.executable,
        "-m",
        "mlx_lm.generate",
        "--model",
        model,
        "--prompt",
        prompt,
        "--max-tokens",
        str(max_tokens),
    ]
    proc = subprocess.run(cmd, text=True, capture_output=True, check=False, timeout=timeout_seconds)
    return proc.returncode, proc.stdout, proc.stderr


def generate_summary(*, prompt: str, model: str | None = None, fallback_model: str | None = None, max_tokens: int = 80, timeout_seconds: int = 300) -> dict[str, Any]:
    model = model or os.environ.get("RIG_MLX_SUMMARY_MODEL", SUMMARY_MODEL)
    fallback_model = fallback_model or SUMMARY_MODEL_FALLBACK
    load, generate = _load_generation_backend()
    warnings: list[str] = []
    if load and generate:
        try:
            model_obj, tokenizer = load(model)
        except Exception as exc:
            warnings.append(f"model_load_failed:{model}:{exc}")
            if fallback_model and fallback_model != model:
                try:
                    model_obj, tokenizer = load(fallback_model)
                    model = fallback_model
                except Exception as exc2:
                    return {"status": "failed", "backend": "mlx", "model": model, "fallback_model": fallback_model, "warnings": warnings + [f"model_load_failed:{fallback_model}:{exc2}"], "error": str(exc2), "output": ""}
            else:
                return {"status": "failed", "backend": "mlx", "model": model, "fallback_model": fallback_model, "warnings": warnings, "error": str(exc), "output": ""}
        try:
            output = generate(model_obj, tokenizer, prompt=prompt, max_tokens=max_tokens)
            if isinstance(output, list):
                output = "".join(str(item) for item in output)
            return {"status": "generated", "backend": "mlx", "model": model, "fallback_model": fallback_model, "warnings": warnings, "error": None, "output": str(output)}
        except Exception as exc:
            warnings.append(f"generate_failed:{exc}")
    try:
        rc, stdout, stderr = _run_mlx_lm_subprocess(model, prompt, max_tokens, timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        return {
            "status": "failed",
            "backend": "mlx",
            "model": model,
            "fallback_model": fallback_model,
            "warnings": warnings + [f"subprocess_timeout:{model}:180"],
            "error": f"mlx_lm generate timed out after 180 seconds: {exc}",
            "output": "",
        }
    if rc != 0 and fallback_model and fallback_model != model:
        warnings.append(f"subprocess_failed:{model}:{rc}")
        try:
            rc2, stdout2, stderr2 = _run_mlx_lm_subprocess(fallback_model, prompt, max_tokens, timeout_seconds)
        except subprocess.TimeoutExpired as exc:
            return {
                "status": "failed",
                "backend": "mlx",
                "model": model,
                "fallback_model": fallback_model,
                "warnings": warnings + [f"subprocess_timeout:{fallback_model}:180"],
                "error": f"mlx_lm generate timed out after 180 seconds: {exc}",
                "output": "",
            }
        if rc2 == 0:
            model = fallback_model
            stdout, stderr = stdout2, stderr2
            rc = rc2
        else:
            return {"status": "failed", "backend": "mlx", "model": model, "fallback_model": fallback_model, "warnings": warnings + [f"subprocess_failed:{fallback_model}:{rc2}"], "error": (stderr2 or stderr or "mlx_lm generate failed").strip(), "output": ""}
    return {"status": "generated" if rc == 0 else "failed", "backend": "mlx", "model": model, "fallback_model": fallback_model, "warnings": warnings, "error": None if rc == 0 else (stderr or "mlx_lm generate failed").strip(), "output": stdout.strip()}


def _probe_mlx_embeddings_backend() -> dict[str, Any] | None:
    try:
        import mlx_embeddings  # type: ignore
    except Exception as exc:
        return None
    if hasattr(mlx_embeddings, "load") or hasattr(mlx_embeddings, "generate") or hasattr(mlx_embeddings, "EmbeddingModel") or hasattr(mlx_embeddings, "utils"):
        return {"module": mlx_embeddings}
    return None


def _probe_mlx_embedding_models_backend() -> dict[str, Any] | None:
    try:
        from mlx_embedding_models.embedding import EmbeddingModel  # type: ignore
    except Exception:
        return None
    return {"EmbeddingModel": EmbeddingModel}


def _to_python_vector(value: Any) -> list[float]:
    if value is None:
        return []
    if hasattr(value, "tolist"):
        try:
            value = value.tolist()
        except Exception:
            pass
    if isinstance(value, (list, tuple)):
        if value and isinstance(value[0], (list, tuple)):
            if len(value) == 1:
                return _to_python_vector(value[0])
            return [float(x) for x in value[0]]
        return [float(x) for x in value]
    if isinstance(value, Iterable) and not isinstance(value, (str, bytes, dict)):
        return [float(x) for x in list(value)]
    return [float(value)]


def _to_python_matrix(value: Any) -> list[list[float]]:
    if value is None:
        return []
    if hasattr(value, "tolist"):
        try:
            value = value.tolist()
        except Exception:
            pass
    if isinstance(value, (list, tuple)):
        if not value:
            return []
        if isinstance(value[0], (list, tuple)):
            return [[float(x) for x in row] for row in value]
        return [_to_python_vector(value)]
    if isinstance(value, Iterable) and not isinstance(value, (str, bytes, dict)):
        rows = list(value)
        if rows and isinstance(rows[0], (list, tuple)):
            return [[float(x) for x in row] for row in rows]
        return [_to_python_vector(rows)]
    return [_to_python_vector(value)]


def _extract_text_embeds(output: Any) -> list[list[float]]:
    if output is None:
        return []
    if hasattr(output, "text_embeds"):
        return _to_python_matrix(getattr(output, "text_embeds"))
    if isinstance(output, dict) and "text_embeds" in output:
        return _to_python_matrix(output["text_embeds"])
    if isinstance(output, (list, tuple)):
        if output and hasattr(output[0], "text_embeds"):
            matrices = [_extract_text_embeds(getattr(item, "text_embeds")) for item in output]
            return [row for matrix in matrices for row in matrix]
        if output and isinstance(output[0], (list, tuple)):
            return [_to_python_vector(vec) for vec in output]
        return [_to_python_vector(output)]
    return [_to_python_vector(output)]


def _build_embeddings_with_mlx_embeddings(texts: list[str], model: str) -> tuple[list[list[float]], dict[str, Any]]:
    try:
        from mlx_embeddings import generate as mlx_generate, load as mlx_load  # type: ignore
    except Exception as exc:
        return [], {"status": "tool_missing", "error": str(exc), "warnings": ["mlx_embeddings_unavailable"], "backend": "mlx_embeddings"}
    try:
        _ = mlx_generate
        loaded = mlx_load(model)
        if isinstance(loaded, tuple) and len(loaded) >= 2:
            model_obj, tokenizer = loaded[0], loaded[1]
        else:
            model_obj, tokenizer = loaded, None
        if tokenizer is None:
            if hasattr(model_obj, "encode"):
                output = model_obj.encode(texts)
            else:
                return [], {"status": "unsupported_output_shape", "error": "missing tokenizer and encode method", "warnings": [], "backend": "mlx_embeddings"}
        else:
            if hasattr(tokenizer, "batch_encode_plus"):
                inputs = tokenizer.batch_encode_plus(texts, return_tensors="mlx", padding=True, truncation=True, max_length=512)
            else:
                inputs = tokenizer(texts) if callable(tokenizer) else None
            if inputs is None:
                return [], {"status": "unsupported_output_shape", "error": "tokenizer produced no inputs", "warnings": [], "backend": "mlx_embeddings"}
            if hasattr(model_obj, "process"):
                output = model_obj.process([{"text": text} for text in texts], processor=tokenizer)
            else:
                input_ids = inputs["input_ids"] if isinstance(inputs, dict) else inputs.input_ids
                attention_mask = None
                if isinstance(inputs, dict):
                    attention_mask = inputs.get("attention_mask")
                elif hasattr(inputs, "get"):
                    attention_mask = inputs.get("attention_mask")
                output = model_obj(input_ids, attention_mask=attention_mask)
        vectors = _extract_text_embeds(output)
        if not vectors:
            return [], {"status": "backend_unavailable", "error": "mlx_embeddings produced no vectors", "warnings": [], "backend": "mlx_embeddings"}
        return vectors, {"status": "generated", "warnings": [], "backend": "mlx_embeddings"}
    except Exception as exc:
        return [], {"status": "model_load_failed", "error": str(exc), "warnings": [], "backend": "mlx_embeddings"}


def smoke_embed_mlx_embeddings(model: str, texts: list[str]) -> dict[str, Any]:
    vectors, meta = _build_embeddings_with_mlx_embeddings(texts, model)
    return {
        "backend_package": "mlx_embeddings",
        "model": model,
        "status": meta.get("status"),
        "vector_count": len(vectors),
        "dimension": len(vectors[0]) if vectors else None,
        "first_vector_preview": vectors[0][:8] if vectors else [],
        "warnings": meta.get("warnings") or [],
        "error": meta.get("error"),
        "authoritative": False,
    }


def _build_embeddings_with_mlx_embedding_models(texts: list[str], model: str) -> tuple[list[list[float]], dict[str, Any]]:
    try:
        from mlx_embedding_models.embedding import EmbeddingModel  # type: ignore
    except Exception as exc:
        return [], {"status": "tool_missing", "error": str(exc), "warnings": ["mlx_embedding_models_unavailable"], "backend": "mlx_embedding_models"}
    try:
        if hasattr(EmbeddingModel, "from_registry"):
            emb = EmbeddingModel.from_registry(model)
        else:
            emb = EmbeddingModel(model, pooling_strategy="mean", normalize=True, max_length=512)
        vectors = emb.encode(texts)
        return [_to_python_vector(vec) for vec in vectors], {"status": "generated", "warnings": [], "backend": "mlx_embedding_models"}
    except Exception as exc:
        return [], {"status": "backend_present_but_adapter_unimplemented", "error": str(exc), "warnings": [], "backend": "mlx_embedding_models"}


def _build_embeddings_backend(texts: list[str], model: str) -> tuple[list[list[float]], dict[str, Any]]:
    vectors, meta = _build_embeddings_with_mlx_embeddings(texts, model)
    if vectors:
        return vectors, meta
    if meta.get("status") in {"tool_missing", "backend_unavailable", "unsupported_output_shape", "model_load_failed"}:
        vectors2, meta2 = _build_embeddings_with_mlx_embedding_models(texts, model)
        if vectors2:
            return vectors2, meta2
        if meta2.get("status") not in {"tool_missing", "backend_unavailable"}:
            return vectors2, meta2
        return [], {"status": "backend_unavailable", "error": meta2.get("error") or meta.get("error") or "no embedding backend available", "warnings": [meta.get("status"), meta2.get("status")], "backend": "mlx"}
    return vectors, meta


def collect_summary_context(repo_root: Path, *, task: str | None = None, artifact_path: Path | None = None, limit: int = 6000) -> dict[str, Any]:
    source_artifacts: list[str] = []
    parts: list[str] = []
    if artifact_path and artifact_path.exists():
        source_artifacts.append(_repo_relative(repo_root, artifact_path))
        parts.append(_read_text(artifact_path, limit))
    else:
        candidates = [
            repo_root / ".build" / "rig" / "results" / "latest.json",
            repo_root / ".build" / "rig" / "monitor" / "state.json",
            repo_root / ".build" / "rig" / "projections" / "latest.md",
        ]
        if task:
            candidates.extend([
                repo_root / ".build" / "rig" / "llm" / f"{task}-session-summary.md",
                repo_root / ".build" / "rig" / "git" / f"commit-plan-{task}.md",
            ])
        for path in candidates:
            if path.exists():
                source_artifacts.append(_repo_relative(repo_root, path))
                parts.append(_read_text(path, limit))
    context = "\n\n".join(part for part in parts if part.strip())
    return {"source_artifacts": sorted(set(source_artifacts)), "context": context[:limit]}


def write_summary_artifact(repo_root: Path, *, task: str | None, prompt_kind: str, model: str, source_artifacts: list[str], summary: str, status_text: str, warnings: list[str], input_char_count: int, output_char_count: int) -> dict[str, Any]:
    out_dir = repo_root / ".build" / "rig" / "llm"
    out_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": "rig.local_llm_summary.v1",
        "status": status_text,
        "authoritative": False,
        "backend": "mlx",
        "model": model,
        "task": task,
        "source_artifacts": source_artifacts,
        "prompt_kind": prompt_kind,
        "summary": summary,
        "limitations": ["advisory only", "not validation", "not canonical"],
        "warnings": warnings,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "input_char_count": input_char_count,
        "output_char_count": output_char_count,
    }
    latest_json = out_dir / "latest-summary.json"
    latest_md = out_dir / "latest-summary.md"
    latest_json.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    latest_md.write_text(summary.strip() + "\n", encoding="utf-8")
    if task:
        (out_dir / f"{task}-session-summary.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (out_dir / f"{task}-session-summary.md").write_text(summary.strip() + "\n", encoding="utf-8")
    return payload


def summarize_artifact(repo_root: Path, *, artifact: Path, task: str | None = None, model: str | None = None) -> dict[str, Any]:
    ctx = collect_summary_context(repo_root, task=task, artifact_path=artifact)
    prompt = build_prompt(task=task, kind="artifact", source_artifacts=ctx["source_artifacts"], context=ctx["context"])
    result = generate_summary(prompt=prompt, model=model)
    summary = result.get("output") or ""
    payload = write_summary_artifact(
        repo_root,
        task=task,
        prompt_kind="artifact",
        model=result.get("model") or (model or SUMMARY_MODEL),
        source_artifacts=ctx["source_artifacts"],
        summary=summary,
        status_text=result.get("status") or "failed",
        warnings=result.get("warnings") or [],
        input_char_count=len(prompt),
        output_char_count=len(summary),
    )
    payload["error"] = result.get("error")
    return payload


def summarize_session(repo_root: Path, *, task: str, model: str | None = None) -> dict[str, Any]:
    ctx = collect_summary_context(repo_root, task=task)
    prompt = build_prompt(task=task, kind="session", source_artifacts=ctx["source_artifacts"], context=ctx["context"])
    result = generate_summary(prompt=prompt, model=model)
    summary = result.get("output") or ""
    payload = write_summary_artifact(
        repo_root,
        task=task,
        prompt_kind="session",
        model=result.get("model") or (model or SUMMARY_MODEL),
        source_artifacts=ctx["source_artifacts"],
        summary=summary,
        status_text=result.get("status") or "failed",
        warnings=result.get("warnings") or [],
        input_char_count=len(prompt),
        output_char_count=len(summary),
    )
    payload["error"] = result.get("error")
    return payload


def compress_proof(repo_root: Path, *, proof: Path, model: str | None = None) -> dict[str, Any]:
    return summarize_artifact(repo_root, artifact=proof, model=model)


def draft_commit_summary(repo_root: Path, *, task: str, model: str | None = None) -> dict[str, Any]:
    return summarize_session(repo_root, task=task, model=model)


def collect_embedding_documents(repo_root: Path, *, task: str | None = None, max_bytes: int = 200000, limit: int | None = None) -> list[dict[str, Any]]:
    docs: list[dict[str, Any]] = []
    roots = [
        repo_root / "Docs" / "indexes",
        repo_root / "Docs" / "td" / "briefs",
        repo_root / "Docs" / "proofs",
        repo_root / ".build" / "rig" / "projections",
        repo_root / ".build" / "rig" / "monitor",
        repo_root / ".build" / "rig" / "results",
    ]
    for root in roots:
        if not root.exists():
            continue
        for path in sorted([p for p in root.rglob("*") if p.is_file()], key=lambda p: p.as_posix()):
            rel = str(path.relative_to(repo_root)).replace("\\", "/")
            if any(part in {".git", "__pycache__", ".pytest_cache", "DerivedData", "archives", "__MACOSX"} for part in path.parts):
                continue
            if any(part.startswith(".") for part in path.relative_to(repo_root).parts):
                continue
            if path.suffix in {".png", ".jpg", ".jpeg", ".gif", ".zip", ".pyc"}:
                continue
            if path.stat().st_size > max_bytes:
                continue
            if task and task not in rel and not rel.endswith("latest.json") and not rel.endswith("latest.md"):
                continue
            text = _read_text(path, max_bytes)
            docs.append({
                "id": rel,
                "path": rel,
                "title": path.name,
                "text_preview": _sanitize_text(text, 500),
                "text": text,
                "metadata": {"size_bytes": path.stat().st_size},
            })
            if limit is not None and len(docs) >= limit:
                return docs
    return docs


def _cosine(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    mag_a = sum(x * x for x in a) ** 0.5
    mag_b = sum(x * x for x in b) ** 0.5
    if not mag_a or not mag_b:
        return 0.0
    return dot / (mag_a * mag_b)


def _embed_texts(texts: list[str], model: str) -> tuple[list[list[float]], dict[str, Any]]:
    warnings: list[str] = []
    try:
        import mlx_embeddings  # type: ignore
    except Exception as exc:
        return [], {"status": "tool_missing", "error": str(exc), "warnings": ["mlx_embeddings_unavailable"]}
    for candidate in [
        ("embed", {}),
        ("EmbeddingModel", {}),
    ]:
        if hasattr(mlx_embeddings, candidate[0]):
            break
    try:
        if hasattr(mlx_embeddings, "embed"):
            vectors = mlx_embeddings.embed(texts, model=model)
            return [list(map(float, vec)) for vec in vectors], {"status": "generated", "warnings": warnings}
    except Exception as exc:
        return [], {"status": "model_load_failed", "error": str(exc), "warnings": warnings}
    try:
        if hasattr(mlx_embeddings, "EmbeddingModel"):
            emb = mlx_embeddings.EmbeddingModel(model)
            vectors = emb.encode(texts)
            return [list(map(float, vec)) for vec in vectors], {"status": "generated", "warnings": warnings}
    except Exception as exc:
        return [], {"status": "model_load_failed", "error": str(exc), "warnings": warnings}
    return [], {"status": "backend_unavailable", "error": "unsupported mlx_embeddings api", "warnings": warnings}


def build_embeddings(repo_root: Path, *, model: str | None = None, task: str | None = None, limit: int | None = None) -> dict[str, Any]:
    model = model or os.environ.get("RIG_MLX_EMBEDDING_MODEL", EMBEDDING_MODEL)
    docs = collect_embedding_documents(repo_root, task=task, limit=limit)
    texts = [doc["text"] for doc in docs]
    vectors, meta = _build_embeddings_backend(texts, model)
    out_dir = repo_root / ".build" / "rig" / "embeddings"
    out_dir.mkdir(parents=True, exist_ok=True)
    index = {
        "schema_version": "rig.embedding_index.v1",
        "backend": "mlx",
        "backend_package": meta.get("backend") or "mlx",
        "model": model,
        "status": "built" if vectors else meta.get("status"),
        "document_count": len(docs),
        "vector_count": len(vectors),
        "dimension": len(vectors[0]) if vectors else None,
        "source_artifacts": sorted({doc["path"] for doc in docs}),
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "warnings": meta.get("warnings") or [],
        "limitations": ["advisory only", "not validation", "not canonical"],
        "authoritative": False,
    }
    (out_dir / "index.json").write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with (out_dir / "vectors.jsonl").open("w", encoding="utf-8") as fh:
        for idx, (doc, vec) in enumerate(zip(docs, vectors)):
            fh.write(json.dumps({
                "id": doc["id"],
                "path": doc["path"],
                "title": doc["title"],
                "text_preview": doc["text_preview"],
                "vector": vec,
                "metadata": doc["metadata"],
            }, sort_keys=True) + "\n")
    return index


def smoke_embeddings(repo_root: Path, *, model: str | None = None) -> dict[str, Any]:
    model = model or os.environ.get("RIG_MLX_EMBEDDING_MODEL", EMBEDDING_MODEL)
    smoke = smoke_embed_mlx_embeddings(model, SMOKE_TEXTS)
    out_dir = repo_root / ".build" / "rig" / "embeddings"
    out_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": "rig.embedding_index.v1",
        "backend": "mlx",
        "backend_package": smoke.get("backend_package") or "mlx",
        "model": model,
        "status": smoke.get("status"),
        "authoritative": False,
        "document_count": len(SMOKE_TEXTS),
        "vector_count": smoke.get("vector_count"),
        "dimension": smoke.get("dimension"),
        "source_artifacts": [],
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "warnings": smoke.get("warnings") or [],
        "limitations": ["advisory only", "not validation", "not canonical"],
    }
    smoke_json = out_dir / "smoke.json"
    smoke_md = out_dir / "smoke.md"
    smoke_json.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    preview = smoke.get("first_vector_preview") or []
    smoke_md.write_text(
        "\n".join([
            "# Embedding Smoke",
            "",
            f"- Model: `{model}`",
            f"- Backend package: `{payload['backend_package']}`",
            f"- Status: `{payload['status']}`",
            f"- Vector count: `{payload['vector_count']}`",
            f"- Dimension: `{payload['dimension']}`",
            f"- First vector preview: `{preview}`",
        ]) + "\n",
        encoding="utf-8",
    )
    return payload


def query_embeddings(repo_root: Path, query: str, *, model: str | None = None, top_k: int = 10) -> dict[str, Any]:
    out_dir = repo_root / ".build" / "rig" / "embeddings"
    index_path = out_dir / "index.json"
    vectors_path = out_dir / "vectors.jsonl"
    if not index_path.exists() or not vectors_path.exists():
        return {"status": "missing_index", "reason": "missing_index", "results": []}
    index = json.loads(index_path.read_text(encoding="utf-8"))
    docs: list[tuple[str, list[float]]] = []
    for line in vectors_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        docs.append((item.get("path") or item.get("id") or "", [float(x) for x in item["vector"]]))
    qvecs, meta = _build_embeddings_backend([query], model or index.get("model") or EMBEDDING_MODEL)
    if not qvecs:
        return {"status": meta.get("status") or "failed", "warnings": meta.get("warnings") or [], "results": []}
    qvec = qvecs[0]
    scored = [{"path": path, "score": round(_cosine(qvec, vec), 6)} for path, vec in docs]
    scored.sort(key=lambda item: item["score"], reverse=True)
    results = scored[:top_k]
    payload = {"status": "passed", "query": query, "results": results, "model": index.get("model"), "backend": "mlx", "backend_package": index.get("backend_package")}
    (out_dir / "query-results.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    lines = ["# Embedding Query Results", "", f"- Query: `{query}`", f"- Model: `{index.get('model')}`", ""]
    for item in results:
        lines.append(f"- `{item['path']}` score `{item['score']}`")
    (out_dir / "query-results.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return payload
