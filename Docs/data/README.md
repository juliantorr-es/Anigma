# Data Directory

**Doc ID:** DATA_README  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-02  

---

## Overview

This directory contains data files used for Anigma documentation, reporting, and tracking. These are **not** runtime data files (which belong in appropriate package directories), but rather **documentation data** - structured data that supports the Docs/ ecosystem.

## Directory Structure

```
 Docs/data/
├── README.md                          # This file
└── ... (data files as needed)
```

## Purpose

The `Docs/data/` directory is intended for:

1. **Report Data** - Structured data extracted from the codebase for analysis
2. **Tracking Data** - Machine-readable tracking of documentation state
3. **Reference Data** - Canonical data sets referenced by documentation
4. **Generated Data** - Output from documentation tools/scripts

## Current State

This directory is currently a **placeholder** for future data files. As of 2026-05-02, no data files have been created yet.

## Expected Content

Future files that may belong here include:

| File | Purpose | Tool/Script |
|------|---------|-------------|
| `file-inventory.json` | Complete inventory of all files in Docs/ | `generate_file_inventory.py` |
| `td-statistics.yaml` | TD task counts, status breakdowns | `generate_td_report.py` |
| `proof-inventory.yaml` | Index of all proof artifacts | `generate_proof_index.py` |
| `dependency-graph.json` | Docs/ dependency graph | `analyze_doc_dependencies.py` |

## Usage

### For Documentation Generators

Script authors should place generated data files here if:
- The data is machine-readable (JSON, YAML, CSV)
- The data supports documentation generation or validation
- The data is not sensitive or runtime-specific

### For Documentation Readers

Files in this directory are intended to be:
- **Read by scripts** for generating reports
- **Referenced by documentation** for current state
- **Committed to git** for reproducibility

## Validation

All files in this directory should be:
- Valid JSON/YAML/CSV as appropriate
- Less than 1MB (larger data should be in a separate data store)
- Documented in this README

```bash
# Validate all data files
for f in Docs/data/*.json; do
  python3 -m json.tool "$f" > /dev/null && echo "✅ $f" || echo "❌ $f"
done

for f in Docs/data/*.yaml Docs/data/*.yml; do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "✅ $f" || echo "❌ $f"
done
```

## Related Documentation

- [Architecture Maps](../architecture/maps/README.md) - Module/file structure
- [Manifests](../manifests/) - Configuration and policy manifests
- [Reports](../reports/) - Human-readable analysis and reports

---

## Maintenance

### Adding Data Files

1. Create the data file in `Docs/data/`
2. Add a row to the Expected Content table above
3. Document the generating tool/script
4. Add validation to the Validation section
5. Reference from relevant documentation

### Removing Data Files

1. Archive to `Docs/archive/data/` if historically significant
2. Remove references from documentation
3. Update this README

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-02 | Initial data README - placeholder for future data files |
