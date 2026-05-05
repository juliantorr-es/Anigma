#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re
from pathlib import Path

REPO_ROOT=Path(__file__).resolve().parents[1]; ATLAS=REPO_ROOT/"Docs"/"atlas"
def load(name):
    p=ATLAS/name
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else []
def toks(s): return set(re.findall(r"[A-Za-z0-9_]+", s.lower()))
def target_priority(item, target):
    if not target:
        return 1
    hay = json.dumps(item).lower()
    return 0 if target.lower() in hay else 1
def main():
    ap=argparse.ArgumentParser(); ap.add_argument("query",nargs="?"); ap.add_argument("--symbol"); ap.add_argument("--file"); ap.add_argument("--risk"); ap.add_argument("--target"); ap.add_argument("--language"); ap.add_argument("--native-dependency"); ap.add_argument("--bridge"); ap.add_argument("--entrypoint"); ap.add_argument("--state"); ap.add_argument("--flow"); ap.add_argument("--cohesion"); ap.add_argument("--limit",type=int,default=10); ap.add_argument("--format",choices=["text","json"],default="text"); ap.add_argument("--check",action="store_true"); a=ap.parse_args()
    repo=load("repo-map.json"); sym=load("symbols.json"); risks=load("risk-index.json"); entries=load("entrypoints.json"); auth=load("authority-map.json"); bridges=load("bridge-map.json"); native=load("native-map.json"); shaders=load("shader-map.json"); targets=load("targets.json"); state=load("state-map.json"); flows=load("data-flow-map.json"); cohesion=load("cohesion-index.json")
    if a.check: print("atlas-present" if repo else "atlas-missing"); raise SystemExit(0 if repo else 1)
    q=" ".join(x for x in [a.query,a.symbol,a.file,a.risk,a.target,a.language,a.native_dependency,a.state,a.flow,a.cohesion] if x); qt=toks(q)
    def score(item, fields):
        s=0
        for f in fields:
            s += len(qt & toks(str(item.get(f,""))))
        return s
    rf=sorted([x for x in repo if (a.file and x["path"]==a.file) or (a.language and x["language"]==a.language) or (qt and qt & toks(x["path"]))], key=lambda x:(0 if x.get("path")==a.file else 1, -score(x,["path","language"])))
    rs=sorted([x for x in sym if (a.symbol and x["name"]==a.symbol) or (a.language and x["language"]==a.language) or (qt and qt & (toks(x["name"])|toks(x["file"])) )], key=lambda x:(0 if x.get("name")==a.symbol else 1, -score(x,["name","file"])))
    rr=sorted([x for x in risks if (a.risk and x.get("category")==a.risk) or (a.target and x.get("target")==a.target) or (qt and qt & toks(json.dumps(x)))], key=lambda x:(target_priority(x, a.target), -score(x,["category","path","target"])))
    bridges_q=[x for x in bridges if (a.bridge and a.bridge in json.dumps(x)) or (qt and qt & toks(json.dumps(x)))]
    entries_q=[]
    for x in entries:
        hay=json.dumps(x).lower()
        exact_entry = a.entrypoint and (a.entrypoint.lower()==x.get("path","").lower() or a.entrypoint.lower()==x.get("name","").lower() or a.entrypoint.lower() in hay)
        if exact_entry or (not a.entrypoint and qt and qt & toks(hay)):
            entries_q.append(x)
    auth_q=[x for x in auth if qt and qt & toks(json.dumps(x))]
    state_q=sorted([x for x in state if (a.state and (a.state in json.dumps(x) or a.state == x.get("classification") or a.state == x.get("symbol"))) or (qt and qt & toks(json.dumps(x)))], key=lambda x:(target_priority(x, a.target), -score(x,["classification","path","target","symbol"])))
    flow_q=sorted([x for x in flows if (a.flow and (a.flow in json.dumps(x) or a.flow == x.get("flow_type"))) or (qt and qt & toks(json.dumps(x)))], key=lambda x:(target_priority(x, a.target), -score(x,["flow_type","source","destination"])))
    cohesion_q=sorted([x for x in cohesion if (a.cohesion and (a.cohesion in json.dumps(x) or a.cohesion == x.get("target_or_module"))) or (qt and qt & toks(json.dumps(x)))], key=lambda x:(target_priority(x, a.target), -score(x,["target_or_module","bottleneck_score"])))
    if a.native_dependency: rf += [x for x in native if a.native_dependency in json.dumps(x)]
    if a.format=="json":
        print(json.dumps({"query":q,"files":rf[:a.limit],"symbols":rs[:a.limit],"risks":rr[:a.limit],"bridges":bridges_q[:a.limit],"entrypoints":entries_q[:a.limit],"authorities":auth_q[:a.limit],"state":state_q[:a.limit],"flows":flow_q[:a.limit],"cohesion":cohesion_q[:a.limit],"native":native[:a.limit],"shaders":shaders[:a.limit]},indent=2,sort_keys=True)); return
    print(f"Query: {q or '(none)'}")
    print("Relevant files:"); print("\n".join(f"- {x['path']} ({x.get('language')})" for x in rf[:a.limit]) or "- none")
    print("Relevant symbols:"); print("\n".join(f"- {x['name']} [{x.get('language')}] {x['file']}:{x['line']}" for x in rs[:a.limit]) or "- none")
    print("Relevant bridges:"); print("\n".join(f"- {x.get('swift_file')} -> {x.get('native_file') or x.get('symbol')} ({x.get('bridge_type')})" for x in bridges_q[:a.limit]) or "- none")
    print("Relevant entrypoints:"); print("\n".join(f"- {x.get('path')} ({x.get('kind')})" for x in entries_q[:a.limit]) or "- none")
    print("Relevant authorities:"); print("\n".join(f"- {x.get('authority') or x.get('name') or x.get('kind')} {x.get('path') or x.get('module')}" for x in auth_q[:a.limit]) or "- none")
    print("Relevant risks:"); print("\n".join(f"- {x.get('category')} {x.get('severity')} {x.get('path')}" for x in rr[:a.limit]) or "- none")
    print("Relevant state:"); print("\n".join(f"- {x.get('classification')} {x.get('path')}:{x.get('line')} {x.get('rationale')}" for x in state_q[:a.limit]) or "- none")
    print("Relevant flows:"); print("\n".join(f"- {x.get('flow_type')} {x.get('source')} -> {x.get('status')} {x.get('rationale')}" for x in flow_q[:a.limit]) or "- none")
    print("Relevant cohesion:"); print("\n".join(f"- {x.get('target_or_module')} bottleneck={x.get('bottleneck_score')} density={x.get('risk_density')}" for x in cohesion_q[:a.limit]) or "- none")
    print("Recommended files:"); rec=[]
    rec += [x["path"] for x in rf[:5]]+[x["file"] for x in rs[:5]]+[x.get("path") for x in rr[:5] if x.get("path")]
    print("\n".join(f"- {p}" for p in dict.fromkeys([x for x in rec if x])) or "- none")

if __name__=="__main__": main()
