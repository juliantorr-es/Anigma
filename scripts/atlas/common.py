from __future__ import annotations
from dataclasses import asdict, dataclass, field


@dataclass
class SymbolRecord:
    language: str
    kind: str
    name: str
    file: str
    line: int
    signature: str = ""
    enclosing_type: str | None = None
    access: str | None = None
    attributes: list[str] = field(default_factory=list)
    risk_tags: list[str] = field(default_factory=list)

    def to_dict(self):
        return asdict(self)


@dataclass
class FileRecord:
    path: str
    language: str
    file_type: str
    source_category: str
    module: str | None
    line_count: int
    sha256: str
    generated: bool = False
    excluded: bool = False

    def to_dict(self):
        return asdict(self)
