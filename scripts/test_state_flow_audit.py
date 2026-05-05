#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import scripts.anigma_state_flow_audit as audit


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    assert audit.source_category_for_path("ExternalResearch/foo.swift") == "external_research"
    assert audit.source_category_for_path("anigma/Packages/AnigmaDaemonCore/Foo.swift") == "production"
    assert audit.include_in_scope(
        "ExternalResearch/foo.swift",
        "repo",
        None,
        None,
        False,
        False,
        [],
    )
    assert not audit.include_in_scope(
        "ExternalResearch/foo.swift",
        "target",
        "AnigmaDaemonCore",
        None,
        False,
        True,
        [("anigma/Packages/AnigmaDaemonCore", "AnigmaDaemonCore")],
    )
    assert audit.include_in_scope(
        "anigma/Packages/AnigmaDaemonCore/Foo.swift",
        "target",
        "AnigmaDaemonCore",
        None,
        False,
        True,
        [("anigma/Packages/AnigmaDaemonCore", "AnigmaDaemonCore")],
    )

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        swift = root / "Example.swift"
        write(
            swift,
            """
import Foundation
let goodConstant = "value"
let socketPath = "/tmp/anigma.sock"
static var sharedState = 1
typealias ArtifactID = String
typealias OpaqueAny = Any
actor ExampleActor { var count = 0 }
final class Worker {
    var cache = [String: String]()
    func run() {
        _ = ProcessInfo.processInfo.environment
        _ = CommandLine.arguments
        _ = FileManager.default.currentDirectoryPath
        _ = RuntimeAuthority.shared.workingDirectory
        _ = DaemonConfiguration(arguments: [], environment: [:])
    }
}
""".strip(),
        )

        recs, flows = audit.scan_swift(swift, swift.read_text(encoding="utf-8"), "AnigmaDaemonCore", "production")
        assert any(r.classification == "immutable_domain_constant" for r in recs)
        assert any(r.classification == "path_constant" for r in recs)
        assert any(r.classification == "mutable_global_state" for r in recs)
        assert any(r.classification == "typealias_semantic" for r in recs)
        assert any(r.classification == "typealias_obscuring" for r in recs)
        assert any(r.classification == "actor_owned_state" for r in recs)
        assert all(r.source_category == "production" for r in recs)
        assert any(f.flow_type == "ambient_process_read" for f in flows)
        assert any(f.flow_type == "runtime_path_source" for f in flows)
        assert any(f.flow_type == "configuration_injection" for f in flows)

        cpp = root / "Example.cpp"
        write(cpp, 'const char* socketPath = "/tmp/x"; extern "C" void foo();')
        recs2, flows2 = audit.scan_cpp_like(cpp, cpp.read_text(encoding="utf-8"), "AnigmaDaemonCore", "production")
        assert any(r.classification == "path_constant" for r in recs2)
        assert all(r.source_category == "production" for r in recs2)
        assert any(f.flow_type == "string_bridge" for f in flows2)

        result = audit.run_audit("target", "AnigmaDaemonCore", "anigmad", True, False)
        assert result["state_record_count"] > 0
        assert result["flow_record_count"] > 0
        assert result["cohesion_record_count"] > 0
        assert "immutable_domain_constant" in result["counts_by_classification"]
        assert "ambient_state_bypass" in result["counts_by_risk_label"] or "bypass" in result["counts_by_risk_label"]
        assert "production" in result["counts_by_source_category"]

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
