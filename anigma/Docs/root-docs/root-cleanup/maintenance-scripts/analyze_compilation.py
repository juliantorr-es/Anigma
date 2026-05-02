import re
import json

def parse_package_swift(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Regex to find target definitions. It's simplified but usually effective for Package.swift
    # Looks for .target(name: "Name", dependencies: ["Dep1", "Dep2"]...)
    target_pattern = re.compile(r'\.(?:target|executableTarget|testTarget)\s*\(\s*name:\s*"([^"]+)"(?:.*?dependencies:\s*\[([^\]]*)\])?', re.DOTALL)
    
    modules = {}
    
    for match in target_pattern.finditer(content):
        name = match.group(1)
        deps_str = match.group(2)
        
        deps = []
        if deps_str:
            # Extract strings from the dependencies array
            dep_matches = re.findall(r'"([^"]+)"|\.target\(name:\s*"([^"]+)"', deps_str)
            for d in dep_matches:
                # d is a tuple like ('DepName', '') or ('', 'DepName')
                dep_name = d[0] if d[0] else d[1]
                if dep_name:
                    deps.append(dep_name)
                    
        modules[name] = deps
        
    return modules

def analyze_surface(modules):
    fan_out = {name: len(deps) for name, deps in modules.items()}
    fan_in = {name: 0 for name in modules.keys()}
    
    for name, deps in modules.items():
        for dep in deps:
            if dep in fan_in:
                fan_in[dep] += 1
            else:
                fan_in[dep] = 1 # External or not explicitly defined as target
                
    # Calculate a "surface complexity" score. High fan-out means it recompiles often.
    # High fan-in means changing it causes many recompilations.
    
    # Group into tiers based on fan-in/fan-out
    # Foundation (High Fan-In, Low Fan-Out)
    # Feature (Low Fan-In, High Fan-Out)
    # Bottleneck (High Fan-In, High Fan-Out)
    
    return fan_in, fan_out

def generate_report(modules, fan_in, fan_out, output_path):
    with open(output_path, 'w') as f:
        f.write("# Compilation Surface Audit\n\n")
        f.write("This document analyzes the module dependency graph to identify compilation bottlenecks and surface area.\n\n")
        
        f.write("## Executive Summary\n\n")
        total_modules = len(modules)
        f.write(f"- **Total Internal Modules**: {total_modules}\n")
        
        # Sort by fan-in (impact of change)
        sorted_by_fan_in = sorted(fan_in.items(), key=lambda x: x[1], reverse=True)
        f.write("\n### Top 10 High-Impact Modules (Foundation / Bottlenecks)\n")
        f.write("Changing these modules causes the largest recompilation cascades.\n\n")
        f.write("| Module | Dependents (Fan-In) | Dependencies (Fan-Out) |\n")
        f.write("|---|---|---|\n")
        for name, fin in sorted_by_fan_in[:10]:
            fout = fan_out.get(name, 0)
            f.write(f"| {name} | {fin} | {fout} |\n")
            
        # Sort by fan-out (fragility / compilation time)
        sorted_by_fan_out = sorted(fan_out.items(), key=lambda x: x[1], reverse=True)
        f.write("\n### Top 10 Most Fragile Modules (High Fan-Out)\n")
        f.write("These modules take the longest to compile and are invalidated by changes in many other modules.\n\n")
        f.write("| Module | Dependencies (Fan-Out) | Dependents (Fan-In) |\n")
        f.write("|---|---|---|\n")
        for name, fout in sorted_by_fan_out[:10]:
            fin = fan_in.get(name, 0)
            f.write(f"| {name} | {fout} | {fin} |\n")
            
        f.write("\n## Compilation Surface Matrix\n\n")
        f.write("Full matrix of all modules sorted alphabetically.\n\n")
        f.write("| Module | Fan-In (Impact) | Fan-Out (Fragility) | Category |\n")
        f.write("|---|---|---|---|\n")
        
        for name in sorted(modules.keys()):
            fin = fan_in.get(name, 0)
            fout = fan_out.get(name, 0)
            
            category = "Standard"
            if fin > 10 and fout > 5:
                category = "🔴 Bottleneck"
            elif fin > 10:
                category = "🔵 Foundation"
            elif fout > 10:
                category = "🟠 Feature/Aggregator"
                
            f.write(f"| {name} | {fin} | {fout} | {category} |\n")

if __name__ == "__main__":
    pkg_path = "anigma/Package.swift"
    out_path = "COMPILATION_SURFACE_AUDIT.md"
    
    modules = parse_package_swift(pkg_path)
    fan_in, fan_out = analyze_surface(modules)
    generate_report(modules, fan_in, fan_out, out_path)
    print(f"Generated report at {out_path}")
