import os

domains = {
    "AnigmaFoundation": ["Foundation", "AnigmaPrimitives", "ContractsCore"],
    "AnigmaGovernance": ["Foundation", "AnigmaFoundation", "AnigmaPrimitives", "GovernanceCore"],
    "AnigmaJobs": ["Foundation", "AnigmaFoundation", "AnigmaGovernance", "AnigmaPrimitives"],
    "AnigmaPipeline": ["Foundation", "AnigmaFoundation", "AnigmaGovernance", "AnigmaJobs", "AnigmaPrimitives", "ContractsCore", "InferenceCore"],
    "HarmoniaCore": ["Foundation", "AnigmaCore", "AnigmaPrimitives"],
    "HarmoniaSecurity": ["Foundation", "HarmoniaCore", "AnigmaCore", "AnigmaPrimitives", "DoctrineCore"],
    "HarmoniaInference": ["Foundation", "HarmoniaCore", "AnigmaCore", "AnigmaPrimitives", "InferenceCore"],
    "HarmoniaServices": ["Foundation", "HarmoniaCore", "HarmoniaSecurity", "HarmoniaInference", "AnigmaCore", "AnigmaPrimitives"]
}

base_paths = ["anigma/Packages/AnigmaCore/Sources", "anigma/Packages/HarmoniaModule/Sources"]

for base_path in base_paths:
    for domain, imports in domains.items():
        domain_path = os.path.join(base_path, domain)
        if not os.path.exists(domain_path):
            continue
            
        for root, _, files in os.walk(domain_path):
            for file in files:
                if not file.endswith(".swift"):
                    continue
                
                path = os.path.join(root, file)
                with open(path, "r") as f:
                    lines = f.readlines()
                
                # Find existing imports
                existing_imports = {line.strip() for line in lines if line.startswith("import ")}
                
                new_imports = []
                for imp in imports:
                    stmt = f"import {imp}"
                    # Avoid self-import
                    if imp == domain:
                        continue
                    if stmt not in existing_imports:
                        new_imports.append(stmt + "\n")
                
                if new_imports:
                    # Insert after the first comment block or at the top
                    insert_idx = 0
                    for i, line in enumerate(lines):
                        if not line.startswith("//") and line.strip() != "":
                            insert_idx = i
                            break
                    
                    # Check if we should insert before existing imports
                    for i, line in enumerate(lines):
                        if line.startswith("import "):
                            insert_idx = i
                            break
                    
                    for imp in reversed(new_imports):
                        lines.insert(insert_idx, imp)
                    
                    with open(path, "w") as f:
                        f.writelines(lines)
                    print(f"Fixed imports in {path}")
