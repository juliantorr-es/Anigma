#!/usr/bin/env python3

# Script to update the cache key calculation in BookAssemblerCapsule

file_path = 'anigma/Packages/BookAssemblerCapsule/Sources/BookAssemblerCapsule/BookAssemblerCapsule.swift'

with open(file_path, 'r') as f:
    lines = f.readlines()

# Replace line 80 (index 79) with the new cache key calculation
lines[79] = '            let layoutHash = layoutAnalysis?.contentHash ?? "no-layout"\n'
lines.insert(80, '            let cacheKey = "\(manifest.id)-$chunkSet.contentHash)-$layoutHash)"\n')

with open(file_path, 'w') as f:
    f.writelines(lines)

print("Successfully updated cache key calculation in BookAssemblerCapsule.swift")
