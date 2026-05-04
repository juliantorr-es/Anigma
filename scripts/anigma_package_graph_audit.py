#!/usr/bin/env python3
"""
Anigma Package Graph Audit Script

Generates normalized JSON package/module graphs from SwiftPM outputs,
cross-references them against Anigma tier/dependency doctrine, and
reports dependency violations in machine-readable JSON plus a human-readable
proof summary.

Usage:
    python3 Scripts/anigma_package_graph_audit.py [snapshot|violations|suggest-classifications|list-targets|explain-target|explain-edge|why-builds|alignment-matrix]

Quick Commands:
    python3 Scripts/anigma_package_graph_audit.py                    # Full audit with all outputs
    python3 Scripts/anigma_package_graph_audit.py snapshot           # Capture SwiftPM JSON snapshots
    python3 Scripts/anigma_package_graph_audit.py violations       # Check violations only
    python3 Scripts/anigma_package_graph_audit.py suggest-classifications  # Suggest tier classifications
    python3 Scripts/anigma_package_graph_audit.py list-targets        # List all targets
    python3 Scripts/anigma_package_graph_audit.py explain-target TargetName    # Explain a target
    python3 Scripts/anigma_package_graph_audit.py explain-edge From Target     # Explain a dependency edge
    python3 Scripts/anigma_package_graph_audit.py why-builds TargetName        # Show why a target builds
    python3 Scripts/anigma_package_graph_audit.py alignment-matrix    # Generate alignment diagnostic matrix

Options:
    --fail-on-violation   Exit nonzero if error-severity violations found
    --rules RULES_FILE     Path to rules YAML file (default: Docs/governance/package-graph-rules.yaml)
    --output-dir DIR       Output directory (default: .build/anigma-graph/)
    --help                 Show this help message

Severity Behavior:
    --fail-on-violation exits nonzero ONLY on error-severity violations.
    Warning-severity findings (like no_unclassified_target) are reported but NON-BLOCKING.
    This allows incremental adoption of classification coverage.

Outputs:
    .build/anigma-graph/swiftpm-package-description.json      # Raw describe output
    .build/anigma-graph/swiftpm-package-dependencies.json      # Raw dependencies output
    .build/anigma-graph/anigma-target-graph.json               # Normalized target graph
    .build/anigma-graph/anigma-product-graph.json              # Normalized product graph
    .build/anigma-graph/anigma-external-package-graph.json     # Normalized external graph
    .build/anigma-graph/anigma-dependency-violations.json      # Violation report
    .build/anigma-graph/anigma-unclassified-targets.json      # Unclassified targets (if any)
    .build/anigma-graph/package-graph-classification-suggestions.yaml  # Suggested classifications
    .build/anigma-graph/anigma-package-graph-audit.md          # Human-readable summary
"""

import argparse
import csv
import fnmatch
import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

# Schema versions
TARGET_GRAPH_SCHEMA = "anigma.target_graph.v1"
PRODUCT_GRAPH_SCHEMA = "anigma.product_graph.v1"
EXTERNAL_GRAPH_SCHEMA = "anigma.external_package_graph.v1"
VIOLATION_SCHEMA = "anigma.package_graph_violations.v1"
AUDIT_SCHEMA = "anigma.package_graph_audit.v1"
UNCLASSIFIED_SCHEMA = "anigma.unclassified_targets.v1"
SUGGESTION_SCHEMA = "anigma.classification_suggestions.v1"
ALIGNMENT_MATRIX_SCHEMA = "anigma.alignment_diagnostic_matrix.v1"

# Default output directory
DEFAULT_OUTPUT_DIR = ".build/anigma-graph"

# Default rules file
DEFAULT_RULES_FILE = "Docs/governance/package-graph-rules.yaml"
DEFAULT_ALIGNMENT_RULES_FILE = "Docs/governance/alignment-diagnostic-rules.yaml"


class AuditError(Exception):
    """Error during audit execution."""
    pass


def ensure_output_dir(output_dir):
    """Ensure output directory exists."""
    Path(output_dir).mkdir(parents=True, exist_ok=True)


def run_command(cmd, cwd=None):
    """Run a shell command and return stdout as JSON if possible."""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise AuditError(f"Command failed: {' '.join(cmd)}\nstdout: {e.stdout}\nstderr: {e.stderr}")


def load_json_file(path):
    """Load and parse a JSON file."""
    with open(path, 'r') as f:
        return json.load(f)


def write_json_file(path, data):
    """Write JSON file with deterministic formatting."""
    with open(path, 'w') as f:
        json.dump(data, f, sort_keys=True, indent=2)


def normalize_path(path, repo_root):
    """Normalize absolute paths to repo-relative paths."""
    if path is None:
        return None
    try:
        full_path = Path(path).resolve()
        repo_path = Path(repo_root).resolve()
        if full_path.is_relative_to(repo_path):
            return str(full_path.relative_to(repo_path))
        return str(full_path)
    except (ValueError, TypeError):
        return path


def get_repo_root():
    """Get the repository root directory."""
    # Look for Package.swift in parent directories or in anigma subdirectory
    current = Path.cwd()
    while current.exists():
        if (current / "Package.swift").exists():
            return str(current)
        if (current / "anigma" / "Package.swift").exists():
            return str(current)
        current = current.parent
    return str(Path.cwd())


def get_package_root():
    """Get the directory containing Package.swift for SwiftPM commands."""
    repo_root = get_repo_root()
    # If repo_root has anigma/Package.swift, return the anigma directory
    if (Path(repo_root) / "anigma" / "Package.swift").exists():
        return str(Path(repo_root) / "anigma")
    return repo_root


def parse_swiftpm_describe(raw_json):
    """Parse SwiftPM describe output into normalized structure."""
    data = json.loads(raw_json)
    
    targets = []
    target_map = {}  # name -> target info
    
    if "targets" not in data:
        return {"targets": [], "products": []}
    
    for target in data["targets"]:
        target_name = target.get("name", "")
        target_type = target.get("type", "regular")
        target_path = target.get("path", None)
        # SwiftPM describe uses "target_dependencies" for target dependencies
        dependencies = target.get("dependencies", []) or target.get("target_dependencies", [])
        
        # Normalize dependencies
        norm_deps = []
        for dep in dependencies:
            if isinstance(dep, str):
                norm_deps.append({"name": dep, "kind": "target"})
            elif isinstance(dep, dict):
                norm_deps.append({
                    "name": dep.get("byName", dep.get("name", "")),
                    "kind": dep.get("product", "target")
                })
        
        target_info = {
            "name": target_name,
            "type": target_type,
            "path": normalize_path(target_path, get_repo_root()),
            "dependencies": norm_deps
        }
        
        targets.append(target_info)
        target_map[target_name] = target_info
    
    # Extract products
    products = []
    if "products" in data:
        for product in data["products"]:
            product_name = product.get("name", "")
            product_type = product.get("type", "library")
            targets_in_product = product.get("targets", [])
            
            products.append({
                "name": product_name,
                "type": product_type,
                "targets": targets_in_product
            })
    
    return {
        "schema": "swiftpm.package_description.v1",
        "source": "swift package describe --type json",
        "targets": targets,
        "products": products
    }


def parse_swiftpm_dependencies(raw_json):
    """Parse SwiftPM show-dependencies output into normalized structure."""
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError:
        data = {}
    
    if not data:
        return {"schema": "swiftpm.package_dependencies.v1", "packages": []}
    
    packages = []
    if "dependencies" in data:
        for dep in data["dependencies"]:
            pkg = {
                "identity": dep.get("identity", ""),
                "name": dep.get("name", ""),
                "path": dep.get("path"),
                "url": dep.get("url"),
                "version": dep.get("version", {}).get("pretty") if isinstance(dep.get("version"), dict) else dep.get("version", ""),
                "state": dep.get("state", "resolved"),
                "dependencies": dep.get("dependencies", [])
            }
            packages.append(pkg)
    
    return {
        "schema": "swiftpm.package_dependencies.v1",
        "source": "swift package show-dependencies --format json",
        "packages": packages
    }


def load_rules(rules_path):
    """Load tier classification and rules from YAML file."""
    if not HAS_YAML:
        return {"tiers": {}, "rules": [], "allowlist": {"edges": [], "targets": []}}
    
    rules_path = Path(rules_path)
    if not rules_path.exists():
        return {"tiers": {}, "rules": [], "allowlist": {"edges": [], "targets": []}}
    
    with open(rules_path, 'r') as f:
        return yaml.safe_load(f) or {"tiers": {}, "rules": [], "allowlist": {"edges": [], "targets": []}}


def classify_target(target_name, rules):
    """Classify a target by tier based on rules configuration."""
    for tier_name, tier_info in rules.get("tiers", {}).items():
        if target_name in tier_info.get("targets", []):
            return {"tier": tier_name, "role": tier_info.get("description", tier_name)}
    return {"tier": "unclassified", "role": "unknown"}


def classify_target_with_heuristics(target_name, target_type, target_path, rules):
    """Classify target using heuristics from rules configuration."""
    heuristic_config = rules.get("suggestion_heuristics", {})
    
    # First check explicit tier classification
    explicit = classify_target(target_name, rules)
    if explicit.get("tier") != "unclassified":
        return explicit
    
    # Check name patterns
    for pattern_info in heuristic_config.get("name_patterns", []):
        pattern = pattern_info.get("pattern", "")
        if fnmatch.fnmatch(target_name, pattern):
            return {
                "tier": pattern_info.get("suggested_tier", "unclassified"),
                "role": pattern_info.get("suggested_role", "unknown"),
                "confidence": pattern_info.get("confidence", "low")
            }
    
    # Check path patterns
    if target_path:
        for pattern_info in heuristic_config.get("path_patterns", []):
            pattern = pattern_info.get("pattern", "")
            if fnmatch.fnmatch(target_path, pattern):
                return {
                    "tier": pattern_info.get("suggested_tier", "unclassified"),
                    "role": pattern_info.get("suggested_role", "unknown"),
                    "confidence": pattern_info.get("confidence", "low")
                }
    
    # Check type-based detection
    for detection_info in heuristic_config.get("test_detection", []):
        if target_type == detection_info.get("target_type"):
            return {
                "tier": "unclassified",
                "role": detection_info.get("suggested_role", "unknown"),
                "confidence": detection_info.get("confidence", "absolute")
            }
    
    for detection_info in heuristic_config.get("plugin_detection", []):
        if target_type == detection_info.get("target_type"):
            return {
                "tier": "unclassified",
                "role": detection_info.get("suggested_role", "unknown"),
                "confidence": detection_info.get("confidence", "absolute")
            }
    
    return {"tier": "unclassified", "role": "unknown", "confidence": "none"}


def detect_cycles(graph):
    """Detect cycles in the dependency graph using DFS."""
    cycles = []
    visited = set()
    rec_stack = set()
    
    def dfs(node, path):
        visited.add(node)
        rec_stack.add(node)
        path.append(node)
        
        for neighbor in graph.get(node, []):
            if neighbor not in visited:
                dfs(neighbor, path.copy())
            elif neighbor in rec_stack:
                # Cycle detected
                cycle_path = path[path.index(neighbor):] + [neighbor]
                cycles.append(cycle_path)
        
        rec_stack.discard(node)
        path.pop()
    
    for node in graph:
        if node not in visited:
            dfs(node, [])
    
    return cycles


def build_target_graph(describe_data, rules):
    """Build normalized target graph with tier classification."""
    target_map = {t["name"]: t for t in describe_data.get("targets", [])}
    
    targets = []
    edges = []
    
    for target_info in describe_data.get("targets", []):
        target_name = target_info["name"]
        classification = classify_target(target_name, rules)
        tier = classification.get("tier", "unclassified")
        role = classification.get("role", "unknown")
        
        # Build normalized target
        norm_target = {
            "name": target_name,
            "type": target_info.get("type", "regular"),
            "path": target_info.get("path"),
            "tier": tier,
            "role": role,
            "dependencies": []
        }
        
        # Process dependencies
        for dep in target_info.get("dependencies", []):
            dep_name = dep.get("name", "")
            dep_kind = dep.get("kind", "target")
            
            dep_classification = classify_target(dep_name, rules)
            dep_tier = dep_classification.get("tier", "unclassified")
            
            norm_dep = {
                "name": dep_name,
                "kind": dep_kind,
                "tier": dep_tier
            }
            
            norm_target["dependencies"].append(norm_dep)
            
            # Add edge
            edges.append({
                "from": target_name,
                "to": dep_name,
                "kind": "target"
            })
        
        targets.append(norm_target)
    
    return {
        "schema": TARGET_GRAPH_SCHEMA,
        "source": "swift package describe --type json",
        "targets": targets,
        "edges": edges
    }


def build_product_graph(describe_data):
    """Build normalized product graph."""
    products = []
    
    for product_info in describe_data.get("products", []):
        product = {
            "name": product_info.get("name", ""),
            "type": product_info.get("type", "library"),
            "targets": product_info.get("targets", [])
        }
        products.append(product)
    
    return {
        "schema": PRODUCT_GRAPH_SCHEMA,
        "source": "swift package describe --type json",
        "products": products
    }


def build_external_graph(dependencies_data):
    """Build normalized external package graph."""
    packages = []
    edges = []
    
    for pkg in dependencies_data.get("packages", []):
        pkg_name = pkg.get("name", pkg.get("identity", ""))
        
        normalized_pkg = {
            "identity": pkg.get("identity", ""),
            "name": pkg_name,
            "path": pkg.get("path"),
            "url": pkg.get("url"),
            "version": pkg.get("version", ""),
            "state": pkg.get("state", "unknown")
        }
        
        packages.append(normalized_pkg)
        
        # Add edges for package dependencies
        for dep in pkg.get("dependencies", []):
            dep_name = dep.get("name", "") if isinstance(dep, dict) else str(dep)
            edges.append({
                "from": pkg_name,
                "to": dep_name,
                "kind": "external"
            })
    
    return {
        "schema": EXTERNAL_GRAPH_SCHEMA,
        "source": "swift package show-dependencies --format json",
        "packages": packages,
        "edges": edges
    }


def check_violation_rules(target_graph, rules):
    """Check dependency violations based on rules."""
    violations = []
    
    tier_order = {"tier1": 1, "tier2": 2, "tier3": 3}
    
    for target_info in target_graph.get("targets", []):
        target_name = target_info["name"]
        from_tier = target_info.get("tier", "unclassified")
        
        for dep in target_info.get("dependencies", []):
            dep_name = dep.get("name", "")
            to_tier = dep.get("tier", "unclassified")
            
            # Skip external dependencies for tier checks
            if dep.get("kind") == "product":
                continue
            
            # Check rule: no_upward_tier_dependency
            # Lower tiers (lower numbers) must not depend on higher tiers (higher numbers)
            # Allowed: Tier 3 -> Tier 2 -> Tier 1 (downward: higher number to lower number)
            # Violates: Tier 1 -> Tier 2 or Tier 1 -> Tier 3 (upward: lower number to higher number)
            if from_tier in tier_order and to_tier in tier_order:
                if tier_order[from_tier] < tier_order[to_tier]:
                    # Upward dependency violation (lower tier depending on higher tier)
                    violations.append({
                        "rule_id": "no_upward_tier_dependency",
                        "severity": "error",
                        "from": target_name,
                        "to": dep_name,
                        "fromTier": from_tier,
                        "toTier": to_tier,
                        "message": f"Tier {from_tier} target '{target_name}' depends on Tier {to_tier} target '{dep_name}'. Dependencies must flow downward (higher tier numbers to lower tier numbers).",
                        "evidence": {
                            "source": "swift package describe --type json",
                            "path": f"targets[{target_name}].dependencies"
                        }
                    })
                else:
                    # tier_order[from_tier] >= tier_order[to_tier]
                    # Same tier or downward flow is fine
                    pass
            
            # Check rule: no_contract_to_runtime_dependency
            # This is a more specific version of no_upward_tier_dependency for clarity
            if from_tier == "tier1" and to_tier in ["tier2", "tier3"]:
                violations.append({
                    "rule_id": "no_contract_to_runtime_dependency",
                    "severity": "error",
                    "from": target_name,
                    "to": dep_name,
                    "fromTier": from_tier,
                    "toTier": to_tier,
                    "message": f"Tier 1 contract target '{target_name}' depends on Tier {to_tier} runtime target '{dep_name}'. Contracts must not depend on runtime/execution/app layers.",
                    "evidence": {
                        "source": "swift package describe --type json",
                        "path": f"targets[{target_name}].dependencies"
                    }
                })
        
        # Check rule: no_unclassified_target
        if target_info.get("tier") == "unclassified":
            violations.append({
                "rule_id": "no_unclassified_target",
                "severity": "warning",
                "from": target_name,
                "to": None,
                "fromTier": "unclassified",
                "toTier": None,
                "message": f"Target '{target_name}' is not classified in any tier. Every Anigma target should be classified by tier/role for doctrine enforcement.",
                "evidence": {
                    "source": "package-graph-rules.yaml",
                    "path": "tiers"
                }
            })
    
    # Check for cycles in the graph
    graph = {}
    for target_info in target_graph.get("targets", []):
        target_name = target_info["name"]
        graph[target_name] = [dep["name"] for dep in target_info.get("dependencies", [])]
    
    cycles = detect_cycles(graph)
    for cycle in cycles:
        for i in range(len(cycle) - 1):
            violations.append({
                "rule_id": "no_same_tier_cycle",
                "severity": "error",
                "from": cycle[i],
                "to": cycle[i + 1],
                "fromTier": None,
                "toTier": None,
                "message": f"Cycle detected: {' -> '.join(cycle)}. Same-tier targets must not create dependency cycles.",
                "evidence": {
                    "source": "swift package describe --type json",
                    "path": "targets[].dependencies"
                }
            })
    
    return violations


def filter_allowlisted(violations, allowlist):
    """Filter out allowlisted violations."""
    if not allowlist:
        return violations
    
    filtered = []
    allowlisted_edges = allowlist.get("edges", [])
    
    for v in violations:
        edge_str = f"{v.get('from')} -> {v.get('to')}"
        if edge_str in allowlisted_edges:
            continue
        filtered.append(v)
    
    return filtered


def compute_classification_coverage(target_graph):
    """Compute classification coverage metrics."""
    total = len(target_graph.get("targets", []))
    if total == 0:
        return {
            "total": 0,
            "classified": 0,
            "unclassified": 0,
            "coverage": 1.0,
            "unclassified_targets": []
        }
    
    classified = 0
    unclassified = 0
    unclassified_list = []
    
    for target in target_graph.get("targets", []):
        if target.get("tier") == "unclassified":
            unclassified += 1
            unclassified_list.append(target.get("name", ""))
        else:
            classified += 1
    
    coverage = classified / total if total > 0 else 1.0
    
    return {
        "total": total,
        "classified": classified,
        "unclassified": unclassified,
        "coverage": round(coverage, 4),
        "unclassified_targets": sorted(unclassified_list)
    }


def generate_unclassified_report(target_graph, output_dir):
    """Generate unclassified targets report."""
    coverage = compute_classification_coverage(target_graph)
    
    unclassified_targets = []
    for target in target_graph.get("targets", []):
        if target.get("tier") == "unclassified":
            unclassified_targets.append({
                "name": target.get("name", ""),
                "type": target.get("type", "unknown"),
                "path": target.get("path"),
                "dependencies": [d.get("name") for d in target.get("dependencies", [])]
            })
    
    report = {
        "schema": UNCLASSIFIED_SCHEMA,
        "generatedBy": "Scripts/anigma_package_graph_audit.py",
        "summary": {
            "totalTargets": coverage["total"],
            "classifiedCount": coverage["classified"],
            "unclassifiedCount": coverage["unclassified"],
            "classificationCoverage": coverage["coverage"]
        },
        "unclassifiedTargets": sorted(unclassified_targets, key=lambda x: x.get("name", ""))
    }
    
    write_json_file(
        os.path.join(output_dir, "anigma-unclassified-targets.json"),
        report
    )
    
    return report


def generate_classification_suggestions(target_graph, rules):
    """Generate classification suggestions using heuristics."""
    suggestions = []
    heuristic_config = rules.get("suggestion_heuristics", {})
    
    for target in target_graph.get("targets", []):
        target_name = target.get("name", "")
        target_type = target.get("type", "regular")
        target_path = target.get("path", "")
        
        # Skip already classified targets
        if target.get("tier") != "unclassified":
            continue
        
        suggestion = classify_target_with_heuristics(target_name, target_type, target_path, rules)
        
        if suggestion.get("tier") != "unclassified" or suggestion.get("role") != "unknown":
            suggestions.append({
                "target": target_name,
                "currentTier": "unclassified",
                "currentRole": "unknown",
                "suggestedTier": suggestion.get("tier", "unclassified"),
                "suggestedRole": suggestion.get("role", "unknown"),
                "confidence": suggestion.get("confidence", "low"),
                "reason": f"Matched heuristic pattern for {target_name}"
            })
    
    return {
        "schema": SUGGESTION_SCHEMA,
        "generatedBy": "Scripts/anigma_package_graph_audit.py",
        "suggestionCount": len(suggestions),
        "suggestions": sorted(suggestions, key=lambda x: x.get("target", ""))
    }


def get_reachable_from(target_name, target_graph):
    """Get all targets reachable from a given target (BFS)."""
    graph = {}
    for target in target_graph.get("targets", []):
        graph[target["name"]] = [d["name"] for d in target.get("dependencies", [])]
    
    visited = set()
    queue = [target_name]
    reachable = set()
    
    while queue:
        node = queue.pop(0)
        if node in visited:
            continue
        visited.add(node)
        if node != target_name:
            reachable.add(node)
        for neighbor in graph.get(node, []):
            if neighbor not in visited:
                queue.append(neighbor)
    
    return sorted(reachable)


def get_why_builds(target_name, target_graph):
    """Get the reverse dependency chain explaining why a target builds."""
    graph = {}
    reverse_graph = {}
    
    for target in target_graph.get("targets", []):
        name = target["name"]
        deps = [d["name"] for d in target.get("dependencies", [])]
        graph[name] = deps
        for dep in deps:
            if dep not in reverse_graph:
                reverse_graph[dep] = []
            reverse_graph[dep].append(name)
    
    # BFS from target to find all that depend on it
    dependents = set()
    queue = [target_name]
    visited = set([target_name])
    
    while queue:
        node = queue.pop(0)
        for parent in reverse_graph.get(node, []):
            if parent not in visited:
                visited.add(parent)
                dependents.add(parent)
                queue.append(parent)
    
    return {
        "target": target_name,
        "directDependents": sorted(reverse_graph.get(target_name, [])),
        "allDependents": sorted(dependents),
        "reachableFrom": get_reachable_from(target_name, target_graph)
    }


def generate_markdown_summary(target_graph, product_graph, external_graph, violations, rules, source_commands, output_dir):
    """Generate human-readable markdown summary."""
    tier_counts = {}
    for target in target_graph.get("targets", []):
        tier = target.get("tier", "unclassified")
        tier_counts[tier] = tier_counts.get(tier, 0) + 1
    
    coverage = compute_classification_coverage(target_graph)
    
    error_count = sum(1 for v in violations if v.get("severity") == "error")
    warning_count = sum(1 for v in violations if v.get("severity") == "warning")
    
    md = []
    md.append("# Anigma Package Graph Audit")
    md.append("")
    md.append("## Summary")
    md.append("")
    md.append(f"- **Schema**: {AUDIT_SCHEMA}")
    md.append(f"- **Target Count**: {len(target_graph.get('targets', []))}")
    md.append(f"- **Product Count**: {len(product_graph.get('products', []))}")
    md.append(f"- **External Package Count**: {len(external_graph.get('packages', []))}")
    md.append(f"- **Violation Count**: {len(violations)}")
    md.append(f"  - Errors: {error_count}")
    md.append(f"  - Warnings: {warning_count}")
    md.append(f"- **Classification Coverage**: {coverage['coverage'] * 100:.1f}% ({coverage['classified']} classified, {coverage['unclassified']} unclassified)")
    md.append("")
    
    md.append("## Source Commands")
    md.append("")
    for cmd in source_commands:
        md.append(f"- `{cmd}`")
    md.append("")
    
    md.append("## Target Classification")
    md.append("")
    for tier, count in sorted(tier_counts.items()):
        md.append(f"- **{tier}**: {count} targets")
    md.append("")
    
    md.append("## Classification Coverage")
    md.append("")
    md.append(f"- **Coverage**: {coverage['coverage'] * 100:.1f}%")
    md.append(f"- **Total Targets**: {coverage['total']}")
    md.append(f"- **Classified**: {coverage['classified']}")
    md.append(f"- **Unclassified**: {coverage['unclassified']}")
    if coverage['unclassified'] > 0:
        md.append(f"- **Unclassified List**: {', '.join(coverage['unclassified_targets'][:10])}" + ("..." if len(coverage['unclassified_targets']) > 10 else ""))
    md.append("")
    
    if violations:
        md.append("## Dependency Violations")
        md.append("")
        
        for v in violations:
            severity_emoji = "❌" if v.get("severity") == "error" else "⚠️"
            md.append(f"### {severity_emoji} {v.get('rule_id', 'unknown')}")
            md.append("")
            md.append(f"- **Severity**: {v.get('severity', 'unknown')}")
            md.append(f"- **From**: {v.get('from', 'unknown')}")
            md.append(f"- **To**: {v.get('to', 'unknown')}")
            if v.get('fromTier'):
                md.append(f"- **From Tier**: {v.get('fromTier')}")
            if v.get('toTier'):
                md.append(f"- **To Tier**: {v.get('toTier')}")
            md.append(f"- **Message**: {v.get('message', '')}")
            md.append("")
    else:
        md.append("## Dependency Violations")
        md.append("")
        md.append("✅ No violations detected.")
        md.append("")
    
    md.append("## Output Files")
    md.append("")
    md.append(f"- `{output_dir}/swiftpm-package-description.json`")
    md.append(f"- `{output_dir}/swiftpm-package-dependencies.json`")
    md.append(f"- `{output_dir}/anigma-target-graph.json`")
    md.append(f"- `{output_dir}/anigma-product-graph.json`")
    md.append(f"- `{output_dir}/anigma-external-package-graph.json`")
    md.append(f"- `{output_dir}/anigma-dependency-violations.json`")
    md.append(f"- `{output_dir}/anigma-unclassified-targets.json`")
    md.append(f"- `{output_dir}/package-graph-classification-suggestions.yaml`")
    md.append(f"- `{output_dir}/anigma-package-graph-audit.md` (this file)")
    md.append("")
    
    md.append("## Severity Behavior")
    md.append("")
    md.append("- `--fail-on-violation` exits nonzero ONLY on error-severity violations.")
    md.append("- Warning-severity findings (like `no_unclassified_target`) are reported but NON-BLOCKING.")
    md.append("- This allows incremental adoption of classification coverage.")
    md.append("")
    
    return "\n".join(md)


def cmd_snapshot(args):
    """Capture SwiftPM JSON snapshots."""
    output_dir = args.output_dir
    ensure_output_dir(output_dir)
    
    source_commands = []
    
    # Get describe output
    describe_cmd = ["swift", "package", "describe", "--type", "json"]
    source_commands.append(" ".join(describe_cmd))
    describe_raw = run_command(describe_cmd, cwd=get_package_root())
    write_json_file(os.path.join(output_dir, "swiftpm-package-description.json"), json.loads(describe_raw))
    
    # Get dependencies output
    deps_cmd = ["swift", "package", "show-dependencies", "--format", "json"]
    source_commands.append(" ".join(deps_cmd))
    try:
        deps_raw = run_command(deps_cmd, cwd=get_package_root())
        write_json_file(os.path.join(output_dir, "swiftpm-package-dependencies.json"), json.loads(deps_raw))
    except AuditError as e:
        print(f"Warning: Could not get dependencies: {e}", file=sys.stderr)
    
    print(f"Snapshots saved to {output_dir}/")
    for cmd in source_commands:
        print(f"  - {cmd}")


def cmd_violations(args):
    """Check violations only."""
    output_dir = args.output_dir
    ensure_output_dir(output_dir)
    
    # Load existing snapshots if available
    describe_file = os.path.join(output_dir, "swiftpm-package-description.json")
    deps_file = os.path.join(output_dir, "swiftpm-package-dependencies.json")
    
    if os.path.exists(describe_file):
        describe_raw = load_json_file(describe_file)
        describe_data = parse_swiftpm_describe(json.dumps(describe_raw))
    else:
        describe_cmd = ["swift", "package", "describe", "--type", "json"]
        describe_raw = run_command(describe_cmd, cwd=get_package_root())
        describe_data = parse_swiftpm_describe(describe_raw)
    
    if os.path.exists(deps_file):
        deps_raw = load_json_file(deps_file)
        deps_data = parse_swiftpm_dependencies(json.dumps(deps_raw))
    else:
        try:
            deps_cmd = ["swift", "package", "show-dependencies", "--format", "json"]
            deps_raw = run_command(deps_cmd, cwd=get_package_root())
            deps_data = parse_swiftpm_dependencies(deps_raw)
        except AuditError:
            deps_data = {"schema": "swiftpm.package_dependencies.v1", "packages": []}
    
    rules = load_rules(args.rules)
    target_graph = build_target_graph(describe_data, rules)
    violations = check_violation_rules(target_graph, rules)
    violations = filter_allowlisted(violations, rules.get("allowlist", {}))
    
    error_count = sum(1 for v in violations if v.get("severity") == "error")
    warning_count = sum(1 for v in violations if v.get("severity") == "warning")
    
    violations_output = {
        "schema": VIOLATION_SCHEMA,
        "generatedBy": "Scripts/anigma_package_graph_audit.py",
        "summary": {
            "targetCount": len(describe_data.get("targets", [])),
            "violationCount": len(violations),
            "errorCount": error_count,
            "warningCount": warning_count
        },
        "violations": violations
    }
    
    write_json_file(os.path.join(output_dir, "anigma-dependency-violations.json"), violations_output)
    
    print(f"Violations check complete.")
    print(f"  Errors: {error_count}")
    print(f"  Warnings: {warning_count}")
    
    if args.fail_on_violation and error_count > 0:
        sys.exit(1)


def cmd_suggest_classifications(args):
    """Suggest tier classifications for unclassified targets."""
    output_dir = args.output_dir
    ensure_output_dir(output_dir)
    
    describe_cmd = ["swift", "package", "describe", "--type", "json"]
    describe_raw = run_command(describe_cmd, cwd=get_package_root())
    describe_data = parse_swiftpm_describe(describe_raw)
    
    rules = load_rules(args.rules)
    target_graph = build_target_graph(describe_data, rules)
    suggestions = generate_classification_suggestions(target_graph, rules)
    
    # Write YAML output
    if HAS_YAML:
        yaml_path = os.path.join(output_dir, "package-graph-classification-suggestions.yaml")
        with open(yaml_path, 'w') as f:
            yaml.dump(suggestions, f, default_flow_style=False, sort_keys=False)
    
    # Also write JSON
    write_json_file(
        os.path.join(output_dir, "anigma-classification-suggestions.json"),
        suggestions
    )
    
    print(f"Classification suggestions generated.")
    print(f"  Suggestions: {suggestions.get('suggestionCount', 0)}")
    print(f"  Output: {output_dir}/package-graph-classification-suggestions.yaml")


def cmd_list_targets(args):
    """List all targets."""
    describe_cmd = ["swift", "package", "describe", "--type", "json"]
    describe_raw = run_command(describe_cmd, cwd=get_package_root())
    describe_data = parse_swiftpm_describe(describe_raw)
    
    rules = load_rules(args.rules)
    target_graph = build_target_graph(describe_data, rules)
    
    for target in sorted(target_graph.get("targets", []), key=lambda x: x.get("name", "")):
        name = target.get("name", "")
        tier = target.get("tier", "unclassified")
        role = target.get("role", "unknown")
        type_ = target.get("type", "regular")
        deps = [d.get("name") for d in target.get("dependencies", [])]
        print(f"{name} [{tier}] ({role}) [{type_}] -> {', '.join(deps) if deps else 'no deps'}")


def cmd_explain_target(args):
    """Explain a target's dependencies."""
    describe_cmd = ["swift", "package", "describe", "--type", "json"]
    describe_raw = run_command(describe_cmd, cwd=get_package_root())
    describe_data = parse_swiftpm_describe(describe_raw)
    
    rules = load_rules(args.rules)
    target_graph = build_target_graph(describe_data, rules)
    
    target_name = args.target_name
    
    # Find the target
    for target in target_graph.get("targets", []):
        if target.get("name") == target_name:
            print(f"Target: {target_name}")
            print(f"  Tier: {target.get('tier', 'unclassified')}")
            print(f"  Role: {target.get('role', 'unknown')}")
            print(f"  Type: {target.get('type', 'regular')}")
            print(f"  Path: {target.get('path', 'N/A')}")
            print(f"  Dependencies:")
            for dep in target.get("dependencies", []):
                dep_tier = dep.get("tier", "unclassified")
                print(f"    - {dep.get('name', 'unknown')} [{dep_tier}]")
            
            reachable = get_reachable_from(target_name, target_graph)
            print(f"  Reachable from: {len(reachable)} targets")
            if reachable:
                print(f"    " + ", ".join(reachable[:10]) + ("..." if len(reachable) > 10 else ""))
            return
    
    print(f"Target '{target_name}' not found.")
    sys.exit(1)


def cmd_explain_edge(args):
    """Explain a dependency edge from one target to another."""
    describe_cmd = ["swift", "package", "describe", "--type", "json"]
    describe_raw = run_command(describe_cmd, cwd=get_package_root())
    describe_data = parse_swiftpm_describe(describe_raw)
    
    rules = load_rules(args.rules)
    target_graph = build_target_graph(describe_data, rules)
    
    from_target = args.from_target
    to_target = args.to_target
    
    # Check if edge exists
    for target in target_graph.get("targets", []):
        if target.get("name") == from_target:
            for dep in target.get("dependencies", []):
                if dep.get("name") == to_target:
                    from_tier = target.get("tier", "unclassified")
                    to_tier = dep.get("tier", "unclassified")
                    print(f"Edge: {from_target} -> {to_target}")
                    print(f"  From Tier: {from_tier}")
                    print(f"  To Tier: {to_tier}")
                    
                    # Check if this violates tier ordering
                    # Lower tiers (lower numbers) must not depend on higher tiers (higher numbers)
                    tier_order = {"tier1": 1, "tier2": 2, "tier3": 3}
                    if from_tier in tier_order and to_tier in tier_order:
                        if tier_order[from_tier] < tier_order[to_tier]:
                            print(f"  ❌ VIOLATION: Upward tier dependency (Tier {from_tier} -> Tier {to_tier})")
                        else:
                            print(f"  ✅ OK: Downward or same-tier dependency")
                    return
    
    print(f"Edge '{from_target} -> {to_target}' not found.")
    sys.exit(1)


def cmd_why_builds(args):
    """Show why a target builds (reverse dependency analysis)."""
    describe_cmd = ["swift", "package", "describe", "--type", "json"]
    describe_raw = run_command(describe_cmd, cwd=get_package_root())
    describe_data = parse_swiftpm_describe(describe_raw)
    
    rules = load_rules(args.rules)
    target_graph = build_target_graph(describe_data, rules)
    
    target_name = args.target_name
    result = get_why_builds(target_name, target_graph)
    
    print(f"Why '{target_name}' builds:")
    print(f"  Direct dependents: {len(result['directDependents'])}")
    if result['directDependents']:
        for dep in result['directDependents']:
            print(f"    - {dep}")
    print(f"  All dependents: {len(result['allDependents'])}")
    if result['allDependents']:
        for dep in result['allDependents'][:20]:
            print(f"    - {dep}")
        if len(result['allDependents']) > 20:
            print(f"    ... and {len(result['allDependents']) - 20} more")
    
    print(f"  Reachable from '{target_name}': {len(result['reachableFrom'])}")
    if result['reachableFrom']:
        for dep in result['reachableFrom'][:20]:
            print(f"    - {dep}")
        if len(result['reachableFrom']) > 20:
            print(f"    ... and {len(result['reachableFrom']) - 20} more")


def check_for_readiness_script(product_name, repo_root):
    """Check if a readiness script exists for this product."""
    scripts_dir = Path(repo_root) / "Scripts"
    if not scripts_dir.exists():
        return False
    
    product_key = product_name.lower().replace("-", "_").replace(" ", "_")
    
    # Look for test_*_readiness.sh
    for script in scripts_dir.glob("test_*_readiness.sh"):
        if product_key in script.name.lower():
            return True
    
    # Also check for mentions in existing test scripts
    for script in scripts_dir.glob("test_*.sh"):
        try:
            content = script.read_text(errors="ignore")
            if product_name in content:
                return True
        except:
            continue
    
    return False


def is_executable_product(product):
    """Check if a SwiftPM product is an executable."""
    product_type = product.get("type", {})
    if isinstance(product_type, dict):
        return "executable" in product_type
    elif isinstance(product_type, str):
        return "executable" in product_type.lower()
    return False


def scan_for_patterns(patterns, root_dir, extensions=None, alignment_rules=None):
    """Scan files for regex patterns with support for exclusions and deduplication."""
    results = []
    if extensions is None:
        extensions = [".md", ".swift", ".yaml", ".json"]
    
    # Get exclusion patterns and filters from alignment rules
    exclusions = alignment_rules.get("claim_scan_exclusions", {}) if alignment_rules else {}
    path_patterns = exclusions.get("path_patterns", [])
    include_extensions = exclusions.get("include_extensions", None)
    
    # Get context filters
    context_filters = alignment_rules.get("claim_context_filters", {}) if alignment_rules else {}
    exclude_phrases = context_filters.get("exclude_phrases", [])
    require_positive_claim = context_filters.get("require_positive_claim", False)
    positive_claim_phrases = context_filters.get("positive_claim_phrases", [])
    
    # Get deduplication settings
    dedup_config = alignment_rules.get("deduplication", {}) if alignment_rules else {}
    dedup_key = dedup_config.get("key", None)  # e.g., "file_pattern"
    
    # Track deduplicated keys
    seen_keys = set()
    
    for path in Path(root_dir).rglob("*"):
        # Filter by extension
        if path.suffix not in extensions:
            continue
        
        # Skip build and git directories
        if ".build" in str(path) or ".git" in str(path):
            continue
        
        # Filter by include_extensions if specified
        if include_extensions is not None:
            if path.suffix not in include_extensions:
                continue
        
        rel_path = normalize_path(str(path), get_repo_root())
        if rel_path is None:
            continue
        
        # Check path exclusions
        is_excluded = False
        for pattern in path_patterns:
            if rel_path == pattern or rel_path.startswith(pattern.rstrip("*")) or fnmatch.fnmatch(rel_path, pattern):
                is_excluded = True
                break
        if is_excluded:
            continue
        
        try:
            content = path.read_text(errors="ignore")
            for key, config in patterns.items():
                pattern = config["pattern"]
                matches = re.finditer(pattern, content, re.IGNORECASE)
                for match in matches:
                    line_no = content.count("\n", 0, match.start()) + 1
                    matched_text = match.group(0)
                    matched_line = content.split("\n")[line_no - 1] if line_no <= len(content.split("\n")) else ""
                    
                    # Apply context filters
                    skip_line = False
                    
                    # Check exclude phrases
                    for phrase in exclude_phrases:
                        if phrase.lower() in matched_line.lower():
                            skip_line = True
                            break
                    
                    # Check if positive claim is required
                    if require_positive_claim and not skip_line:
                        has_positive = False
                        for pos_phrase in positive_claim_phrases:
                            if pos_phrase.lower() in matched_line.lower():
                                has_positive = True
                                break
                        if not has_positive:
                            skip_line = True
                    
                    if skip_line:
                        continue
                    
                    # Apply deduplication
                    if dedup_key == "file_pattern":
                        dedup_key_val = f"{rel_path}:{key}"
                        if dedup_key_val in seen_keys:
                            continue
                        seen_keys.add(dedup_key_val)
                    
                    results.append({
                        "id": key,
                        "file": rel_path,
                        "line": line_no,
                        "text": matched_text,
                        "severity": config.get("severity", "informational"),
                        "message": config.get("message", "")
                    })
        except Exception:
            continue
    return results


def cmd_alignment_matrix(args):
    """Generate alignment diagnostic matrix."""
    output_dir = args.output_dir
    ensure_output_dir(output_dir)
    
    # Load data
    describe_file = os.path.join(output_dir, "swiftpm-package-description.json")
    if not os.path.exists(describe_file):
        cmd_snapshot(args)
    
    describe_raw = load_json_file(describe_file)
    describe_data = parse_swiftpm_describe(json.dumps(describe_raw))
    
    rules = load_rules(args.rules)
    alignment_rules = load_rules(args.alignment_rules)
    
    target_graph = build_target_graph(describe_data, rules)
    product_graph = build_product_graph(describe_data)
    
    diagnostics = []
    diag_id_counter = 1

    def add_diag(subject, subject_type, current_target, current_role, expected_role, misalignment, severity, action, followup="", evidence=None, rule=""):
        nonlocal diag_id_counter
        diag_id = f"ADM-{diag_id_counter:04d}"
        diag_id_counter += 1
        
        # Check if exception exists (by ID or by subject match)
        for exc in alignment_rules.get("exceptions", []):
            if exc.get("id") == diag_id or exc.get("subject") == subject:
                return # Skip excepted diagnostic
        
        diagnostics.append({
            "diagnosticId": diag_id,
            "subject": subject,
            "subjectType": subject_type,
            "currentTarget": current_target,
            "currentRole": current_role,
            "expectedRole": expected_role,
            "misalignment": misalignment,
            "severity": severity,
            "recommendedAction": action,
            "followupTd": followup,
            "status": "open",
            "sourceEvidence": evidence or [],
            "doctrineRule": rule
        })

    # 1. Sidecar Readiness Gap
    sidecar_patterns = alignment_rules.get("sidecar_markers", {}).get("product_names", [])
    resolved_products = alignment_rules.get("resolved_sidecar_products", {}).get("product_names", [])
    repo_root = get_repo_root()
    
    for product in product_graph.get("products", []):
        # Check if product matches sidecar patterns
        is_sidecar = False
        for pattern in sidecar_patterns:
            if fnmatch.fnmatch(product["name"], pattern):
                is_sidecar = True
                break
        
        if not is_sidecar:
            continue
        
        # Check if product is in resolved list
        if product["name"] in resolved_products:
            continue  # Skip resolved products
        
        # Check for existing readiness lane (product-specific)
        # Check for readiness scripts for this specific product
        has_readiness_script = check_for_readiness_script(product["name"], repo_root)
        
        if not has_readiness_script:
            # Determine subject type based on actual product type
            if is_executable_product(product):
                subject_type = "executable_product"
                current_role = "executable"
            else:
                subject_type = "library_product"
                current_role = "library"
            
            add_diag(
                subject=product["name"],
                subject_type=subject_type,
                current_target=product["targets"][0] if product["targets"] else product["name"],
                current_role=current_role,
                expected_role="sidecar_executable",
                misalignment="Product build/readiness is not equivalent to governed sidecar health.",
                severity="P0",
                action="Implement sidecar readiness receipt and governance gate.",
                rule="sidecar products require sidecar readiness receipts"
            )

    # 2. Native Linker Leakage
    forbidden_reach = alignment_rules.get("forbidden_readiness_reachability", [])
    for forbidden in forbidden_reach:
        # Who reaches this forbidden target?
        why = get_why_builds(forbidden, target_graph)
        for dep in why["allDependents"]:
            # If a generic Tier 2 target depends on it
            target_info = next((t for t in target_graph["targets"] if t["name"] == dep), None)
            if target_info and target_info.get("tier") in ["tier1", "tier2"] and "Readiness" not in dep:
                add_diag(
                    subject=dep,
                    subject_type="target",
                    current_target=dep,
                    current_role=target_info.get("role", "unknown"),
                    expected_role="portable_runtime",
                    misalignment=f"Generic target reaches native dependency '{forbidden}'.",
                    severity="P1",
                    action=f"Isolate '{forbidden}' behind a portable contract or sidecar.",
                    evidence=[f"Dependency path: {dep} -> ... -> {forbidden}"],
                    rule="native linker settings must be isolated from portable targets"
                )

    # 3. Claim Audit
    claim_patterns = alignment_rules.get("claim_audit_patterns", {})
    repo_root = get_repo_root()
    # Scan both Docs and Packages, but exclusions will filter out Docs/
    scan_dirs = [os.path.join(repo_root, "Docs"), os.path.join(repo_root, "anigma", "Packages")]
    for scan_dir in scan_dirs:
        if not os.path.exists(scan_dir): continue
        # Pass alignment_rules to enable exclusions, context filters, and deduplication
        findings = scan_for_patterns(claim_patterns, scan_dir, alignment_rules=alignment_rules)
        for f in findings:
            pattern_id = f["id"]
            # Only process text-based claim patterns (skip if somehow empty)
            if not pattern_id or pattern_id not in claim_patterns:
                continue
            
            # Determine subject type based on file extension
            file_ext = Path(f["file"]).suffix.lower() if f["file"] else ""
            if file_ext == ".swift":
                subject_type = "target"
                current_role = "substrate_or_capsule"
            else:
                subject_type = "file"
                current_role = "documentation"
            
            # Determine action based on pattern
            if pattern_id == "zero_copy":
                action = "Standardize on 'copy-minimized' unless receipt is proven."
                rule = "do not claim zero-copy without receipt evidence"
            elif pattern_id == "hardware_resident":
                action = "Provide domain proof for hardware residue claims."
                rule = "hardware-resident claims require domain proof"
            else:
                action = "Review and validate claim with appropriate receipt."
                rule = f"{pattern_id} claims require validation"
            
            add_diag(
                subject=f["file"],
                subject_type=subject_type,
                current_target=f["file"],
                current_role=current_role,
                expected_role="doctrine" if subject_type == "file" else "portable_contract",
                misalignment=f["message"],
                severity=f["severity"],
                action=action,
                evidence=[f"Found '{f['text']}' at {f['file']}:{f['line']}"],
                rule=rule
            )

    # Summary
    p0_count = sum(1 for d in diagnostics if d["severity"] == "P0")
    p1_count = sum(1 for d in diagnostics if d["severity"] == "P1")
    p2_count = sum(1 for d in diagnostics if d["severity"] == "P2")
    info_count = sum(1 for d in diagnostics if d["severity"] == "informational")
    
    matrix_output = {
        "schema": ALIGNMENT_MATRIX_SCHEMA,
        "summary": {
            "diagnosticCount": len(diagnostics),
            "p0Count": p0_count,
            "p1Count": p1_count,
            "p2Count": p2_count,
            "informationalCount": info_count
        },
        "diagnostics": diagnostics
    }

    # Deterministic output dir based on task-id
    final_output_dir = os.path.join(output_dir, "current")
    if args.task_id:
        # Try to get commit hash
        commit_hash = "unknown"
        try:
            commit_hash = run_command(["git", "rev-parse", "--short", "HEAD"])
        except: pass
        label = args.label or "default"
        final_output_dir = os.path.join(output_dir, "tasks", args.task_id, commit_hash, label)
    
    Path(final_output_dir).mkdir(parents=True, exist_ok=True)
    
    # JSON
    write_json_file(os.path.join(final_output_dir, "anigma-alignment-diagnostic-matrix.json"), matrix_output)
    # Also write to 'current' if not already there
    if final_output_dir != os.path.join(output_dir, "current"):
        Path(os.path.join(output_dir, "current")).mkdir(parents=True, exist_ok=True)
        write_json_file(os.path.join(output_dir, "current", "anigma-alignment-diagnostic-matrix.json"), matrix_output)

    # CSV
    csv_path = os.path.join(final_output_dir, "anigma-alignment-diagnostic-matrix.csv")
    csv_columns = [
        "diagnosticId", "subject", "subjectType", "currentTarget", "currentRole",
        "expectedRole", "misalignment", "severity", "recommendedAction",
        "followupTd", "status", "doctrineRule"
    ]
    with open(csv_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=csv_columns, extrasaction='ignore')
        writer.writeheader()
        for d in diagnostics:
            writer.writerow(d)
    if final_output_dir != os.path.join(output_dir, "current"):
        import shutil
        shlex_csv = os.path.join(output_dir, "current", "anigma-alignment-diagnostic-matrix.csv")
        shutil.copy(csv_path, shlex_csv)

    # Markdown Summary
    md_path = os.path.join(final_output_dir, "anigma-alignment-diagnostic-summary.md")
    with open(md_path, 'w') as f:
        f.write("# Anigma Alignment Diagnostic Summary\n\n")
        f.write(f"- **P0**: {p0_count}\n")
        f.write(f"- **P1**: {p1_count}\n")
        f.write(f"- **P2**: {p2_count}\n")
        f.write(f"- **Informational**: {info_count}\n\n")
        
        f.write("## Detailed Findings\n\n")
        for d in diagnostics:
            emoji = {"P0": "🔴", "P1": "🟠", "P2": "🟡", "informational": "🔵"}.get(d["severity"], "⚪")
            f.write(f"### {emoji} {d['diagnosticId']}: {d['subject']}\n")
            f.write(f"- **Severity**: {d['severity']}\n")
            f.write(f"- **Misalignment**: {d['misalignment']}\n")
            f.write(f"- **Action**: {d['recommendedAction']}\n\n")
    if final_output_dir != os.path.join(output_dir, "current"):
        shutil.copy(md_path, os.path.join(output_dir, "current", "anigma-alignment-diagnostic-summary.md"))

    print(f"Alignment matrix generated in {final_output_dir}/")
    print(f"Summary: P0={p0_count}, P1={p1_count}, P2={p2_count}, Info={info_count}")
    
    if args.fail_on_p0 and p0_count > 0:
        print(f"Exiting with code 1 due to {p0_count} P0 diagnostics.")
        sys.exit(1)


def cmd_why_builds(args):
    """Show why a target builds (reverse dependency analysis)."""
    describe_cmd = ["swift", "package", "describe", "--type", "json"]
    describe_raw = run_command(describe_cmd, cwd=get_package_root())
    describe_data = parse_swiftpm_describe(describe_raw)
    
    rules = load_rules(args.rules)
    target_graph = build_target_graph(describe_data, rules)
    
    target_name = args.target_name
    result = get_why_builds(target_name, target_graph)
    
    print(f"Why '{target_name}' builds:")
    print(f"  Direct dependents: {len(result['directDependents'])}")
    if result['directDependents']:
        for dep in result['directDependents']:
            print(f"    - {dep}")
    print(f"  All dependents: {len(result['allDependents'])}")
    if result['allDependents']:
        for dep in result['allDependents'][:20]:
            print(f"    - {dep}")
        if len(result['allDependents']) > 20:
            print(f"    ... and {len(result['allDependents']) - 20} more")
    
    print(f"  Reachable from '{target_name}': {len(result['reachableFrom'])}")
    if result['reachableFrom']:
        for dep in result['reachableFrom'][:20]:
            print(f"    - {dep}")
        if len(result['reachableFrom']) > 20:
            print(f"    ... and {len(result['reachableFrom']) - 20} more")


def main():
    parser = argparse.ArgumentParser(
        description="Anigma Package Graph Audit",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Severity Behavior:
    --fail-on-violation exits nonzero ONLY on error-severity violations.
    Warning-severity findings (like no_unclassified_target) are reported but NON-BLOCKING.
    This allows incremental adoption of classification coverage.
        """
    )
    subparsers = parser.add_subparsers(dest="command", title="commands", description="Available commands")
    
    # Full command (default)
    full_parser = subparsers.add_parser("full", help="Run full audit with all outputs")
    full_parser.set_defaults(command="full")
    
    # Snapshot command
    snapshot_parser = subparsers.add_parser("snapshot", help="Capture SwiftPM JSON snapshots")
    snapshot_parser.set_defaults(command="snapshot")
    
    # Violations command
    violations_parser = subparsers.add_parser("violations", help="Check violations only")
    violations_parser.set_defaults(command="violations")
    
    # Suggest classifications command
    suggest_parser = subparsers.add_parser("suggest-classifications", help="Suggest tier classifications")
    suggest_parser.set_defaults(command="suggest-classifications")
    
    # List targets command
    list_parser = subparsers.add_parser("list-targets", help="List all targets")
    list_parser.set_defaults(command="list-targets")
    
    # Explain target command
    explain_target_parser = subparsers.add_parser("explain-target", help="Explain a target")
    explain_target_parser.add_argument("target_name", help="Name of the target to explain")
    explain_target_parser.set_defaults(command="explain-target")
    
    # Explain edge command
    explain_edge_parser = subparsers.add_parser("explain-edge", help="Explain a dependency edge")
    explain_edge_parser.add_argument("from_target", help="Source target name")
    explain_edge_parser.add_argument("to_target", help="Destination target name")
    explain_edge_parser.set_defaults(command="explain-edge")
    
    # Why builds command
    why_builds_parser = subparsers.add_parser("why-builds", help="Show why a target builds")
    why_builds_parser.add_argument("target_name", help="Name of the target to analyze")
    why_builds_parser.set_defaults(command="why-builds")
    
    # Alignment matrix command
    alignment_parser = subparsers.add_parser("alignment-matrix", help="Generate alignment diagnostic matrix")
    alignment_parser.add_argument("--task-id", help="Task ID for snapshots")
    alignment_parser.add_argument("--label", help="Label for snapshots (e.g. pre, post, review)")
    alignment_parser.add_argument("--fail-on-p0", action="store_true", help="Exit nonzero if P0 diagnostics found")
    alignment_parser.add_argument("--alignment-rules", default=DEFAULT_ALIGNMENT_RULES_FILE, help="Path to alignment diagnostic rules YAML")
    alignment_parser.set_defaults(command="alignment-matrix")
    
    # Global options
    parser.add_argument(
        "--fail-on-violation",
        action="store_true",
        help="Exit nonzero if error-severity violations found"
    )
    parser.add_argument(
        "--rules",
        default=DEFAULT_RULES_FILE,
        help="Path to rules YAML file"
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help="Output directory for generated files"
    )
    
    args = parser.parse_args()
    
    # Default to full audit if no command specified
    if args.command is None:
        args.command = "full"
    
    output_dir = args.output_dir
    
    # Handle subcommands
    if args.command == "snapshot":
        cmd_snapshot(args)
        return
    
    if args.command == "violations":
        cmd_violations(args)
        return
    
    if args.command == "suggest-classifications":
        cmd_suggest_classifications(args)
        return
    
    if args.command == "list-targets":
        cmd_list_targets(args)
        return
    
    if args.command == "explain-target":
        cmd_explain_target(args)
        return
    
    if args.command == "explain-edge":
        cmd_explain_edge(args)
        return
    
    if args.command == "why-builds":
        cmd_why_builds(args)
        return
    
    if args.command == "alignment-matrix":
        cmd_alignment_matrix(args)
        return
    
    # Default: full audit
    ensure_output_dir(output_dir)
    source_commands = []
    
    try:
        # Step 1: Get SwiftPM describe output
        describe_cmd = ["swift", "package", "describe", "--type", "json"]
        source_commands.append(" ".join(describe_cmd))
        describe_raw = run_command(describe_cmd, cwd=get_package_root())
        describe_file = os.path.join(output_dir, "swiftpm-package-description.json")
        write_json_file(describe_file, json.loads(describe_raw))
        describe_data = parse_swiftpm_describe(describe_raw)
        write_json_file(
            os.path.join(output_dir, "anigma-target-graph.json"),
            describe_data
        )
        
        # Step 2: Get SwiftPM dependencies output
        deps_cmd = ["swift", "package", "show-dependencies", "--format", "json"]
        source_commands.append(" ".join(deps_cmd))
        try:
            deps_raw = run_command(deps_cmd, cwd=get_package_root())
            deps_data = parse_swiftpm_dependencies(deps_raw)
            write_json_file(
                os.path.join(output_dir, "swiftpm-package-dependencies.json"),
                json.loads(deps_raw)
            )
            write_json_file(
                os.path.join(output_dir, "anigma-external-package-graph.json"),
                deps_data
            )
        except AuditError:
            deps_data = {"schema": "swiftpm.package_dependencies.v1", "packages": []}
        
        # Step 3: Load rules
        rules = load_rules(args.rules)
        
        # Step 4: Build normalized graphs
        target_graph = build_target_graph(describe_data, rules)
        write_json_file(
            os.path.join(output_dir, "anigma-target-graph.json"),
            target_graph
        )
        
        product_graph_data = build_product_graph(describe_data)
        write_json_file(
            os.path.join(output_dir, "anigma-product-graph.json"),
            product_graph_data
        )
        
        external_graph = build_external_graph(deps_data)
        write_json_file(
            os.path.join(output_dir, "anigma-external-package-graph.json"),
            external_graph
        )
        
        # Step 5: Generate unclassified report
        unclassified_report = generate_unclassified_report(target_graph, output_dir)
        
        # Step 6: Generate classification suggestions
        suggestions = generate_classification_suggestions(target_graph, rules)
        if HAS_YAML:
            yaml_path = os.path.join(output_dir, "package-graph-classification-suggestions.yaml")
            with open(yaml_path, 'w') as f:
                yaml.dump(suggestions, f, default_flow_style=False, sort_keys=False)
        write_json_file(
            os.path.join(output_dir, "anigma-classification-suggestions.json"),
            suggestions
        )
        
        # Step 7: Check violations
        violations = check_violation_rules(target_graph, rules)
        violations = filter_allowlisted(violations, rules.get("allowlist", {}))
        
        error_count = sum(1 for v in violations if v.get("severity") == "error")
        warning_count = sum(1 for v in violations if v.get("severity") == "warning")
        
        violations_output = {
            "schema": VIOLATION_SCHEMA,
            "generatedBy": "Scripts/anigma_package_graph_audit.py",
            "sourceCommands": source_commands,
            "summary": {
                "targetCount": len(describe_data.get("targets", [])),
                "productCount": len(describe_data.get("products", [])),
                "externalPackageCount": len(deps_data.get("packages", [])),
                "violationCount": len(violations),
                "errorCount": error_count,
                "warningCount": warning_count,
                "classificationCoverage": unclassified_report.get("summary", {}).get("classificationCoverage", 0)
            },
            "violations": violations
        }
        
        write_json_file(
            os.path.join(output_dir, "anigma-dependency-violations.json"),
            violations_output
        )
        
        # Step 8: Generate markdown summary
        md_summary = generate_markdown_summary(
            target_graph, product_graph_data, external_graph,
            violations, rules, source_commands, output_dir
        )
        with open(os.path.join(output_dir, "anigma-package-graph-audit.md"), 'w') as f:
            f.write(md_summary)
        
        # Step 9: Print summary
        print(f"Audit complete. Output written to {output_dir}/")
        print(f"Summary:")
        print(f"  Targets: {len(describe_data.get('targets', []))}")
        print(f"  Products: {len(describe_data.get('products', []))}")
        print(f"  External packages: {len(deps_data.get('packages', []))}")
        print(f"  Violations: {len(violations)} ({error_count} errors, {warning_count} warnings)")
        coverage = compute_classification_coverage(target_graph)
        print(f"  Classification Coverage: {coverage['coverage'] * 100:.1f}%")
        
        if args.fail_on_violation and error_count > 0:
            sys.exit(1)
        
    except AuditError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
