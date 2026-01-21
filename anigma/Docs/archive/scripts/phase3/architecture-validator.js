#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

class ArchitectureValidator {
  constructor(repoPath, docsPath) {
    this.repoPath = repoPath;
    this.docsPath = docsPath;
    this.sourcesPath = path.join(repoPath, 'Sources');
    this.rules = this.loadValidationRules();
    this.results = {
      passed: 0,
      failed: 0,
      warnings: 0,
      issues: []
    };
  }

  loadValidationRules() {
    return {
      // Core Governance Layer Rules
      coreLayerOnly: {
        name: 'Core Layer Dependencies',
        description: 'Core modules should only depend on other core modules',
        severity: 'error'
      },
      
      // Capability Layer Rules  
      capabilityToCore: {
        name: 'Capability Dependencies',
        description: 'Capability modules should only depend on Core Governance layer',
        severity: 'error'
      },
      
      // General Architecture Rules
      noCircularDependencies: {
        name: 'Circular Dependencies',
        description: 'No circular dependencies allowed between modules',
        severity: 'error'
      },
      
      ecsConsistency: {
        name: 'ECS Pattern Consistency',
        description: 'Modules should follow ECS patterns consistently',
        severity: 'warning'
      },
      
      namingConventions: {
        name: 'Naming Conventions',
        description: 'Modules should follow Anigma naming conventions',
        severity: 'warning'
      },
      
      moduleStructure: {
        name: 'Module Structure',
        description: 'Modules should have proper directory structure',
        severity: 'warning'
      }
    };
  }

  getModuleStructure() {
    const modules = {};
    
    if (!fs.existsSync(this.sourcesPath)) {
      return modules;
    }
    
    const moduleDirs = fs.readdirSync(this.sourcesPath)
      .filter(item => {
        const itemPath = path.join(this.sourcesPath, item);
        return fs.statSync(itemPath).isDirectory();
      });
    
    moduleDirs.forEach(moduleName => {
      modules[moduleName] = this.analyzeModule(moduleName);
    });
    
    return modules;
  }

  analyzeModule(moduleName) {
    const modulePath = path.join(this.sourcesPath, moduleName);
    const analysis = {
      name: moduleName,
      path: modulePath,
      dependencies: [],
      structure: {
        hasComponents: false,
        hasSystems: false,
        hasServices: false,
        hasPipelines: false
      },
      files: [],
      layer: this.determineModuleLayer(moduleName)
    };
    
    // Scan module directory
    function scanDirectory(dirPath, relativePath = '') {
      const items = fs.readdirSync(dirPath);
      
      for (const item of items) {
        const itemPath = path.join(dirPath, item);
        const itemRelativePath = path.join(relativePath, item);
        const stat = fs.statSync(itemPath);
        
        if (stat.isDirectory()) {
          // Check for standard directories
          if (item === 'Components') analysis.structure.hasComponents = true;
          if (item === 'Systems') analysis.structure.hasSystems = true;
          if (item === 'Services') analysis.structure.hasServices = true;
          if (item === 'Pipelines') analysis.structure.hasPipelines = true;
          
          scanDirectory(itemPath, itemRelativePath);
        } else if (item.endsWith('.swift')) {
          analysis.files.push(itemRelativePath);
          
          // Extract dependencies
          const content = fs.readFileSync(itemPath, 'utf8');
          const imports = content.match(/import\s+([^\s;]+)/g) || [];
          
          imports.forEach(imp => {
            const dep = imp.replace(/import\s+/, '');
            if (dep.startsWith('Anigma') || 
                dep === 'DatabaseCore' || 
                dep === 'ContractsCore') {
              analysis.dependencies.push(dep);
            }
          });
        }
      }
    }
    
    scanDirectory(modulePath);
    analysis.dependencies = [...new Set(analysis.dependencies)];
    
    return analysis;
  }

  determineModuleLayer(moduleName) {
    const coreModules = [
      'AnigmaCore', 'AnigmaPrimitives', 'DatabaseCore', 'ContractsCore'
    ];
    
    return coreModules.includes(moduleName) ? 'core' : 'capability';
  }

  validateCoreLayerDependencies(modules) {
    const coreModules = Object.values(modules).filter(m => m.layer === 'core');
    const issues = [];
    
    coreModules.forEach(module => {
      module.dependencies.forEach(dep => {
        const depModule = modules[dep];
        if (depModule && depModule.layer === 'capability') {
          issues.push({
            rule: 'coreLayerOnly',
            module: module.name,
            dependency: dep,
            message: `Core module ${module.name} depends on capability module ${dep}`,
            severity: 'error'
          });
        }
      });
    });
    
    return issues;
  }

  validateCapabilityDependencies(modules) {
    const capabilityModules = Object.values(modules).filter(m => m.layer === 'capability');
    const issues = [];
    
    capabilityModules.forEach(module => {
      module.dependencies.forEach(dep => {
        const depModule = modules[dep];
        if (depModule && depModule.layer === 'capability') {
          issues.push({
            rule: 'capabilityToCore',
            module: module.name,
            dependency: dep,
            message: `Capability module ${module.name} depends on another capability module ${dep}`,
            severity: 'error'
          });
        }
      });
    });
    
    return issues;
  }

  detectCircularDependencies(modules) {
    const visited = new Set();
    const recursionStack = new Set();
    const issues = [];
    
    function dfs(moduleName, path = []) {
      if (recursionStack.has(moduleName)) {
        const cycleStart = path.indexOf(moduleName);
        const cycle = path.slice(cycleStart).concat(moduleName);
        issues.push({
          rule: 'noCircularDependencies',
          module: moduleName,
          cycle: cycle,
          message: `Circular dependency detected: ${cycle.join(' → ')}`,
          severity: 'error'
        });
        return;
      }
      
      if (visited.has(moduleName)) {
        return;
      }
      
      visited.add(moduleName);
      recursionStack.add(moduleName);
      
      const module = modules[moduleName];
      if (module) {
        module.dependencies.forEach(dep => {
          dfs(dep, path.concat(moduleName));
        });
      }
      
      recursionStack.delete(moduleName);
    }
    
    Object.keys(modules).forEach(moduleName => {
      if (!visited.has(moduleName)) {
        dfs(moduleName);
      }
    });
    
    return issues;
  }

  validateECSConsistency(modules) {
    const issues = [];
    
    Object.values(modules).forEach(module => {
      // Check if modules have proper ECS structure
      const hasECSFiles = module.files.some(file => 
        file.includes('Component') || file.includes('System') || file.includes('World')
      );
      
      if (module.layer === 'capability' && !hasECSFiles) {
        issues.push({
          rule: 'ecsConsistency',
          module: module.name,
          message: `Capability module ${module.name} should use ECS patterns`,
          severity: 'warning'
        });
      }
    });
    
    return issues;
  }

  validateNamingConventions(modules) {
    const issues = [];
    
    Object.values(modules).forEach(module => {
      // Check module naming
      if (!module.name.endsWith('Module') && 
          !module.name.endsWith('Core') && 
          !module.name.endsWith('CLI')) {
        issues.push({
          rule: 'namingConventions',
          module: module.name,
          message: `Module ${module.name} should follow naming convention (end with Module, Core, or CLI)`,
          severity: 'warning'
        });
      }
    });
    
    return issues;
  }

  validateModuleStructure(modules) {
    const issues = [];
    
    Object.values(modules).forEach(module => {
      // Check for at least one structural directory
      const hasStructure = Object.values(module.structure).some(Boolean);
      
      if (!hasStructure && module.files.length > 1) {
        issues.push({
          rule: 'moduleStructure',
          module: module.name,
          message: `Module ${module.name} should have proper directory structure (Components/, Systems/, etc.)`,
          severity: 'warning'
        });
      }
    });
    
    return issues;
  }

  async runValidation() {
    console.log('🔍 Starting architecture validation...');
    
    const modules = this.getModuleStructure();
    console.log(`📦 Analyzed ${Object.keys(modules).length} modules`);
    
    // Run all validation rules
    const allIssues = [
      ...this.validateCoreLayerDependencies(modules),
      ...this.validateCapabilityDependencies(modules),
      ...this.detectCircularDependencies(modules),
      ...this.validateECSConsistency(modules),
      ...this.validateNamingConventions(modules),
      ...this.validateModuleStructure(modules)
    ];
    
    // Categorize results
    allIssues.forEach(issue => {
      if (issue.severity === 'error') {
        this.results.failed++;
      } else if (issue.severity === 'warning') {
        this.results.warnings++;
      }
      this.results.issues.push(issue);
    });
    
    this.results.passed = Object.keys(modules).length - this.results.failed;
    
    // Generate report
    this.generateReport();
    
    return this.results;
  }

  generateReport() {
    console.log('\n📊 Architecture Validation Report');
    console.log('='.repeat(50));
    console.log(`✅ Passed: ${this.results.passed}`);
    console.log(`❌ Failed: ${this.results.failed}`);
    console.log(`⚠️  Warnings: ${this.results.warnings}`);
    console.log(`📋 Total Issues: ${this.results.issues.length}`);
    
    if (this.results.issues.length > 0) {
      console.log('\n🔍 Issues Found:');
      console.log('-'.repeat(50));
      
      this.results.issues.forEach((issue, index) => {
        const icon = issue.severity === 'error' ? '❌' : '⚠️';
        console.log(`${index + 1}. ${icon} ${issue.message}`);
        console.log(`   Rule: ${this.rules[issue.rule]?.name || issue.rule}`);
        console.log(`   Module: ${issue.module}`);
        if (issue.dependency) {
          console.log(`   Dependency: ${issue.dependency}`);
        }
        console.log('');
      });
    }
    
    // Save detailed report
    const reportPath = path.join(this.docsPath || '.', 'data', 'validation-report.json');
    const reportDir = path.dirname(reportPath);
    
    if (!fs.existsSync(reportDir)) {
      fs.mkdirSync(reportDir, { recursive: true });
    }
    
    const detailedReport = {
      timestamp: new Date().toISOString(),
      summary: {
        passed: this.results.passed,
        failed: this.results.failed,
        warnings: this.results.warnings,
        total: this.results.issues.length
      },
      rules: this.rules,
      issues: this.results.issues
    };
    
    fs.writeFileSync(reportPath, JSON.stringify(detailedReport, null, 2));
    console.log(`📄 Detailed report saved to: ${reportPath}`);
  }

  getHealthScore() {
    const total = this.results.passed + this.results.failed;
    if (total === 0) return 100;
    
    const baseScore = (this.results.passed / total) * 100;
    const warningPenalty = (this.results.warnings / total) * 5;
    
    return Math.max(0, Math.round(baseScore - warningPenalty));
  }
}

// CLI interface
function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'validate';
  
  const repoPath = path.resolve(__dirname, '..', '..', '..');
  const docsPath = path.resolve(__dirname, '..', '..');
  const validator = new ArchitectureValidator(repoPath, docsPath);
  
  switch (command) {
    case 'validate':
      validator.runValidation().then(results => {
        const score = validator.getHealthScore();
        console.log(`\n🏆 Architecture Health Score: ${score}/100`);
        
        if (results.failed > 0) {
          process.exit(1);
        }
      });
      break;
      
    case 'rules':
      console.log('📋 Available Validation Rules:');
      Object.entries(validator.rules).forEach(([key, rule]) => {
        console.log(`  ${key}: ${rule.name} (${rule.severity})`);
        console.log(`    ${rule.description}`);
      });
      break;
      
    case 'score':
      validator.runValidation().then(() => {
        const score = validator.getHealthScore();
        console.log(`${score}`);
      });
      break;
      
    default:
      console.log(`
Usage: node architecture-validator.js <command>

Commands:
  validate    Run full architecture validation
  rules       Show available validation rules
  score       Show only the health score

Examples:
  node architecture-validator.js validate
  node architecture-validator.js rules
  node architecture-validator.js score
      `);
  }
}

if (require.main === module) {
  main();
}

module.exports = ArchitectureValidator;