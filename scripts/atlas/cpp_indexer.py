import re
from .common import SymbolRecord

INCLUDE_RE = re.compile(r'^\s*#include\s+[<"]([^">]+)[">]')
CLASS_RE = re.compile(r'^\s*(class|struct)\s+([A-Za-z_][A-Za-z0-9_]*)')
FUNC_RE = re.compile(r'^\s*(?:[A-Za-z_][\w:<>,\s\*&]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
MAIN_RE = re.compile(r'^\s*int\s+main\s*\(')

def index(path, text):
    includes = []
    symbols = []
    for i, line in enumerate(text.splitlines(), 1):
        m = INCLUDE_RE.match(line)
        if m:
            includes.append(m.group(1))
        c = CLASS_RE.match(line)
        if c:
            kind, name = c.groups()
            tags = ["cpp_ffi_boundary"] if "extern \"C\"" in text else []
            symbols.append(SymbolRecord("cpp", kind, name, path, i, line.strip(), None, None, [], tags))
        f = FUNC_RE.match(line)
        if f and not line.strip().startswith("#"):
            name = f.group(1)
            symbols.append(SymbolRecord("cpp", "func", name, path, i, line.strip(), None, None, [], []))
    if MAIN_RE.search(text):
        symbols.append(SymbolRecord("cpp", "main", "main", path, 1, "int main", None, None, ["entrypoint"], ["cpp_ffi_boundary"]))
    tags = []
    if any(x in text for x in ("malloc(", "free(", "new ", "delete ")):
        tags.extend(["cpp_raw_pointer", "cpp_manual_lifetime"])
    if "std::thread" in text or "pthread_" in text or "dispatch_" in text:
        tags.append("cpp_threading")
    if "extern \"C\"" in text:
        tags.append("cpp_ffi_boundary")
    return {"imports": sorted(set(includes)), "symbols": symbols, "risk_tags": sorted(set(tags))}

