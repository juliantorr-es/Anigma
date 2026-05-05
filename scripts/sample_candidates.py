import json
import os

with open('.build/anigma-dead-code-audit.json', 'r') as f:
    data = json.load(f)

candidates = [d for d in data if d['classification'] == 'candidate_dead']

# Deterministic sampling (sort by file and line)
candidates.sort(key=lambda x: (x['file'], x['line']))

prod = [c for c in candidates if 'Tests' not in c['file'] and 'App' not in c['file'] and 'Package.swift' not in c['file']]
tests = [c for c in candidates if 'Tests' in c['file']]
app = [c for c in candidates if 'App' in c['file']]
pkg = [c for c in candidates if 'Package.swift' in c['file'] or 'Plugin' in c['file']]

sample_prod = prod[:20]
sample_tests = tests[:10]
sample_app = app[:10]
sample_pkg = pkg[:10]

all_samples = sample_prod + sample_tests + sample_app + sample_pkg

for i, s in enumerate(all_samples):
    print(f"{i+1}. {s['name']} ({s['kind']}) in {s['file']}:{s['line']}")
