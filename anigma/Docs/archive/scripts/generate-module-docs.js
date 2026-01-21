#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function analyzeSwiftFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  
  // Extract imports
  const importRegex = /import\s+([^\s;]+)/g;
  const imports = [];
  let match;
  while ((match = importRegex.exec(content)) !== null) {
    imports.push(match[1]);
  }
  
  // Extract public structs/classes/enums
  const publicTypes = [];
  const publicRegex = /(public\s+)(struct|class|enum|protocol)\s+(\w+)/g;
  while ((match = publicRegex.exec(content)) !== null) {
    publicTypes.push({
      type: match[2],
      name: match[3],
      line: content.substring(0, match.index).split('\n').length
    });
  }
  
  // Extract functions
  const functions = [];
  const funcRegex = /(public\s+)?(static\s+)?func\s+(\w+)/g;
  while ((match = funcRegex.exec(content)) !== null) {
    functions.push({
      name: match[3],
      isPublic: !!match[1],
      isStatic: !!match[2],
      line: content.substring(0, match.index).split('\n').length
    });
  }
  
  // Extract comments/documentation
  const comments = [];
  const commentRegex = /\/\/\s*(.+)|\/\*\*([\s\S]*?)\*\//g;
  while ((match = commentRegex.exec(content)) !== null) {
    const comment = match[1] || match[2].trim();
    if (comment.length > 10) { // Filter out short comments
      comments.push({
        text: comment,
        line: content.substring(0, match.index).split('\n').length
      });
    }
  }
  
  return {
    imports,
    publicTypes,
    functions,
    comments,
    lineCount: content.split('\n').length
  };
}

function analyzeModule(modulePath) {
  const moduleInfo = {
    name: path.basename(modulePath),
    files: [],
    totalTypes: 0,
    totalFunctions: 0,
    totalLines: 0,
    dependencies: new Set(),
    components: [],
    systems: [],
    services: []
  };
  
  function analyzeDirectory(dirPath) {
    const items = fs.readdirSync(dirPath);
    
    for (const item of items) {
      const itemPath = path.join(dirPath, item);
      const stat = fs.statSync(itemPath);
      
      if (stat.isDirectory()) {
        analyzeDirectory(itemPath);
      } else if (item.endsWith('.swift')) {
        const relativePath = path.relative(modulePath, itemPath);
        const fileAnalysis = analyzeSwiftFile(itemPath);
        
        moduleInfo.files.push({
          path: relativePath,
          ...fileAnalysis
        });
        
        moduleInfo.totalTypes += fileAnalysis.publicTypes.length;
        moduleInfo.totalFunctions += fileAnalysis.functions.filter(f => f.isPublic).length;
        moduleInfo.totalLines += fileAnalysis.lineCount;
        
        // Categorize by directory structure
        if (relativePath.includes('Components/')) {
          fileAnalysis.publicTypes.forEach(type => {
            moduleInfo.components.push(type.name);
          });
        } else if (relativePath.includes('Systems/')) {
          fileAnalysis.publicTypes.forEach(type => {
            moduleInfo.systems.push(type.name);
          });
        } else if (relativePath.includes('Services/')) {
          fileAnalysis.publicTypes.forEach(type => {
            moduleInfo.services.push(type.name);
          });
        }
        
        // Collect dependencies
        fileAnalysis.imports.forEach(imp => {
          if (imp.startsWith('Anigma') || imp === 'DatabaseCore' || imp === 'ContractsCore') {
            moduleInfo.dependencies.add(imp);
          }
        });
      }
    }
  }
  
  analyzeDirectory(modulePath);
  moduleInfo.dependencies = Array.from(moduleInfo.dependencies);
  
  return moduleInfo;
}

function generateModuleDocumentation() {
  const sourcesPath = path.join(__dirname, '..', '..', 'Sources');
  const modules = {};
  
  console.log('🔍 Analyzing Swift modules...');
  
  const moduleDirs = fs.readdirSync(sourcesPath)
    .filter(item => {
      const itemPath = path.join(sourcesPath, item);
      return fs.statSync(itemPath).isDirectory() && !item.startsWith('.');
    });
  
  for (const moduleName of moduleDirs) {
    const modulePath = path.join(sourcesPath, moduleName);
    console.log(`  Analyzing ${moduleName}...`);
    modules[moduleName] = analyzeModule(modulePath);
  }
  
  // Generate documentation files
  const docsPath = path.join(__dirname, '..', 'architecture', 'modules');
  if (!fs.existsSync(docsPath)) {
    fs.mkdirSync(docsPath, { recursive: true });
  }
  
  console.log('📝 Generating documentation files...');
  
  Object.entries(modules).forEach(([moduleName, info]) => {
    const docContent = generateModulePage(moduleName, info);
    const docPath = path.join(docsPath, `${moduleName.toLowerCase()}.md`);
    fs.writeFileSync(docPath, docContent);
    console.log(`  Generated: ${moduleName}.md`);
  });
  
  // Generate index
  const indexContent = generateModuleIndex(modules);
  fs.writeFileSync(path.join(docsPath, 'index.md'), indexContent);
  console.log('  Generated: index.md');
  
  // Save analysis data
  const analysisPath = path.join(__dirname, '..', 'diagrams', 'generated', 'module-analysis.json');
  fs.writeFileSync(analysisPath, JSON.stringify(modules, null, 2));
  console.log(`  Saved analysis: module-analysis.json`);
  
  console.log('\n🎉 Dynamic documentation generation complete!');
  console.log(`📚 Generated ${Object.keys(modules).length} module documentation pages`);
}

function generateModulePage(moduleName, info) {
  return `# ${moduleName}

## Overview

${moduleName} is a Swift module in the Anigma ecosystem with **${info.totalLines} lines of code** across **${info.files.length} files**.

## Statistics

- **Public Types**: ${info.totalTypes}
- **Public Functions**: ${info.totalFunctions}  
- **Components**: ${info.components.length}
- **Systems**: ${info.systems.length}
- **Services**: ${info.services.length}

## Architecture

### Components
${info.components.length > 0 ? 
  info.components.map(comp => `- \`${comp}\``).join('\n') : 
  'No components found'
}

### Systems
${info.systems.length > 0 ? 
  info.systems.map(sys => `- \`${sys}\``).join('\n') : 
  'No systems found'
}

### Services
${info.services.length > 0 ? 
  info.services.map(svc => `- \`${svc}\``).join('\n') : 
  'No services found'
}

## Dependencies

${info.dependencies.length > 0 ? 
  info.dependencies.map(dep => `- \`${dep}\``).join('\n') : 
  'No internal dependencies'
}

## File Structure

${info.files.map(file => `
### ${file.path}

- **Lines**: ${file.lineCount}
- **Public Types**: ${file.publicTypes.length}
- **Public Functions**: ${file.functions.filter(f => f.isPublic).length}

${file.publicTypes.length > 0 ? `
**Public Types:**
${file.publicTypes.map(type => `- \`${type.type} ${type.name}\` (line ${type.line})`).join('\n')}
` : ''}

${file.functions.filter(f => f.isPublic).length > 0 ? `
**Public Functions:**
${file.functions.filter(f => f.isPublic).map(func => `- \`${func.name}\`${func.isStatic ? ' (static)' : ''} (line ${func.line})`).join('\n')}
` : ''}
`).join('')}
`;
}

function generateModuleIndex(modules) {
  const moduleList = Object.entries(modules)
    .map(([name, info]) => ({
      name,
      lines: info.totalLines,
      files: info.files.length,
      types: info.totalTypes,
      functions: info.totalFunctions
    }))
    .sort((a, b) => b.lines - a.lines);
  
  return `# Module Documentation

Complete documentation for all Anigma Swift modules, generated automatically from source code analysis.

## Module Overview

| Module | Lines | Files | Types | Functions |
|--------|-------|-------|-------|-----------|
${moduleList.map(mod => 
  `| [${mod.name}](./${mod.name.toLowerCase()}.md) | ${mod.lines} | ${mod.files} | ${mod.types} | ${mod.functions} |`
).join('\n')}

## Summary

- **Total Modules**: ${Object.keys(modules).length}
- **Total Lines**: ${moduleList.reduce((sum, mod) => sum + mod.lines, 0)}
- **Total Files**: ${moduleList.reduce((sum, mod) => sum + mod.files, 0)}

## Architecture Layers

### Core Governance Modules
${Object.entries(modules)
  .filter(([name]) => ['AnigmaCore', 'AnigmaPrimitives', 'DatabaseCore', 'ContractsCore'].includes(name))
  .map(([name, info]) => `- **[${name}](./${name.toLowerCase()}.md)**: ${info.totalLines} lines, ${info.totalTypes} types`)
  .join('\n')}

### Capability Modules
${Object.entries(modules)
  .filter(([name]) => !['AnigmaCore', 'AnigmaPrimitives', 'DatabaseCore', 'ContractsCore'].includes(name))
  .map(([name, info]) => `- **[${name}](./${name.toLowerCase()}.md)**: ${info.totalLines} lines, ${info.totalTypes} types`)
  .join('\n')}

---

*This documentation is automatically generated from the Swift source code. Last updated: ${new Date().toISOString()}*
`;
}

// Run the generation
generateModuleDocumentation();