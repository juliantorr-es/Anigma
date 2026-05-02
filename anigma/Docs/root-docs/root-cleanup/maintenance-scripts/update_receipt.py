#!/usr/bin/env python3

# Script to update the generateReceipt function in BookAssemblerCapsule

file_path = 'anigma/Packages/BookAssemblerCapsule/Sources/BookAssemblerCapsule/BookAssemblerCapsule.swift'

with open(file_path, 'r') as f:
    content = f.read()

# Find and replace the generateReceipt function signature
old_signature = '''    private func generateReceipt(
        chunkSet: ChunkSet,
        manifest: BookProjectManifest,
        bookDocIR: BookDocIR,
        errors: [AssemblyError],
        fromCache: Bool
    ) throws -> CapsuleReceipt {'''

new_signature = '''    private func generateReceipt(
        chunkSet: ChunkSet,
        manifest: BookProjectManifest,
        bookDocIR: BookDocIR,
        errors: [AssemblyError],
        fromCache: Bool,
        layoutAnalysis: LayoutAnalysisResult? = nil
    ) throws -> CapsuleReceipt {'''

content = content.replace(old_signature, new_signature)

# Find and replace the receipt generation to include layout information
old_metadata = '''                "chunk_count": chunkSet.chunks.count,
                "node_count": bookDocIR.allNodeIDs.count,
                "error_count": errors.count,
                "from_cache": fromCache,
                "config_hash": configHash(),
                "chapter_count": bookDocIR.chapters.count,
                "front_matter_count": bookDocIR.frontMatter.count,
                "back_matter_count": bookDocIR.backMatter.count'''

new_metadata = '''                "chunk_count": chunkSet.chunks.count,
                "node_count": bookDocIR.allNodeIDs.count,
                "error_count": errors.count,
                "from_cache": fromCache,
                "config_hash": configHash(),
                "chapter_count": bookDocIR.chapters.count,
                "front_matter_count": bookDocIR.frontMatter.count,
                "back_matter_count": bookDocIR.backMatter.count,
                "layout_analyzed": layoutAnalysis != nil,
                "header_count": layoutAnalysis?.headers.count ?? 0,
                "table_count": layoutAnalysis?.tables.count ?? 0,
                "figure_count": layoutAnalysis?.figures.count ?? 0'''

content = content.replace(old_metadata, new_metadata)

with open(file_path, 'w') as f:
    f.write(content)

print("Successfully updated generateReceipt function")
