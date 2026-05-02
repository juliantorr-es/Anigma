# Development Commands Guide

## 🚀 Start Development Environment

### Option 1: Basic Development Server
```bash
cd /Users/user/Developer/GitHub/Anigma/Docs
npm run dev
```
Starts VitePress dev server with hot reload at `http://localhost:5173`

### Option 2: Full Phase 3 Monitoring
For the complete development experience with real-time updates:

**Terminal 1 - Git Watcher:**
```bash
cd /Users/user/Developer/GitHub/Anigma/Docs
npm run watch
```

**Terminal 2 - Development Server:**
```bash
cd /Users/user/Developer/GitHub/Anigma/Docs
npm run dev
```

This gives you:
- ✅ **Automatic documentation updates** when code changes
- ✅ **Live browser reload** when documentation changes  
- ✅ **Real-time git status** display
- ✅ **Architecture validation** on changes

## 📊 Git Watcher Features

### Enhanced Status Display
The watcher now shows comprehensive git information:

```
🔍 Anigma Documentation Watcher Status
==================================================
📂 Repository: /Users/user/Developer/GitHub/Anigma
📚 Documentation: /Users/user/Developer/GitHub/Anigma/Docs
🌿 Current Branch: main
🔍 Last Commit: c918642e
👀 Watching: ✅ Active

📝 Uncommitted Changes:
   63 changes: 0 added, 13 modified, 1 deleted, 49 untracked

   🟢 Staged Changes:
     🟡 filename.swift

   🟡 Unstaged Changes:
     🟡 modified-file.js
     🟡 another-file.ts

   🔴 Untracked Files:
     ❓ new-file.md
     ❓ another-new-file.swift

📜 Recent Commits:
   c918642 Update agent instructions
   b11fc0f Phase 1: Authority & Boundaries
   6b8e947 Add comprehensive visual diagrams
```

### Git Watcher Commands
```bash
# Start watching (updates every 5 seconds)
npm run watch

# Check current status
npm run watch-status

# Force full documentation update
npm run phase3-build

# Watch with custom interval (10 seconds)
node scripts/phase3/git-watcher.js watch 10
```

## 🔧 Development Workflow

### Making Changes
1. **Make code changes** in `/Users/user/Developer/GitHub/Anigma/Sources/`
2. **Git watcher detects** changes within 5 seconds
3. **Documentation auto-updates** for affected modules
4. **Browser reloads** automatically with new content
5. **Architecture validation** runs on each update

### Status Indicators
- 🟢 **Staged**: Changes ready to commit
- 🟡 **Modified**: Changes not staged yet  
- 🔴 **Untracked**: New files not in git
- ❓ **Unknown**: File status unclear

### Branch Information
- Shows current branch and tracking status
- Displays ahead/behind info (↑↓)
- Lists all available branches

## 🏗️ Build Commands

### Development Builds
```bash
# Quick incremental build
npm run incremental-update <module1> <module2>

# Full Phase 3 build with validation
npm run phase3-build

# Generate specific content
npm run generate-diagrams          # Basic architecture diagrams
npm run generate-enhanced-modules     # Module relationship diagrams  
npm run generate-module-docs         # Dynamic documentation
npm run validate                    # Architecture validation
```

### Build Cache Management
```bash
# Show cache statistics
npm run incremental-update stats

# Clear build cache
npm run incremental-update clear

# Force rebuild of specific modules
npm run incremental-update HarmoniaModule DiaplasionModule
```

## 📱 Accessing Documentation

### Local Development
- **URL**: http://localhost:5173
- **Hot Reload**: Automatic on file changes
- **Full Interactivity**: All Vue components enabled

### Key Pages
- **Home**: `/` - Project overview
- **Module Explorer**: `/architecture/module-explorer` - Interactive module browser
- **Phase 3 Dashboard**: `/architecture/phase3` - Health monitoring
- **Architecture Issues**: `/ARCHITECTURE_ISSUES_REPORT.html` - Detailed issue report

## 🔍 Architecture Monitoring

### Health Dashboard
- **Real-time Score**: Current architecture health (82/100)
- **Issue Tracking**: Live validation results
- **Trend Analysis**: Health over time
- **Export Reports**: Download detailed analysis

### Validation Results
- **Critical Issues**: 4 found (capability dependencies, circular imports)
- **Warnings**: 47 improvement opportunities
- **Categories**: ECS patterns, naming conventions, module structure
- **Recommendations**: Specific actionable fixes

## 🚨 Troubleshooting

### Common Issues

**Dev server won't start:**
```bash
# Clear VitePress cache
rm -rf .vitepress/cache
rm -rf .vitepress/dist

# Restart dev server
npm run dev
```

**Git watcher errors:**
```bash
# Check git repository status
git status

# Ensure you're in the right directory
pwd  # Should be /Users/user/Developer/GitHub/Anigma/Docs
```

**Build failures:**
```bash
# Check Node.js version
node --version  # Should be 18+

# Clear build cache
npm run incremental-update clear

# Force full rebuild
npm run phase3-build
```

**Port conflicts:**
```bash
# Kill existing processes
pkill -f vitepress
pkill -f node

# Try different port
npx vitepress dev --port 3000
```

### Performance Tips

**Faster Development:**
- Use incremental builds for specific modules
- Enable git watcher for automatic updates
- Keep build cache for faster rebuilds

**Memory Usage:**
- Stop watcher when not needed: `Ctrl+C`
- Clear cache periodically: `npm run incremental-update clear`
- Use status command instead of full watcher

## 📋 Quick Reference

| Command | Purpose | When to Use |
|---------|----------|--------------|
| `npm run dev` | Start dev server | Basic development |
| `npm run watch` | Start git monitoring | Full Phase 3 experience |
| `npm run watch-status` | Show git status | Quick status check |
| `npm run validate` | Run architecture validation | Check code quality |
| `npm run phase3-build` | Full build + validation | Before commits |
| `npm run clean` | Clean all generated files | Fresh start |

## 🎯 Best Practices

### Development Workflow
1. **Start both services** (`npm run watch` + `npm run dev`)
2. **Make changes** to source code
3. **Watch for auto-updates** in terminal
4. **Check browser** for refreshed content
5. **Review validation** results in health dashboard
6. **Commit changes** when satisfied

### Before Committing
```bash
# Run full validation
npm run phase3-build

# Check architecture health
npm run validate

# Review uncommitted changes
npm run watch-status
```

### Regular Maintenance
```bash
# Weekly: Clean and rebuild
npm run clean
npm run phase3-build

# Monthly: Review architecture issues
cat data/validation-report.json
```

This setup provides a complete development environment with real-time monitoring, automatic updates, and comprehensive architecture validation.

## Key Constraints

- **Native Library Governance**: All native dependencies must follow [Native Library Lifecycle Governance](governance/NATIVE-LIBRARY-LIFECYCLE.md) with mandatory intake contracts, distribution compliance, and operational monitoring
- **Security First**: Native libraries are treated as attack surfaces requiring sandboxing, verification, and continuous vulnerability monitoring
- **Legal Compliance**: Every native dependency requires license compatibility review and attribution management
- **Operational Stability**: Native dependencies are liabilities that require reproducible builds and distribution verification
- **Swift only** for runtime code
- **No Python/Node** as runtime dependencies
- **No AGPL/GPL** code
- **Single ECS** in AnigmaCore (modules extend, not replace)
- **JS/TS** allowed only for build-time tools producing static assets

See [Constitution](/AnigmaConstitution) for full set of rules.

## Current Code Status

- **HarmoniaModule** delivers deterministic governance surface: security policies in `Sources/HarmoniaModule/Security`, ML worker dispatcher in `Sources/HarmoniaModule/Systems/MLWorkerDispatchSystem.swift`, and Accessum/diaplasion orchestration systems under `Sources/HarmoniaModule/Systems`.
- **DiaplasionModule** provides ingest→OCR→normalize pipeline described by `Scripts/run_diaplasion_pipeline.sh`, which operates on `Sources/DiaplasionModule/TestFiles/diaplasion-happy` fixtures and emits searchable PDFs, normalized text, and `trace.json` artifacts under `Artifacts/diaplasion/<pipelineVersion>/<inputHash>/`.
- **AccessumFlow** (see `Scripts/run_accessum_flow.sh` and `Sources/AccessumFlow` product) orchestrates Diaplasion and Outlineum, writes the shared CLI envelope to stdout, persists run/step records under `Artifacts/accessum/{runId}/trace.json`, and powers admin surface `accessum flow admin` plus daemon packaging guidance in `Docs/phase5/accessum-daemon`.
- **OutlineumModule** runs deterministic zine pipeline reachable via `Scripts/run_zine_pipeline.sh`, which reads `Sources/OutlineumModule/TestFiles/zine-minimal`, builds `outlineum-zine`, and outputs PDFs plus provenance metadata into `Artifacts/outlineum/zine/{pipelineVersion>/<inputHash>/`.
- **ML worker infrastructure** lives in `Sources/MLWorkerCommon`, `Sources/MLWorkerExecutable`, and supervisor systems in `HarmoniaModule`; it treats embeddings/results as artifacts with ledger-backed hashes for replay.
- Status and governance truth live in `Docs/status/status.json` and VitePress `ProjectStatus` widget, which now reports Sigma Phase 5, Accessum ledger/admin story, and `docs last updated` stamp derived from git history.

