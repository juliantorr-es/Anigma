#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class IncrementalBuilder {
  constructor(docsPath) {
    this.docsPath = docsPath;
    this.buildCache = this.loadBuildCache();
    this.dependencyGraph = this.buildDependencyGraph();
  }

  loadBuildCache() {
    const cachePath = path.join(this.docsPath, 'data', 'build-cache.json');
    
    if (fs.existsSync(cachePath)) {
      try {
        return JSON.parse(fs.readFileSync(cachePath, 'utf8'));
      } catch (error) {
        console.warn('⚠️  Could not load build cache, starting fresh');
      }
    }
    
    return {};
  }

  saveBuildCache() {
    const cachePath = path.join(this.docsPath, 'data', 'build-cache.json');
    const dataDir = path.dirname(cachePath);
    
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    
    fs.writeFileSync(cachePath, JSON.stringify(this.buildCache, null, 2));
  }

  getFileHash(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      return require('crypto').createHash('md5').update(content).digest('hex');
    } catch (error) {
      return null;
    }
  }

  buildDependencyGraph() {
    const sourcesPath = path.join(this.docsPath, '..', 'Sources');
    const graph = {};
    
    if (!fs.existsSync(sourcesPath)) {
      return graph;
    }
    
    const modules = fs.readdirSync(sourcesPath)
      .filter(item => {
        const itemPath = path.join(sourcesPath, item);
        return fs.statSync(itemPath).isDirectory();
      });
    
    modules.forEach(module => {
      graph[module] = this.getModuleDependencies(path.join(sourcesPath, module));
    });
    
    return graph;
  }

  getModuleDependencies(modulePath) {
    const dependencies = [];
    
    function scanDirectory(dirPath) {
      const items = fs.readdirSync(dirPath);
      
      for (const item of items) {
        const itemPath = path.join(dirPath, item);
        const stat = fs.statSync(itemPath);
        
        if (stat.isDirectory()) {
          scanDirectory(itemPath);
        } else if (item.endsWith('.swift')) {
          const content = fs.readFileSync(itemPath, 'utf8');
          const imports = content.match(/import\s+([^\s;]+)/g) || [];
          
          imports.forEach(imp => {
            const moduleName = imp.replace(/import\s+/, '');
            if (moduleName.startsWith('Anigma') || 
                moduleName === 'DatabaseCore' || 
                moduleName === 'ContractsCore') {
              dependencies.push(moduleName);
            }
          });
        }
      }
    }
    
    scanDirectory(modulePath);
    return [...new Set(dependencies)];
  }

  getAffectedModules(changedModules) {
    const affected = new Set(changedModules);
    
    // Add modules that depend on changed modules
    function addDependents(moduleName) {
      Object.entries(this.dependencyGraph).forEach(([name, deps]) => {
        if (deps.includes(moduleName) && !affected.has(name)) {
          affected.add(name);
          addDependents.call(this, name);
        }
      });
    }
    
    changedModules.forEach(module => {
      addDependents.call(this, module);
    });
    
    return Array.from(affected);
  }

  needsRebuild(target) {
    const cacheKey = target;
    const cached = this.buildCache[cacheKey];
    
    if (!cached) {
      return true;
    }
    
    // Check if source files changed
    if (cached.sourceFiles) {
      for (const sourceFile of cached.sourceFiles) {
        const currentHash = this.getFileHash(sourceFile);
        if (currentHash !== cached.fileHashes[sourceFile]) {
          return true;
        }
      }
    }
    
    return false;
  }

  updateBuildCache(target, sourceFiles) {
    const fileHashes = {};
    
    sourceFiles.forEach(file => {
      fileHashes[file] = this.getFileHash(file);
    });
    
    this.buildCache[target] = {
      sourceFiles,
      fileHashes,
      builtAt: new Date().toISOString()
    };
  }

  async rebuildModule(moduleName) {
    console.log(`🔧 Incrementally rebuilding module: ${moduleName}`);
    
    try {
      // Get module source files
      const modulePath = path.join(this.docsPath, '..', 'Sources', moduleName);
      const sourceFiles = this.getAllSwiftFiles(modulePath);
      
      // Check if rebuild is needed
      if (!this.needsRebuild(`module:${moduleName}`)) {
        console.log(`⏭️  Module ${moduleName} is up to date`);
        return true;
      }
      
      // Regenerate module documentation
      execSync('node scripts/generate-module-docs.js', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      // Update cache
      this.updateBuildCache(`module:${moduleName}`, sourceFiles);
      
      console.log(`✅ Incrementally rebuilt ${moduleName}`);
      return true;
      
    } catch (error) {
      console.error(`❌ Failed to rebuild ${moduleName}:`, error.message);
      return false;
    }
  }

  async rebuildDiagrams() {
    console.log('🎨 Incrementally rebuilding diagrams...');
    
    try {
      // Check if diagram sources changed
      const diagramSources = [
        path.join(this.docsPath, 'scripts', 'generate-enhanced-modules.js'),
        path.join(this.docsPath, 'scripts', 'generate-fixed-diagrams.js')
      ];
      
      const needsRebuild = diagramSources.some(source => 
        this.needsRebuild(`diagrams`)
      );
      
      if (!needsRebuild) {
        console.log('⏭️  Diagrams are up to date');
        return true;
      }
      
      // Regenerate diagrams
      execSync('node scripts/generate-enhanced-modules.js', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      execSync('node scripts/generate-fixed-diagrams.js', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      // Update cache
      this.updateBuildCache('diagrams', diagramSources);
      
      console.log('✅ Incrementally rebuilt diagrams');
      return true;
      
    } catch (error) {
      console.error('❌ Failed to rebuild diagrams:', error.message);
      return false;
    }
  }

  async rebuildSite() {
    console.log('🏗️ Incrementally rebuilding site...');
    
    try {
      // Check if site sources changed
      const siteSources = [
        path.join(this.docsPath, '.vitepress'),
        path.join(this.docsPath, 'index.md'),
        path.join(this.docsPath, 'architecture'),
        path.join(this.docsPath, 'diagrams', 'generated')
      ];
      
      const allSiteFiles = this.getAllFiles(siteSources);
      const needsRebuild = this.needsRebuild('site');
      
      if (!needsRebuild) {
        console.log('⏭️  Site is up to date');
        return true;
      }
      
      // Build site
      execSync('npm run build', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      // Update cache
      this.updateBuildCache('site', allSiteFiles);
      
      console.log('✅ Incrementally rebuilt site');
      return true;
      
    } catch (error) {
      console.error('❌ Failed to rebuild site:', error.message);
      return false;
    }
  }

  getAllSwiftFiles(dirPath) {
    const files = [];
    
    if (!fs.existsSync(dirPath)) {
      return files;
    }
    
    function scanDirectory(dir) {
      const items = fs.readdirSync(dir);
      
      for (const item of items) {
        const itemPath = path.join(dir, item);
        const stat = fs.statSync(itemPath);
        
        if (stat.isDirectory()) {
          scanDirectory(itemPath);
        } else if (item.endsWith('.swift')) {
          files.push(itemPath);
        }
      }
    }
    
    scanDirectory(dirPath);
    return files;
  }

  getAllFiles(paths) {
    const files = [];
    
    paths.forEach(basePath => {
      if (!fs.existsSync(basePath)) {
        return;
      }
      
      const stat = fs.statSync(basePath);
      
      if (stat.isDirectory()) {
        function scanDirectory(dir) {
          const items = fs.readdirSync(dir);
          
          for (const item of items) {
            const itemPath = path.join(dir, item);
            const itemStat = fs.statSync(itemPath);
            
            if (itemStat.isDirectory()) {
              scanDirectory(itemPath);
            } else {
              files.push(itemPath);
            }
          }
        }
        
        scanDirectory(basePath);
      } else {
        files.push(basePath);
      }
    });
    
    return files;
  }

  async incrementalUpdate(changedModules) {
    console.log(`🔄 Starting incremental update for: ${changedModules.join(', ')}`);
    
    const affectedModules = this.getAffectedModules(changedModules);
    console.log(`📦 Affected modules: ${affectedModules.join(', ')}`);
    
    let successCount = 0;
    
    // Rebuild affected modules
    for (const module of affectedModules) {
      if (await this.rebuildModule(module)) {
        successCount++;
      }
    }
    
    // Rebuild diagrams if modules changed
    if (affectedModules.length > 0) {
      await this.rebuildDiagrams();
    }
    
    // Rebuild site
    await this.rebuildSite();
    
    // Save cache
    this.saveBuildCache();
    
    console.log(`✅ Incremental update complete: ${successCount}/${affectedModules.length} modules rebuilt`);
    return successCount === affectedModules.length;
  }

  async fullRebuild() {
    console.log('🔄 Starting full rebuild...');
    
    // Clear cache
    this.buildCache = {};
    
    // Rebuild everything
    try {
      execSync('node scripts/generate-module-docs.js', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      execSync('node scripts/generate-enhanced-modules.js', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      execSync('node scripts/generate-fixed-diagrams.js', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      execSync('npm run build', { 
        cwd: this.docsPath,
        stdio: 'pipe'
      });
      
      console.log('✅ Full rebuild complete');
      return true;
      
    } catch (error) {
      console.error('❌ Full rebuild failed:', error.message);
      return false;
    }
  }

  getCacheStats() {
    return {
      cachedItems: Object.keys(this.buildCache).length,
      modules: Object.keys(this.dependencyGraph).length,
      lastSaved: this.buildCache.lastSaved || 'Never'
    };
  }
}

// CLI interface
function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'stats';
  
  const docsPath = path.resolve(__dirname, '..', '..');
  const builder = new IncrementalBuilder(docsPath);
  
  switch (command) {
    case 'update':
      const modules = args.slice(1);
      if (modules.length === 0) {
        console.error('❌ Please specify modules to update');
        process.exit(1);
      }
      builder.incrementalUpdate(modules);
      break;
      
    case 'full':
      builder.fullRebuild();
      break;
      
    case 'stats':
      console.log('📊 Build Cache Statistics:');
      console.log(JSON.stringify(builder.getCacheStats(), null, 2));
      break;
      
    case 'clear':
      builder.buildCache = {};
      builder.saveBuildCache();
      console.log('✅ Build cache cleared');
      break;
      
    default:
      console.log(`
Usage: node incremental-builder.js <command> [options]

Commands:
  update <modules...>  Incrementally update specific modules
  full                Perform full rebuild
  stats               Show cache statistics
  clear               Clear build cache

Examples:
  node incremental-builder.js update HarmoniaModule DiaplasionModule
  node incremental-builder.js full
  node incremental-builder.js stats
      `);
  }
}

if (require.main === module) {
  main();
}

module.exports = IncrementalBuilder;