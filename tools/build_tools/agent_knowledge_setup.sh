#!/bin/bash
# Agent Knowledge Database Setup Script
# Creates a hybrid knowledge system using available tools

echo "🔧 Setting up Agent Knowledge Database..."

# 1. Create knowledge base structure
mkdir -p ~/.agent_knowledge/{tools,codebase,architecture,api,workflows}

echo "✅ Knowledge base structure created"

# 2. Document all available tools
cat > ~/.agent_knowledge/tools/available_tools.md << 'TOOLS'
# Agent Tool Knowledge Base

## Core Tools

### Search & Navigation
- **ripgrep (rg)**: Fast recursive search
  - Version: 15.1.0
  - Usage: `rg "pattern"`, `rg -t swift "func"`
  - Best for: Finding code patterns across large codebases

- **fd**: Fast file search
  - Version: 10.4.2
  - Usage: `fd -e swift`, `fd "Test"`
  - Best for: Locating files by name/extension

- **fzf**: Fuzzy finder
  - Version: 0.71.0
  - Usage: `fd -e swift | fzf --preview "bat {}"`
  - Best for: Interactive file selection

### Code Viewing & Analysis
- **bat**: Better cat with syntax highlighting
  - Version: 0.26.1
  - Usage: `bat file.swift`, `bat -n`
  - Best for: Viewing files with proper syntax highlighting

- **tokei**: Code metrics
  - Version: 14.0.0
  - Usage: `tokei`
  - Best for: Codebase statistics and analysis

- **cscope**: Code navigation
  - Version: 15.9
  - Usage: `cscope -R -b -q`
  - Best for: Symbol jumping and code navigation

### Swift-Specific Tools
- **swift-format**: Code formatter
  - Version: 602.0.0
  - Usage: `swift-format format -i`, `swift-format lint`
  - Best for: Consistent code style

- **swiftlint**: Linter
  - Version: 0.63.2
  - Usage: `swiftlint lint`, `swiftlint autocorrect`
  - Best for: Catching style violations

- **sourcekitten**: Code analysis
  - Version: 0.37.3
  - Usage: `sourcekitten doc`, `sourcekitten structure`
  - Best for: Code documentation and structure analysis

### Workflow Automation
- **just**: Command runner
  - Version: 1.49.0
  - Usage: `just format`, `just analyze`
  - Recipes available: `just --list`

- **entr**: File watcher
  - Version: 5.8
  - Usage: `fd -e swift | entr -r swift test`
  - Best for: Auto-testing on file changes

- **taskwarrior**: Task management
  - Version: 3.4.2
  - Usage: `task add "Refactor module"`, `task list`
  - Best for: Tracking agent tasks

## Agent Workflow Recipes

### Code Formatting
```bash
just format
```

### Code Analysis
```bash
just analyze
```

### Pattern Search
```bash
just search pattern="search_term"
```

### Module Testing
```bash
just test module="ModuleName"
```

### Watch Mode
```bash
just watch
```

## Query Methods

### Find Files
```bash
fd -e swift | fzf --preview "bat --color=always {}"
```

### Search Code
```bash
rg "pattern" --type swift
```

### View File
```bash
bat file.swift
```

### Code Statistics
```bash
tokei
```

### Symbol Navigation
```bash
cscope -d -L "symbol_name"
```

## Configuration

All tools are configured in:
- `~/.zshrc` - Shell configurations
- `~/.fzf.zsh` - Fuzzy finder settings
- `~/.config/bat/config` - Bat theme
- `~/.cscope` - Cscope settings
- `justfile` - Project recipes
TOOLS

echo "✅ Tool documentation created"

# 3. Create codebase index script
cat > ~/.agent_knowledge/codebase/index_codebase.sh << 'INDEX'
#!/bin/bash
# Codebase Indexing Script for Agents

echo "📊 Indexing codebase for agent knowledge..."

# Generate code statistics
cd /Users/user/Developer/GitHub/Anigma_clean
echo "### Codebase Statistics" > ~/.agent_knowledge/codebase/stats.md
echo "\`\`\`" >> ~/.agent_knowledge/codebase/stats.md
tokei >> ~/.agent_knowledge/codebase/stats.md
echo "\`\`\`" >> ~/.agent_knowledge/codebase/stats.md

# Generate file structure
echo "### File Structure" >> ~/.agent_knowledge/codebase/stats.md
echo "\`\`\`" >> ~/.agent_knowledge/codebase/stats.md
fd --type f --extension swift | head -20 >> ~/.agent_knowledge/codebase/stats.md
echo "\`\`\`" >> ~/.agent_knowledge/codebase/stats.md

# Build cscope database
echo "🔍 Building cscope database..."
cscope -R -b -q -i ~/.cscope

echo "✅ Codebase indexed"
INDEX

chmod +x ~/.agent_knowledge/codebase/index_codebase.sh
echo "✅ Index script created"

# 4. Create query interface
cat > ~/.agent_knowledge/query_knowledge.sh << 'QUERY'
#!/bin/bash
# Agent Knowledge Query Interface

if [ "$#" -eq 0 ]; then
    echo "Usage: query_knowledge.sh [search_term]"
    echo "Example: query_knowledge.sh "swift-format""
    exit 1
fi

# Search across all knowledge base
rg --pretty --context 3 "$1" ~/.agent_knowledge
QUERY

chmod +x ~/.agent_knowledge/query_knowledge.sh
echo "✅ Query interface created"

# 5. Create alias for easy access
echo "" >> ~/.zshrc
echo "# Agent Knowledge Base" >> ~/.zshrc
echo "alias kb-index='~/.agent_knowledge/codebase/index_codebase.sh'" >> ~/.zshrc
echo "alias kb-query='~/.agent_knowledge/query_knowledge.sh'" >> ~/.zshrc
echo "alias kb-edit='code ~/.agent_knowledge'" >> ~/.zshrc

echo "✅ Shell aliases added"

# 6. Index codebase initially
~/.agent_knowledge/codebase/index_codebase.sh

echo ""
echo "🎉 Agent Knowledge Database Setup Complete!"
echo ""
echo "Available commands:"
echo "  kb-index   - Update codebase index"
echo "  kb-query   - Search knowledge base"
echo "  kb-edit    - Edit knowledge base"
echo ""
echo "Knowledge base location: ~/.agent_knowledge"
echo "Documentation: ~/.agent_knowledge/tools/available_tools.md"
