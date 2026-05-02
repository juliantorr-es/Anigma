# Git Commit and Push Guide

This document provides instructions for committing and pushing the build fixes to your main branch.

## Table of Contents
1. [Pre-Commit Checklist](#pre-commit-checklist)
2. [Verify Changes](#verify-changes)
3. [Commit Strategy](#commit-strategy)
4. [Push to Remote](#push-to-remote)
5. [Alternative: Feature Branch Approach](#alternative-feature-branch-approach)

---

## Pre-Commit Checklist

Before committing, ensure everything is working:

### ✅ Step 1: Clean Build
```bash
cd /path/to/anigma
swift package clean
swift build
```

**Expected Result:** Build completes successfully with 0 errors and significantly fewer warnings.

### ✅ Step 2: Run Tests (Optional but Recommended)
```bash
swift test
```

**Expected Result:** All tests pass (or same test results as before the fixes).

### ✅ Step 3: Verify All Changes
Check what files have been modified:
```bash
git status
```

You should see:
- Modified Swift source files (PipelineRunner.swift, DatabaseActor files, MakerEngine.swift, etc.)
- New module.modulemap files
- New BUILD_FIXES.md file
- Any other files you've touched

---

## Verify Changes

Before committing, review your changes to make sure everything looks correct:

### View All Changes
```bash
git diff
```

### View Specific File Changes
```bash
# Example: Review PipelineRunner changes
git diff Sources/AnigmaCore/Pipeline/PipelineRunner.swift

# Example: Review DatabaseActor changes
git diff Sources/DatabaseCore/DatabaseActor+LedgerSegmentation.swift
```

### Check New Files
```bash
git status --short
```

Files marked with `??` are new and need to be added:
```
?? BUILD_FIXES.md
?? Packages/TableExtractionCapsule/Native/include/module.modulemap
?? Packages/MathOCRCapsule/Native/include/module.modulemap
?? Packages/CitationExtractionCapsule/Native/include/module.modulemap
?? Packages/ReferenceResolutionCapsule/Native/include/module.modulemap
?? Packages/DiffCapsule/Native/include/module.modulemap
```

---

## Commit Strategy

You have two main options for organizing your commits:

### Option A: Single Comprehensive Commit (Recommended for Quick Fixes)

**Best for:** When all changes are related and you want to push quickly.

```bash
# Stage all changes
git add -A

# Create a descriptive commit
git commit -m "Fix build warnings and errors

- Remove 'convenience' keyword from PipelineRunner actor initializer (Swift 6 compatibility)
- Remove unnecessary 'await' keywords from synchronous DatabaseCore execute() calls
- Fix unused variable warnings in DatabaseCore and AnigmaCore
- Fix unreachable default case in ReflexiveAnalytics
- Add module.modulemap files for native C/C++ capsule interop
- Add BUILD_FIXES.md documentation"
```

### Option B: Multiple Focused Commits (Recommended for Better History)

**Best for:** When you want clear, traceable history for each type of fix.

#### Commit 1: Add Module Maps
```bash
git add Packages/*/Native/include/module.modulemap
git commit -m "Add module.modulemap files for native capsule interop

- TableExtractionCapsule
- MathOCRCapsule
- CitationExtractionCapsule
- ReferenceResolutionCapsule
- DiffCapsule

These module maps expose C/C++ headers to Swift for proper interoperability."
```

#### Commit 2: Fix Critical Swift 6 Issue
```bash
git add Sources/AnigmaCore/Pipeline/PipelineRunner.swift
git commit -m "Fix: Remove 'convenience' keyword from PipelineRunner actor initializer

The 'convenience' keyword is not allowed on actor initializers in Swift 6.
This change ensures forward compatibility with the Swift 6 language mode."
```

#### Commit 3: Fix DatabaseCore Warnings
```bash
git add Sources/DatabaseCore/DatabaseActor+LedgerSegmentation.swift
git add Sources/DatabaseCore/DatabaseActor+Maintenance.swift
git add Sources/DatabaseCore/DatabaseActor+GarbageCollection.swift
git add Sources/DatabaseCore/DatabaseActor+MasterLedger.swift
git commit -m "Fix: Remove unnecessary 'await' keywords from synchronous execute() calls

The execute() method in DatabaseActor is synchronous but was being
called with 'await', causing compiler warnings. Also fixed unused
variable warnings in DatabaseActor+MasterLedger.swift."
```

#### Commit 4: Fix AnigmaCore Warnings
```bash
git add Sources/AnigmaCore/Reasoning/MakerEngine.swift
git add Sources/AnigmaCore/Analytics/ReflexiveAnalytics.swift
git commit -m "Fix: Address unused variable and unreachable code warnings

- MakerEngine: Fix unused variable bindings
- ReflexiveAnalytics: Remove unreachable default case"
```

#### Commit 5: Add Documentation
```bash
git add BUILD_FIXES.md
git commit -m "docs: Add comprehensive build fixes documentation

Added BUILD_FIXES.md with detailed instructions for addressing
all build warnings and errors, including:
- Swift 6 compatibility issues
- Database actor warnings
- Unused variable warnings
- Module map setup"
```

---

## Push to Remote

### Step 1: Ensure You're on Main Branch
```bash
git branch
```

The current branch will have an asterisk (*). If you're not on main:
```bash
git checkout main
```

### Step 2: Pull Latest Changes (Important!)
Before pushing, make sure you have the latest remote changes:
```bash
git pull origin main --rebase
```

**Why `--rebase`?** This keeps your commit history cleaner by replaying your commits on top of the remote changes.

**If there are conflicts:**
1. Git will tell you which files have conflicts
2. Open the conflicted files and resolve them
3. After resolving:
   ```bash
   git add <resolved-files>
   git rebase --continue
   ```

### Step 3: Push to Remote
```bash
git push origin main
```

**Expected Output:**
```
Enumerating objects: X, done.
Counting objects: 100% (X/X), done.
Delta compression using up to Y threads
Compressing objects: 100% (Z/Z), done.
Writing objects: 100% (W/W), A KiB | B MiB/s, done.
Total W (delta V), reused U (delta T), pack-reused 0
To github.com:your-org/anigma.git
   abc1234..def5678  main -> main
```

---

## Alternative: Feature Branch Approach

If you want to be extra careful and review changes before merging to main:

### Step 1: Create Feature Branch
```bash
# Make sure you're on main first
git checkout main

# Create and switch to a new branch
git checkout -b fix/build-warnings
```

### Step 2: Commit Your Changes
Use either Option A or Option B from the [Commit Strategy](#commit-strategy) section above.

### Step 3: Push Feature Branch
```bash
git push origin fix/build-warnings
```

### Step 4: Create Pull Request
1. Go to your repository on GitHub/GitLab/etc.
2. You should see a prompt to create a Pull Request for `fix/build-warnings`
3. Click "Create Pull Request"
4. Add a description:

```markdown
## Changes

This PR fixes all build warnings and errors:

### Critical Fixes
- Removed `convenience` keyword from PipelineRunner actor initializer for Swift 6 compatibility

### Warning Fixes
- Removed 30+ unnecessary `await` keywords from synchronous DatabaseCore execute() calls
- Fixed unused variable warnings in DatabaseCore and AnigmaCore
- Fixed unreachable default case in ReflexiveAnalytics

### Infrastructure
- Added module.modulemap files for native C/C++ capsule interop
- Added comprehensive BUILD_FIXES.md documentation

### Testing
- ✅ Build completes successfully with 0 errors
- ✅ Warnings reduced from 30+ to 0 (or minimal)
- ✅ All tests pass (if applicable)

## Files Changed
- 7 Swift source files
- 5 new module.modulemap files
- 1 new documentation file
```

5. Review the changes in the PR interface
6. Merge the PR when ready

### Step 5: Update Local Main
After merging the PR:
```bash
git checkout main
git pull origin main
```

---

## Post-Push Verification

After pushing to remote, verify everything worked:

### Check Remote Repository
1. Visit your repository on GitHub/GitLab
2. Navigate to the main branch
3. Verify all commits are visible
4. Check that all files are present

### Verify CI/CD (if applicable)
If you have CI/CD pipelines:
1. Check that the build pipeline runs
2. Verify all tests pass
3. Ensure no new warnings or errors appear

---

## Common Issues and Solutions

### Issue 1: Push Rejected (Remote has Changes)
```
! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'origin'
```

**Solution:**
```bash
git pull origin main --rebase
# Resolve any conflicts if they occur
git push origin main
```

### Issue 2: Accidentally Pushed to Wrong Branch
```bash
# If you pushed to main but meant to push to a feature branch
git checkout main
git reset --hard origin/main~1  # Go back one commit on local
git checkout -b fix/build-warnings
git cherry-pick HEAD@{1}  # Get your commit back
git push origin fix/build-warnings
```

### Issue 3: Want to Undo Last Commit (Before Pushing)
```bash
# Undo the last commit but keep the changes
git reset --soft HEAD~1

# Undo the last commit and discard changes (CAREFUL!)
git reset --hard HEAD~1
```

### Issue 4: Already Pushed but Need to Fix Something
**DO NOT** use `git push --force` on main unless absolutely necessary and you're sure no one else is working on it.

**Better approach:**
1. Make a new commit with the fix
2. Push the new commit

```bash
# Make your fixes
git add <files>
git commit -m "Fix: Address issue in previous commit"
git push origin main
```

---

## Recommended Git Configuration

For better commit messages and workflow:

```bash
# Use Vim/Nano/VS Code for commit messages
git config --global core.editor "code --wait"  # For VS Code
# or
git config --global core.editor "vim"

# Enable color output
git config --global color.ui auto

# Set default push behavior
git config --global push.default simple

# Enable rerere (reuse recorded resolution)
git config --global rerere.enabled true
```

---

## Best Practices

### ✅ Do:
- **Write descriptive commit messages** - Explain what and why, not just what
- **Test before pushing** - Ensure build succeeds and tests pass
- **Pull before pushing** - Always sync with remote first
- **Use conventional commits** - Prefix with `fix:`, `feat:`, `docs:`, etc.
- **Review your changes** - Use `git diff` before committing

### ❌ Don't:
- **Don't commit commented-out code** - Remove it or explain why it's there
- **Don't commit secrets** - API keys, passwords, etc. (use .gitignore)
- **Don't force push to main** - Unless you're absolutely sure
- **Don't commit large binary files** - Use Git LFS if needed
- **Don't commit build artifacts** - Add them to .gitignore

---

## Example Complete Workflow

Here's a complete example using the single commit approach:

```bash
# 1. Verify you're on main and up to date
git checkout main
git pull origin main --rebase

# 2. Verify build works
swift package clean
swift build
# ✅ Build successful

# 3. Check what changed
git status
git diff

# 4. Stage all changes
git add -A

# 5. Commit with descriptive message
git commit -m "Fix build warnings and errors

- Remove 'convenience' keyword from PipelineRunner actor initializer (Swift 6 compatibility)
- Remove unnecessary 'await' keywords from synchronous DatabaseCore execute() calls
- Fix unused variable warnings in DatabaseCore and AnigmaCore
- Fix unreachable default case in ReflexiveAnalytics
- Add module.modulemap files for native C/C++ capsule interop
- Add BUILD_FIXES.md documentation

Resolves all build warnings and ensures Swift 6 compatibility."

# 6. Verify commit looks good
git log -1 --stat

# 7. Push to remote
git push origin main

# 8. Verify on remote repository
# Visit GitHub/GitLab and check the commit
```

---

## Quick Command Reference

```bash
# View status
git status
git status --short

# View changes
git diff                              # All unstaged changes
git diff --staged                     # All staged changes
git diff <file>                       # Specific file

# Stage changes
git add <file>                        # Specific file
git add .                             # Current directory
git add -A                            # All changes

# Commit
git commit -m "message"               # With inline message
git commit                            # Opens editor for message
git commit --amend                    # Modify last commit

# View history
git log                               # Full log
git log --oneline                     # Compact log
git log -1 --stat                     # Last commit with stats

# Sync with remote
git pull origin main --rebase         # Pull with rebase
git push origin main                  # Push to main
git push origin <branch>              # Push to branch

# Branch operations
git branch                            # List branches
git checkout <branch>                 # Switch branch
git checkout -b <branch>              # Create and switch

# Undo operations
git reset --soft HEAD~1               # Undo last commit, keep changes
git reset --hard HEAD~1               # Undo last commit, discard changes
git checkout -- <file>                # Discard changes in file
```

---

**Document Version:** 1.0  
**Last Updated:** February 6, 2026  
**Project:** Anigma  

