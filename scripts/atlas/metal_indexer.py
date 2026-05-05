import re
from .common import SymbolRecord

INCLUDE_RE = re.compile(r'^\s*#include\s+[<"]([^">]+)[">]')
KERNEL_RE = re.compile(r'^\s*(kernel|vertex|fragment)\s+([^\s]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
BUFFER_RE = re.compile(r'\[\[buffer\((\d+)\)\]\]')
TEXTURE_RE = re.compile(r'\[\[texture\((\d+)\)\]\]')
SAMPLER_RE = re.compile(r'\[\[sampler\((\d+)\)\]\]')

def index(path, text):
    imports = []
    symbols = []
    for i, line in enumerate(text.splitlines(), 1):
        m = INCLUDE_RE.match(line)
        if m:
            imports.append(m.group(1))
        k = KERNEL_RE.match(line)
        if k:
            kind, ret, name = k.groups()
            attrs = [kind]
            risk = ["metal_kernel_string_reference"]
            if BUFFER_RE.search(line):
                risk.append("metal_buffer_index_contract")
            symbols.append(SymbolRecord("metal", f"{kind}_function", name, path, i, line.strip(), None, None, attrs, risk))
    risk_tags = []
    if "threadgroup" in text or "thread_position" in text:
        risk_tags.append("metal_threadgroup_assumption")
    if "device " in text or "constant " in text or "threadgroup " in text:
        risk_tags.append("metal_address_space")
    if "texture(" in text:
        risk_tags.append("metal_texture_index_contract")
    if "buffer(" in text:
        risk_tags.append("metal_buffer_index_contract")
    return {"imports": sorted(set(imports)), "symbols": symbols, "risk_tags": sorted(set(risk_tags))}

