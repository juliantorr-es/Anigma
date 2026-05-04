import sys

with open("anigma/Package.swift", "r") as f:
    lines = f.readlines()

new_lines = []
inserted_lib = False
inserted_target = False

for line in lines:
    new_lines.append(line)
    if ".library(name: \"EvidenceContracts\"" in line and not inserted_lib:
        new_lines.append('  .library(name: "PersistenceContracts", targets: ["PersistenceContracts"]),\n')
        inserted_lib = True
    if 'name: "EvidenceContracts"' in line and not inserted_target:
        # Find the closing brace of EvidenceContracts target
        # I'll just append it after the target
        pass

# This is too complex for a script injection. 
# I will output the file to a temporary location and rebuild it or 
# accept that I must be careful with manual editing.
