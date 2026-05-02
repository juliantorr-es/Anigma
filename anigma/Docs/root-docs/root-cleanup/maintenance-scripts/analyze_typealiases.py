import re
import collections

def analyze_typealiases(filepath):
    # Regex to match: anigma/Packages/ModuleName/File.swift:typealias AliasName = TargetType
    # and variations for Sources/ModuleName/
    pattern = re.compile(r'anigma/(?:Packages|Sources)/([^/]+)/.*?typealias\s+(\w+)\s*=\s*([^/\n]+)')
    
    aliases = []
    with open(filepath, 'r') as f:
        for line in f:
            match = pattern.search(line)
            if match:
                module = match.group(1)
                alias_name = match.group(2)
                target_type = match.group(3).strip()
                # Clean up target type (remove comments, extra spaces)
                target_type = target_type.split('//')[0].strip()
                aliases.append({
                    'module': module,
                    'alias': alias_name,
                    'target': target_type
                })
    return aliases

def generate_matrix(aliases):
    # alias_name -> {target_type -> count}
    usage = collections.defaultdict(lambda: collections.defaultdict(int))
    # alias_name -> set(modules)
    distribution = collections.defaultdict(set)
    
    for a in aliases:
        usage[a['alias']][a['target']] += 1
        distribution[a['alias']].add(a['module'])
        
    return usage, distribution

def generate_report(aliases, usage, distribution, output_path):
    with open(output_path, 'w') as f:
        f.write("# Typealias Audit & Usage Matrix\n\n")
        f.write("This audit identifies how typealiases are used across the codebase to provide domain-specific names or bridge between modules.\n\n")
        
        f.write("## Executive Summary\n\n")
        f.write(f"- **Total Typealiases Found**: {len(aliases)}\n")
        f.write(f"- **Unique Alias Names**: {len(usage)}\n")
        
        f.write("\n## Top 20 Most Frequent Typealias Names\n\n")
        f.write("| Alias Name | Unique Target Types | Modules Using It | Total Occurrences |\n")
        f.write("|---|---|---|---|\n")
        
        sorted_aliases = sorted(usage.items(), key=lambda x: sum(x[1].values()), reverse=True)
        for name, targets in sorted_aliases[:20]:
            target_count = len(targets)
            module_count = len(distribution[name])
            total = sum(targets.values())
            f.write(f"| {name} | {target_count} | {module_count} | {total} |\n")
            
        f.write("\n## Backend Consolidation Strategy\n\n")
        f.write("Typealiases are powerful indicators of domain overlap. Here is how they help consolidate the backend:\n\n")
        f.write("1. **Identifying Shadow Domains**: When multiple modules alias different internal types to the same public name (e.g., `typealias Workspace = ...`), it suggests these modules are competing to own the same concept. These should be moved to a shared `ContractsCore` or `DomainCore`.\n")
        f.write("2. **Detecting Semantic Drift**: If an alias like `UserID` points to `String` in one module but `UUID` in another, it creates silent integration bugs. Consolidation requires standardizing these primitive aliases.\n")
        f.write("3. **Interface Bridging**: Many typealiases exist only to avoid importing a large module for a single type. If we see `typealias AppState = AnigmaAppMac.AppState` repeated, it's a sign that `AppState` should be extracted into a smaller interface module.\n")
        f.write("4. **Refactoring Targets**: High-frequency aliases with multiple target types (High 'Unique Target Types') are high-risk areas where the codebase is 'lying' about what a type actually is. These are the primary targets for protocol-based abstraction.\n")

        f.write("\n## Typealias Usage Matrix (Inconsistent Aliases)\n")
        f.write("Aliases that point to different types in different modules (potential semantic drift).\n\n")
        f.write("| Alias | Module -> Target Type Mapping |\n")
        f.write("|---|---|\n")
        
        for name, targets in sorted_aliases:
            if len(targets) > 1:
                # Find modules for each target
                mapping = []
                for target_type in targets:
                    mods = [a['module'] for a in aliases if a['alias'] == name and a['target'] == target_type]
                    mapping.append(f"**{target_type}**: {', '.join(set(mods))}")
                
                f.write(f"| {name} | {';<br>'.join(mapping)} |\n")

if __name__ == "__main__":
    raw_path = "typealiases_raw.txt"
    out_path = "TYPEALIAS_AUDIT.md"
    
    aliases = analyze_typealiases(raw_path)
    usage, distribution = generate_matrix(aliases)
    generate_report(aliases, usage, distribution, out_path)
    print(f"Generated report at {out_path}")
