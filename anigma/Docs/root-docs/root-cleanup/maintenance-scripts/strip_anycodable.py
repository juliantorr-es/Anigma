import os
import re

files_to_edit = {
    "anigma/Packages/DocumentIRKit/Sources/DocumentIRKit/DocumentIRNode.swift": {
        "pattern": r"/// Type-erased codable for heterogeneous property dictionaries\npublic enum AnyCodable: Codable, Sendable, Equatable \{.*?\n\}\n",
        "replacement": "import AnigmaPrimitives\n",
        "import_stmt": "import AnigmaPrimitives"
    },
    "anigma/Packages/ContainerKit/Sources/ContainerKit/ContainerModels.swift": {
        "pattern": r"/// Type-erased codable for heterogeneous property dictionaries\npublic enum AnyCodable: Codable, Sendable, Equatable \{.*?\n\}\n",
        "replacement": "import AnigmaPrimitives\n",
        "import_stmt": "import AnigmaPrimitives"
    },
    "anigma/Packages/HarmoniaWorkflowContracts/Sources/HarmoniaWorkflowContracts/WorkflowModels.swift": {
        "pattern": r"public enum AnyCodable: Codable, Sendable \{.*?\n\}\n",
        "replacement": "import AnigmaPrimitives\n",
        "import_stmt": "import AnigmaPrimitives"
    },
    "anigma/Packages/AnigmaCore/Sources/AnigmaCore/Sync/SyncInfrastructure.swift": {
        "pattern": r"/// Type-erased codable value for sync fields\.\npublic enum AnyCodableValue: Codable, Sendable, Equatable \{.*?\n\}\n",
        "replacement": "import AnigmaPrimitives\n\npublic typealias AnyCodableValue = AnyCodable\n",
        "import_stmt": "import AnigmaPrimitives"
    }
}

for path, info in files_to_edit.items():
    with open(path, "r") as f:
        content = f.read()
    
    # Check if already has import
    if info["import_stmt"] not in content:
        # Add import at the top
        content = content.replace("import Foundation\n", f"import Foundation\n{info['import_stmt']}\n", 1)
        
    new_content = re.sub(info["pattern"], info["replacement"], content, flags=re.DOTALL)
    
    with open(path, "w") as f:
        f.write(new_content)
    print(f"Processed {path}")
