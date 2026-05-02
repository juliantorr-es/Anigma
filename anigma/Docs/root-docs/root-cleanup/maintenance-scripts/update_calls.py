#!/usr/bin/env python3

# Script to update the generateReceipt calls in BookAssemblerCapsule

file_path = 'anigma/Packages/BookAssemblerCapsule/Sources/BookAssemblerCapsule/BookAssemblerCapsule.swift'

with open(file_path, 'r') as f:
    content = f.read()

# Update the first call to generateReceipt (line 87)
old_call1 = '''                let receipt = try generateReceipt(
                    chunkSet: chunkSet,
                    manifest: manifest,
                    bookDocIR: cached,
                    errors: [],
                    fromCache: true
                )'''

new_call1 = '''                let receipt = try generateReceipt(
                    chunkSet: chunkSet,
                    manifest: manifest,
                    bookDocIR: cached,
                    errors: [],
                    fromCache: true,
                    layoutAnalysis: layoutAnalysis
                )'''

content = content.replace(old_call1, new_call1)

# Update the second call to generateReceipt (line 146)
old_call2 = '''            let receipt = try generateReceipt(
                chunkSet: chunkSet,
                manifest: manifest,
                bookDocIR: bookDocIR,
                errors: processingErrors,
                fromCache: false
            )'''

new_call2 = '''            let receipt = try generateReceipt(
                chunkSet: chunkSet,
                manifest: manifest,
                bookDocIR: bookDocIR,
                errors: processingErrors,
                fromCache: false,
                layoutAnalysis: layoutAnalysis
            )'''

content = content.replace(old_call2, new_call2)

with open(file_path, 'w') as f:
    f.write(content)

print("Successfully updated generateReceipt calls")
