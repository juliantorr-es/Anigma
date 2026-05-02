import re

with open('anigma/Package.swift', 'r') as f:
    content = f.read()

# We need to remove "README.md" from the exclude arrays of specific targets.
# The targets are:
# VectorIndexCapsule, DatabaseCore, AnigmaFoundation, AnigmaGovernance, AnigmaPipeline, TextPipelineCapsule, VectorCapsule, CosineSimilarityCapsule, RankFusionCapsule, MediaFingerprintCapsule, SceneGraphCapsule, TextRenderKit, MediaContainerCapsule, SidecarPDFService, AnigmaDaemonSimple

targets_to_fix = [
    "VectorIndexCapsule", "DatabaseCore", "AnigmaFoundation", "AnigmaGovernance", "AnigmaPipeline", "TextPipelineCapsule", "VectorCapsule", "CosineSimilarityCapsule", "RankFusionCapsule", "MediaFingerprintCapsule", "SceneGraphCapsule", "TextRenderKit", "MediaContainerCapsule", "SidecarPDFService", "AnigmaDaemonSimple"
]

for t in targets_to_fix:
    # Find the target block
    pattern = r'(\.target\(\s*name:\s*"' + t + r'".*?exclude:\s*\[)(.*?)(\].*?\))'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        excludes = match.group(2)
        if '"README.md"' in excludes:
            excludes = excludes.replace('"README.md",', '').replace(', "README.md"', '').replace('"README.md"', '')
            new_block = match.group(1) + excludes + match.group(3)
            content = content[:match.start()] + new_block + content[match.end():]
            
    # Also handle executableTarget
    pattern2 = r'(\.executableTarget\(\s*name:\s*"' + t + r'".*?exclude:\s*\[)(.*?)(\].*?\))'
    match2 = re.search(pattern2, content, re.DOTALL)
    if match2:
        excludes = match2.group(2)
        if '"README.md"' in excludes:
            excludes = excludes.replace('"README.md",', '').replace(', "README.md"', '').replace('"README.md"', '')
            new_block = match2.group(1) + excludes + match2.group(3)
            content = content[:match2.start()] + new_block + content[match2.end():]

with open('anigma/Package.swift', 'w') as f:
    f.write(content)
