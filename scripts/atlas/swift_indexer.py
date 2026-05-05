import re
from .common import SymbolRecord

DECL_RE = re.compile(r'^\s*(public|open|internal|fileprivate|private|package)?\s*(?:@MainActor\s*)?(struct|class|actor|enum|protocol|extension|func)\s+([A-Za-z_][A-Za-z0-9_]*)')
IMPORT_RE = re.compile(r'^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)')

def index(path, text):
    imports = []
    symbols = []
    for i, line in enumerate(text.splitlines(), 1):
        m = IMPORT_RE.match(line)
        if m:
            imports.append(m.group(1))
        d = DECL_RE.match(line)
        if d:
            access, kind, name = d.groups()
            sig = line.strip()
            tags = []
            if "Authority" in name:
                tags.append("process_lifecycle_boundary")
            if "Executor" in name:
                tags.append("executor_boundary")
            if "Registry" in name:
                tags.append("registry_boundary")
            if "Worker" in name:
                tags.append("worker_boundary")
            if "Kernel" in name:
                tags.append("kernel_boundary")
            symbols.append(SymbolRecord("swift", kind, name, path, i, sig, None, access, [], tags))
    if "@main" in text:
        symbols.append(SymbolRecord("swift", "@main", path.rsplit("/", 1)[-1].replace(".swift", ""), path, 1, "@main", None, None, ["main"], []))
    return {"imports": sorted(set(imports)), "symbols": symbols}

