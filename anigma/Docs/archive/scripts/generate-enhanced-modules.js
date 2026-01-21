#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Module structure based on analysis
const moduleStructure = {
  core: {
    name: "Core Governance Layer",
    description: "Production-hardened, court-safe substrate",
    modules: {
      "AnigmaPrimitives": {
        purpose: "Foundational types and contracts",
        components: ["GovernanceMode", "TrustTier", "MigrationTaskRow", "AstAnchor"],
        dependencies: []
      },
      "AnigmaCore": {
        purpose: "Central ECS framework and governance substrate",
        components: ["World", "EntityId", "Component", "System", "AuditLog", "ReasoningOrchestrator"],
        dependencies: ["AnigmaPrimitives", "ContractsCore"]
      },
      "DatabaseCore": {
        purpose: "Thread-safe SQLite database access",
        components: ["DatabaseActor", "DatabaseConfiguration", "DatabaseMetrics"],
        dependencies: []
      },
      "ContractsCore": {
        purpose: "Universal contract definitions and validation",
        components: ["ContractID", "WorkflowContract", "TrustTier", "SecurityZone"],
        dependencies: ["ArgumentParser"]
      }
    }
  },
  capability: {
    name: "Capability Modules",
    description: "Feature-rich ecosystem modules",
    modules: {
      "HarmoniaModule": {
        purpose: "AI-assisted code orchestration with safety analysis",
        components: ["ReasoningOrchestrator", "CICDGate", "ThemisGovernance", "BonkersInference"],
        dependencies: ["AnigmaCore", "GRDB", "SwiftSyntax"],
        category: "ai-governance"
      },
      "DiaplasionModule": {
        purpose: "Document transformation for accessibility",
        components: ["OCREngine", "TextChunker", "EPUBExport", "BrailleExport", "AudioExport"],
        dependencies: ["AnigmaCore", "Vision", "PDFKit"],
        category: "media-processing"
      },
      "CodexModule": {
        purpose: "Documentation and knowledge management",
        components: ["Space", "Page", "Template", "VersionControl", "SearchEngine"],
        dependencies: ["AnigmaCore"],
        category: "knowledge-management"
      },
      "TranscriptumModule": {
        purpose: "Academic records management",
        components: ["StudentRecord", "CourseCatalog", "GradeBook", "TranscriptGenerator"],
        dependencies: ["AnigmaCore"],
        category: "education"
      },
      "PragmaModule": {
        purpose: "Project and task management",
        components: ["Project", "Task", "Workflow", "Timeline", "ResourceAllocation"],
        dependencies: ["AnigmaCore"],
        category: "project-management"
      },
      "ConexusModule": {
        purpose: "Contact and relationship management",
        components: ["Contact", "Relationship", "NetworkGraph", "CommunicationLog"],
        dependencies: ["AnigmaCore"],
        category: "crm"
      },
      "ObservatoriumModule": {
        purpose: "Telemetry and monitoring",
        components: ["TelemetryService", "AlertService", "MetricsCollector", "Dashboard"],
        dependencies: ["AnigmaCore"],
        category: "monitoring"
      },
      "PolytroposModule": {
        purpose: "Media processing and editing",
        components: ["MediaProcessor", "EditProfile", "ExportService", "SyncService"],
        dependencies: ["AnigmaCore"],
        category: "media-processing"
      }
    }
  }
};

function generateModuleHierarchyDiagram() {
  return `graph TB
    subgraph "Executables"
        E1[harmonia-surface]
        E2[harmonia]
        E3[ml-worker]
        E4[accessum-flow]
    end
    
    subgraph "Capability Modules"
        CM1[HarmoniaModule<br/>AI Governance]
        CM2[DiaplasionModule<br/>Media Processing]
        CM3[CodexModule<br/>Knowledge Management]
        CM4[TranscriptumModule<br/>Education]
        CM5[PragmaModule<br/>Project Management]
        CM6[ConexusModule<br/>CRM]
        CM7[ObservatoriumModule<br/>Monitoring]
        CM8[PolytroposModule<br/>Media Processing]
    end
    
    subgraph "Core Governance Layer"
        CG1[AnigmaCore<br/>ECS Framework]
        CG2[DatabaseCore<br/>SQLite Storage]
        CG3[ContractsCore<br/>Contract Validation]
        CG4[AnigmaPrimitives<br/>Base Types]
    end
    
    E1 --> CM1
    E2 --> CM1
    E3 --> CM1
    E4 --> CM1
    
    CM1 --> CG1
    CM2 --> CG1
    CM3 --> CG1
    CM4 --> CG1
    CM5 --> CG1
    CM6 --> CG1
    CM7 --> CG1
    CM8 --> CG1
    
    CG1 --> CG2
    CG1 --> CG3
    CG1 --> CG4
    
    classDef core fill:#e1f5fe,stroke:#01579b,stroke-width:3px
    classDef capability fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef executable fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    
    class CG1,CG2,CG3,CG4 core
    class CM1,CM2,CM3,CM4,CM5,CM6,CM7,CM8 capability
    class E1,E2,E3,E4 executable`;
}

function generateDependencyFlowDiagram() {
  const dependencies = [];
  
  // Core dependencies
  dependencies.push('AnigmaCore --> AnigmaPrimitives');
  dependencies.push('AnigmaCore --> ContractsCore');
  dependencies.push('AnigmaCore --> DatabaseCore');
  
  // Capability dependencies
  Object.entries(moduleStructure.capability.modules).forEach(([name, info]) => {
    info.dependencies.forEach(dep => {
      if (dep.startsWith('Anigma') || dep === 'DatabaseCore' || dep === 'ContractsCore') {
        dependencies.push(`${name} --> ${dep}`);
      }
    });
  });

  return `graph LR
    ${dependencies.join('\n    ')}
    
    classDef core fill:#e1f5fe,stroke:#01579b,stroke-width:3px
    classDef capability fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef external fill:#fff3e0,stroke:#e65100,stroke-width:2px
    
    class AnigmaCore,DatabaseCore,ContractsCore,AnigmaPrimitives core
    class ${Object.keys(moduleStructure.capability.modules).join(',')} capability`;
}

function generateCapabilityCategoriesDiagram() {
  const categories = {};
  
  Object.entries(moduleStructure.capability.modules).forEach(([name, info]) => {
    const category = info.category || 'other';
    if (!categories[category]) {
      categories[category] = [];
    }
    categories[category].push(name);
  });

  const subgraphs = Object.entries(categories).map(([category, modules]) => {
    return `    subgraph "${category.replace('-', ' ').toUpperCase()}"
${modules.map(m => `        ${m.replace(/Module$/, '')}`).join('\n')}
    end`;
  }).join('\n');

  return `graph TB
    ${subgraphs}
    
    classDef ai fill:#ffebee,stroke:#c62828
    classDef media fill:#e8f5e8,stroke:#2e7d32
    classDef knowledge fill:#fff3e0,stroke:#f57c00
    classDef education fill:#f3e5f5,stroke:#7b1fa2
    classDef project fill:#e0f2f1,stroke:#00695c
    classDef crm fill:#e1f5fe,stroke:#0277bd
    classDef monitoring fill:#fce4ec,stroke:#ad1457
    
    class HarmoniaModule ai
    class DiaplasionModule,PolytroposModule media
    class CodexModule knowledge
    class TranscriptumModule education
    class PragmaModule project
    class ConexusModule crm
    class ObservatoriumModule monitoring`;
}

function generateModuleDetailDiagram(moduleName, moduleInfo) {
  const components = moduleInfo.components || [];
  const dependencies = moduleInfo.dependencies || [];
  
  return `graph TB
    subgraph "${moduleName}"
        M["${moduleName}<br/><em>${moduleInfo.purpose}</em>"]
        
        subgraph "Components"
${components.map(comp => `            C${comp}["${comp}"]`).join('\n')}
        end
        
        subgraph "Dependencies"
${dependencies.map(dep => `            D${dep}["${dep}"]`).join('\n')}
        end
    end
    
    ${dependencies.map(dep => `    M --> D${dep}`).join('\n    ')}
    ${components.map(comp => `    M --> C${comp}`).join('\n    ')}
    
    classDef module fill:#e3f2fd,stroke:#1565c0,stroke-width:3px
    classDef component fill:#f1f8e9,stroke:#558b2f,stroke-width:2px
    classDef dependency fill:#fff8e1,stroke:#ff8f00,stroke-width:2px
    
    class M module
    class ${components.map(c => `C${c}`).join(',')} component
    class ${dependencies.map(d => `D${d}`).join(',')} dependency`;
}

// Generate all diagrams
const diagrams = [
  {
    name: "Module Hierarchy",
    filename: "module-hierarchy",
    content: generateModuleHierarchyDiagram()
  },
  {
    name: "Dependency Flow",
    filename: "dependency-flow", 
    content: generateDependencyFlowDiagram()
  },
  {
    name: "Capability Categories",
    filename: "capability-categories",
    content: generateCapabilityCategoriesDiagram()
  }
];

// Add detailed diagrams for key modules
['HarmoniaModule', 'DiaplasionModule', 'AnigmaCore'].forEach(moduleName => {
  const moduleInfo = moduleStructure.core.modules[moduleName] || 
                    moduleStructure.capability.modules[moduleName];
  if (moduleInfo) {
    diagrams.push({
      name: `${moduleName} Details`,
      filename: `${moduleName.toLowerCase()}-details`,
      content: generateModuleDetailDiagram(moduleName, moduleInfo)
    });
  }
});

// Write diagrams
const outputDir = path.join(__dirname, '..', 'diagrams', 'generated');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

['svg', 'png'].forEach(format => {
  const formatDir = path.join(outputDir, format);
  if (!fs.existsSync(formatDir)) {
    fs.mkdirSync(formatDir, { recursive: true });
  }
});

console.log('🎨 Generating enhanced module diagrams...');

diagrams.forEach(diagram => {
  const mmdPath = path.join(outputDir, `${diagram.filename}.mmd`);
  fs.writeFileSync(mmdPath, diagram.content);
  console.log(`✓ Created enhanced diagram: ${diagram.filename}.mmd`);
  
  // Generate SVG and PNG using mermaid CLI
  try {
    const { execSync } = require('child_process');
    execSync(`npx mmdc -i ${mmdPath} -o ${path.join(outputDir, 'svg', diagram.filename + '.svg')}`, { stdio: 'pipe' });
    execSync(`npx mmdc -i ${mmdPath} -o ${path.join(outputDir, 'png', diagram.filename + '.png')}`, { stdio: 'pipe' });
    console.log(`✓ Generated SVG and PNG: ${diagram.filename}`);
  } catch (error) {
    console.log(`⚠️  Could not generate SVG/PNG for ${diagram.filename}: ${error.message}`);
  }
});

// Generate enhanced manifest
const manifest = {
  generated: new Date().toISOString(),
  phase: "Phase 2 - Enhanced Module Visualization",
  moduleStructure: moduleStructure,
  diagrams: diagrams.map(d => ({
    name: d.name,
    filename: d.filename,
    svg: `/diagrams/generated/svg/${d.filename}.svg`,
    png: `/diagrams/generated/png/${d.filename}.png`
  }))
};

fs.writeFileSync(path.join(outputDir, 'enhanced-manifest.json'), JSON.stringify(manifest, null, 2));
console.log('✓ Generated enhanced manifest: enhanced-manifest.json');

console.log('\n🎉 Enhanced module diagram generation complete!');
console.log(`📊 Generated ${diagrams.length} detailed module diagrams`);