import re
from .common import SymbolRecord

def index(path, text):
    symbols = []
    if path.endswith((".sh", ".bash", ".zsh")):
        if re.search(r'^\s*(#!/usr/bin/env|#!/bin/)', text, re.M):
            symbols.append(SymbolRecord("script", "entrypoint", path.rsplit("/", 1)[-1], path, 1, text.splitlines()[0] if text else "", None, None, ["shebang"], []))
    if path.endswith(".py") and "if __name__ == \"__main__\":" in text:
        symbols.append(SymbolRecord("script", "entrypoint", path.rsplit("/", 1)[-1], path, 1, "python main guard", None, None, ["main_guard"], []))
    risk = []
    if "rm -rf" in text or "find .build -mindepth 1 -delete" in text:
        risk.append("destructive_operation")
    return {"imports": [], "symbols": symbols, "risk_tags": risk}

