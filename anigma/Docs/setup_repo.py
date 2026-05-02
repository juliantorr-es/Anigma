import os
import shutil
import glob

def safe_makedirs(path):
    if not os.path.exists(path):
        os.makedirs(path)
        print(f"Created {path}")

def safe_move(src, dst):
    if os.path.exists(src):
        if os.path.exists(dst) and os.path.isdir(dst):
            # If dst is a dir, move into it
            shutil.move(src, dst)
        else:
            # Rename/Move
            shutil.move(src, dst)
        print(f"Moved {src} to {dst}")
    else:
        print(f"Source {src} not found")

# 1. Create directories
dirs = [
    "App/MacApp",
    "App/LaunchAgent",
    "App/XPCService",
    "Packages",
    "Tests/MacAppTests",
    "Tests/MacAppUITests",
    "Native/CrashReporting",
    "ThirdParty",
    "Scripts",
    "Docs"
]
for d in dirs:
    safe_makedirs(d)

# 2. Move Sources/* to Packages/
sources = glob.glob("Sources/*")
for s in sources:
    safe_move(s, "Packages/")

# 3. Move Anigma/Anigma to App/MacApp
# Note: App/MacApp already exists. We want the CONTENTS of Anigma/Anigma to be in App/MacApp?
# Or we want App/MacApp to BE the source root.
# If Anigma/Anigma contains the source files (AppDelegate.swift etc), we should move them.
# Let's move Anigma/Anigma/* to App/MacApp/
if os.path.exists("Anigma/Anigma"):
    for item in os.listdir("Anigma/Anigma"):
        safe_move(os.path.join("Anigma/Anigma", item), "App/MacApp/")
    # Remove empty dir
    try:
        os.rmdir("Anigma/Anigma")
    except:
        pass

# 4. Move Anigma/AnigmaTests to Tests/MacAppTests
if os.path.exists("Anigma/AnigmaTests"):
    for item in os.listdir("Anigma/AnigmaTests"):
        safe_move(os.path.join("Anigma/AnigmaTests", item), "Tests/MacAppTests/")
    try:
        os.rmdir("Anigma/AnigmaTests")
    except:
        pass

# 5. Move Anigma/AnigmaUITests to Tests/MacAppUITests
if os.path.exists("Anigma/AnigmaUITests"):
    for item in os.listdir("Anigma/AnigmaUITests"):
        safe_move(os.path.join("Anigma/AnigmaUITests", item), "Tests/MacAppUITests/")
    try:
        os.rmdir("Anigma/AnigmaUITests")
    except:
        pass

# 6. Move Anigma.xcodeproj to App/
safe_move("Anigma.xcodeproj", "App/")

# 7. Move Anigma.xcworkspace to App/
safe_move("Anigma.xcworkspace", "App/")

# Cleanup Anigma dir if empty
if os.path.exists("Anigma") and not os.listdir("Anigma"):
    os.rmdir("Anigma")

print("Restructuring complete.")
