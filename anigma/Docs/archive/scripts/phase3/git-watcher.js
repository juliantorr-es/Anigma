#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class GitWatcher {
  constructor(repoPath, docsPath) {
    this.repoPath = repoPath;
    this.docsPath = docsPath;
    this.lastCommit = this.getCurrentCommit();
    this.isWatching = false;
    this.watchInterval = null;
  }

  getCurrentCommit() {
    try {
      const result = execSync('git rev-parse HEAD', { 
        cwd: this.repoPath, 
        encoding: 'utf8' 
      }).trim();
      return result;
    } catch (error) {
      console.error('Error getting current commit:', error.message);
      return null;
    }
  }

  getCurrentBranch() {
    try {
      const result = execSync('git rev-parse --abbrev-ref HEAD', { 
        cwd: this.repoPath, 
        encoding: 'utf8' 
      }).trim();
      return result;
    } catch (error) {
      console.error('Error getting current branch:', error.message);
      return 'unknown';
    }
  }

  getUncommittedChanges() {
    try {
      // Get status of all files
      const statusResult = execSync('git status --porcelain', { 
        cwd: this.repoPath, 
        encoding: 'utf8' 
      }).trim();
      
      if (!statusResult) {
        return { files: [], summary: 'No uncommitted changes' };
      }

      const lines = statusResult.split('\n');
      const files = [];
      let added = 0, modified = 0, deleted = 0, renamed = 0, untracked = 0;

      lines.forEach(line => {
        const statusCode = line.substring(0, 2);
        const filePath = line.substring(3);
        
        let status = 'unknown';
        let category = '';
        
        if (statusCode === '??') {
          status = 'untracked';
          category = 'untracked';
          untracked++;
        } else if (statusCode[0] === 'A' || statusCode[1] === 'A') {
          status = 'added';
          category = 'staged';
          added++;
        } else if (statusCode[0] === 'M' || statusCode[1] === 'M') {
          status = 'modified';
          category = statusCode[0] === ' ' ? 'unstaged' : 'staged';
          modified++;
        } else if (statusCode[0] === 'D' || statusCode[1] === 'D') {
          status = 'deleted';
          category = statusCode[0] === ' ' ? 'unstaged' : 'staged';
          deleted++;
        } else if (statusCode[0] === 'R' || statusCode[1] === 'R') {
          status = 'renamed';
          category = 'staged';
          renamed++;
        }

        files.push({
          path: filePath,
          status,
          category,
          statusCode
        });
      });

      const total = added + modified + deleted + renamed + untracked;
      const summary = total > 0 
        ? `${total} changes: ${added} added, ${modified} modified, ${deleted} deleted, ${renamed} renamed, ${untracked} untracked`
        : 'No uncommitted changes';

      return { files, summary, stats: { added, modified, deleted, renamed, untracked, total } };
    } catch (error) {
      console.error('Error getting uncommitted changes:', error.message);
      return { files: [], summary: 'Error getting status' };
    }
  }

  getBranchInfo() {
    try {
      const currentBranch = this.getCurrentBranch();
      
      // Get all branches
      const allBranchesResult = execSync('git branch -a', { 
        cwd: this.repoPath, 
        encoding: 'utf8' 
      }).trim();
      
      const branches = allBranchesResult.split('\n').map(branch => {
        const isCurrent = branch.startsWith('* ');
        return {
          name: branch.replace(/^\* /, '').replace('remotes/origin/', ''),
          current: isCurrent
        };
      });

      // Get ahead/behind info for current branch
      let aheadBehind = '';
      try {
        const trackingInfo = execSync('git rev-list --count --left-right @{upstream}...HEAD', { 
          cwd: this.repoPath, 
          encoding: 'utf8' 
        }).trim();
        
        if (trackingInfo) {
          const [behind, ahead] = trackingInfo.split('\t');
          if (ahead > 0 && behind > 0) {
            aheadBehind = `↑${ahead} ↓${behind}`;
          } else if (ahead > 0) {
            aheadBehind = `↑${ahead}`;
          } else if (behind > 0) {
            aheadBehind = `↓${behind}`;
          }
        }
      } catch (error) {
        // No upstream branch or other error
      }

      return {
        current: currentBranch,
        branches,
        aheadBehind
      };
    } catch (error) {
      console.error('Error getting branch info:', error.message);
      return { current: 'unknown', branches: [], aheadBehind: '' };
    }
  }

  displayStatus() {
    console.clear();
    console.log('🔍 Anigma Documentation Watcher Status');
    console.log('='.repeat(50));
    
    const branchInfo = this.getBranchInfo();
    const uncommitted = this.getUncommittedChanges();
    
    console.log(`📂 Repository: ${this.repoPath}`);
    console.log(`📚 Documentation: ${this.docsPath}`);
    console.log(`🌿 Current Branch: ${branchInfo.current}${branchInfo.aheadBehind ? ` (${branchInfo.aheadBehind})` : ''}`);
    console.log(`🔍 Last Commit: ${this.lastCommit ? this.lastCommit.substring(0, 8) : 'Unknown'}`);
    console.log(`👀 Watching: ${this.isWatching ? '✅ Active' : '❌ Inactive'}`);
    console.log('');
    
    // Display uncommitted changes
    console.log('📝 Uncommitted Changes:');
    console.log(`   ${uncommitted.summary}`);
    
    if (uncommitted.files.length > 0) {
      // Group by category
      const staged = uncommitted.files.filter(f => f.category === 'staged');
      const unstaged = uncommitted.files.filter(f => f.category === 'unstaged');
      const untracked = uncommitted.files.filter(f => f.category === 'untracked');
      
      if (staged.length > 0) {
        console.log('\n   🟢 Staged Changes:');
        staged.forEach(file => {
          const icon = this.getStatusIcon(file.status);
          console.log(`     ${icon} ${file.path}`);
        });
      }
      
      if (unstaged.length > 0) {
        console.log('\n   🟡 Unstaged Changes:');
        unstaged.forEach(file => {
          const icon = this.getStatusIcon(file.status);
          console.log(`     ${icon} ${file.path}`);
        });
      }
      
      if (untracked.length > 0) {
        console.log('\n   🔴 Untracked Files:');
        untracked.forEach(file => {
          console.log(`     ❓ ${file.path}`);
        });
      }
    }
    
    console.log('');
    
    // Display recent commits
    try {
      const recentCommits = execSync('git log --oneline -5', { 
        cwd: this.repoPath, 
        encoding: 'utf8' 
      }).trim();
      
      console.log('📜 Recent Commits:');
      recentCommits.split('\n').forEach(commit => {
        console.log(`   ${commit}`);
      });
    } catch (error) {
      console.log('   Could not fetch recent commits');
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('Press Ctrl+C to stop watching');
  }

  getStatusIcon(status) {
    const icons = {
      'added': '🟢',
      'modified': '🟡', 
      'deleted': '🔴',
      'renamed': '🔄',
      'untracked': '❓'
    };
    return icons[status] || '❓';
  }

  getChangedFiles(sinceCommit) {
    try {
      const result = execSync(`git diff --name-only ${sinceCommit} HEAD`, { 
        cwd: this.repoPath, 
        encoding: 'utf8' 
      }).trim();
      
      return result ? result.split('\n').filter(file => file.length > 0) : [];
    } catch (error) {
      console.error('Error getting changed files:', error.message);
      return [];
    }
  }

  getChangedModules(changedFiles) {
    const modules = new Set();
    
    changedFiles.forEach(file => {
      if (file.startsWith('Sources/')) {
        const parts = file.split('/');
        if (parts.length > 2) {
          modules.add(parts[1]);
        }
      }
    });
    
    return Array.from(modules);
  }

  async updateModuleDocumentation(moduleName) {
    console.log(`📝 Updating documentation for module: ${moduleName}`);
    
    try {
      // Regenerate module documentation
      execSync(`node scripts/generate-module-docs.js`, { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      // Regenerate enhanced diagrams
      execSync(`node scripts/generate-enhanced-modules.js`, { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      console.log(`✅ Updated documentation for ${moduleName}`);
      return true;
    } catch (error) {
      console.error(`❌ Failed to update ${moduleName}:`, error.message);
      return false;
    }
  }

  async rebuildSite() {
    console.log('🔄 Rebuilding documentation site...');
    
    try {
      execSync('npm run build', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      console.log('✅ Site rebuilt successfully');
      return true;
    } catch (error) {
      console.error('❌ Failed to rebuild site:', error.message);
      return false;
    }
  }

  async checkForChanges() {
    const currentCommit = this.getCurrentCommit();
    
    if (!currentCommit || currentCommit === this.lastCommit) {
      return;
    }

    console.log(`🔄 Detected changes: ${this.lastCommit} → ${currentCommit}`);
    
    const changedFiles = this.getChangedFiles(this.lastCommit);
    const changedModules = this.getChangedModules(changedFiles);
    
    console.log(`📁 Changed files: ${changedFiles.length}`);
    console.log(`📦 Affected modules: ${changedModules.join(', ')}`);
    
    if (changedModules.length > 0) {
      // Update documentation for changed modules
      let successCount = 0;
      for (const module of changedModules) {
        if (await this.updateModuleDocumentation(module)) {
          successCount++;
        }
      }
      
      if (successCount > 0) {
        await this.rebuildSite();
      }
    }
    
    this.lastCommit = currentCommit;
  }

  startWatching(intervalMs = 5000) {
    if (this.isWatching) {
      console.log('⚠️  Git watcher is already running');
      return;
    }

    console.log(`👀 Starting git watcher (interval: ${intervalMs}ms)`);
    console.log(`📂 Repository: ${this.repoPath}`);
    console.log(`📚 Documentation: ${this.docsPath}`);
    console.log(`🔍 Initial commit: ${this.lastCommit}`);

    this.isWatching = true;
    
    // Display initial status
    this.displayStatus();
    
    this.watchInterval = setInterval(async () => {
      try {
        await this.checkForChanges();
        // Update status display periodically
        if (Date.now() % (intervalMs * 2) < intervalMs) {
          this.displayStatus();
        }
      } catch (error) {
        console.error('Error in git watcher:', error.message);
      }
    }, intervalMs);

    // Handle graceful shutdown
    process.on('SIGINT', () => {
      this.stopWatching();
    });
    
    process.on('SIGTERM', () => {
      this.stopWatching();
    });
  }

  stopWatching() {
    if (!this.isWatching) {
      return;
    }

    console.log('\n🛑 Stopping git watcher...');
    this.isWatching = false;
    
    if (this.watchInterval) {
      clearInterval(this.watchInterval);
      this.watchInterval = null;
    }
    
    console.log('✅ Git watcher stopped');
    process.exit(0);
  }

  async forceUpdate() {
    console.log('🔄 Forcing full documentation update...');
    
    try {
      await this.updateModuleDocumentation('all');
      await this.rebuildSite();
      console.log('✅ Full update completed');
    } catch (error) {
      console.error('❌ Full update failed:', error.message);
    }
  }
}

// CLI interface
function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'watch';
  
  const repoPath = path.resolve(__dirname, '..', '..', '..');
  const docsPath = path.resolve(__dirname, '..', '..');
  
  const watcher = new GitWatcher(repoPath, docsPath);
  
  switch (command) {
    case 'watch':
      const interval = args[1] ? parseInt(args[1]) * 1000 : 5000;
      watcher.startWatching(interval);
      break;
      
    case 'check':
      watcher.checkForChanges();
      break;
      
    case 'force':
      watcher.forceUpdate();
      break;
      
    case 'status':
      watcher.displayStatus();
      break;
      
    default:
      console.log(`
Usage: node git-watcher.js <command> [options]

Commands:
  watch [interval]    Start watching for changes (default: 5s interval)
  check              Check for changes once
  force              Force full documentation update
  status             Show current status

Examples:
  node git-watcher.js watch 10    # Watch every 10 seconds
  node git-watcher.js check       # Check once
  node git-watcher.js force       # Force rebuild
      `);
  }
}

if (require.main === module) {
  main();
}

module.exports = GitWatcher;