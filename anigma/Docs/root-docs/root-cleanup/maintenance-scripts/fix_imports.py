import os

domains = {
    "FoundationContracts": ["Foundation", "AnigmaPrimitives"],
    "GovernanceContracts": ["Foundation", "FoundationContracts", "AnigmaPrimitives"],
    "EvidenceContracts": ["Foundation", "FoundationContracts", "GovernanceContracts", "AnigmaPrimitives"],
    "IntelligenceContracts": ["Foundation", "FoundationContracts", "GovernanceContracts", "EvidenceContracts", "AnigmaPrimitives"]
}

base_path = "anigma/Packages/ContractsCore/Sources"

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
