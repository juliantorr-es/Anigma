#!/usr/bin/env node

/**
 * Fixed Diagram Generator for Anigma
 * Separates pure Mermaid from explanatory content
 */

const fs = require('fs');
const path = require('path');

// Pure Mermaid templates (no markdown headers)
const mermaidTemplates = {
  'two-tier-overview': `graph TB
    subgraph "Core Governance Layer"
        direction TB
        Core[AnigmaCore ECS]
        DB[DatabaseCore]
        Harmonia[HarmoniaSpine]
        ML[ML Worker]
        Security[Security & Evidence]
        
        Core --> DB
        Core --> Harmonia
        Harmonia --> ML
        ML --> Security
    end
    
    subgraph "Capability Modules"
        direction LR
        HarmoniaMod[HarmoniaModule<br/>Governed Inference]
        Diaplasion[DiaplasionModule<br/>Alt-Media]
        Accessum[AccessumModule<br/>Client Workflows]
        Outlineum[OutlineumModule<br/>Creative]
        Pragma[PragmaModule<br/>Work Management]
        Conexus[ConexusModule<br/>CRM]
        Codex[CodexModule<br/>Knowledge]
        Transcriptum[TranscriptumModule<br/>Academic]
        Observatorium[ObservatoriumModule<br/>Telemetry]
        Polytropos[PolytroposModule<br/>Video]
    end
    
    Core -.->|ECS Foundation| HarmoniaMod
    Core -.->|ECS Foundation| Diaplasion
    Core -.->|ECS Foundation| Accessum
    Core -.->|ECS Foundation| Outlineum
    Core -.->|ECS Foundation| Pragma
    Core -.->|ECS Foundation| Conexus
    Core -.->|ECS Foundation| Codex
    Core -.->|ECS Foundation| Transcriptum
    Core -.->|ECS Foundation| Observatorium
    Core -.->|ECS Foundation| Polytropos
    
    classDef coreLayer fill:#e1f5fe,stroke:#01579b,stroke-width:3px
    classDef capabilityLayer fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef securityBoundary stroke:#ff5722,stroke-width:2px,stroke-dasharray: 5 5
    
    class Core,DB,Harmonia,ML,Security coreLayer
    class HarmoniaMod,Diaplasion,Accessum,Outlineum,Pragma,Conexus,Codex,Transcriptum,Observatorium,Polytropos capabilityLayer`,

  'agent-pipeline': `flowchart TD
    Start([Start Task]) --> Architect{Agent Type}
    
    Architect -->|Architect| A1[Analyze Requirements]
    A1 --> A2[Search Existing Abstractions]
    A2 --> A3[Create Structured Spec]
    A3 --> A4[No File Writes]
    A4 --> Handoff1[Handoff to Builder]
    
    Architect -->|Builder| B1[Receive Spec from Architect]
    B1 --> B2[Implement Using Core Patterns]
    B2 --> B3[Reuse Existing Abstractions]
    B3 --> B4[Run Tests]
    B4 --> B5[Validate Implementation]
    B5 --> Handoff2[Handoff to Validator]
    
    Architect -->|Validator| V1[Receive Implementation]
    V1 --> V2[Compare vs Spec]
    V2 --> V3[Check Security Boundaries]
    V3 --> V4[Verify Core Integration]
    V4 --> V5[Validate Tests]
    V5 --> Handoff3[Handoff to Scribe]
    
    Architect -->|Scribe| S1[Receive Validation Results]
    S1 --> S2[Update AGENTS.md]
    S2 --> S3[Update Documentation]
    S3 --> S4[Record Architectural Decisions]
    S4 --> S5[Update TechDebt.md]
    S5 --> Handoff4[Handoff to Tech-Debt Scout]
    
    Architect -->|Tech-Debt Scout| T1[Receive Documentation Updates]
    T1 --> T2[Scan for Duplication]
    T2 --> T3[Identify Consolidation Opportunities]
    T3 --> T4[Record in TechDebt.md]
    T4 --> T5[Create Consolidation Tasks]
    T5 --> Complete([Task Complete])
    
    Handoff1 --> B1
    Handoff2 --> V1
    Handoff3 --> S1
    Handoff4 --> T1
    
    classDef agentNode fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef processNode fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef handoffNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef startEndNode fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    
    class Architect,B1,V1,S1,T1 agentNode
    class A1,A2,A3,A4,B2,B3,B4,B5,V2,V3,V4,V5,S2,S3,S4,S5,T2,T3,T4,T5 processNode
    class Handoff1,Handoff2,Handoff3,Handoff4 handoffNode
    class Start,Complete startEndNode`,

  'core-layer-components': `graph TB
    subgraph "AnigmaCore ECS Foundation"
        direction TB
        World[World Actor]
        Entity[Entity System]
        Component[Component System]
        System[System Registry]
        Scheduler[Job Scheduler]
        
        World --> Entity
        World --> Component
        World --> System
        World --> Scheduler
    end
    
    subgraph "DatabaseCore"
        direction TB
        DBActor[Database Actor]
        SQLite[SQLite Backend]
        Migrations[Schema Migrations]
        Queries[Query Interface]
        
        DBActor --> SQLite
        DBActor --> Migrations
        DBActor --> Queries
    end
    
    subgraph "HarmoniaSpine Governance"
        direction TB
        Governance[Governance Engine]
        Policies[Policy Enforcement]
        Audit[Audit Trail]
        KillSwitch[Kill Switch]
        
        Governance --> Policies
        Governance --> Audit
        Governance --> KillSwitch
    end
    
    subgraph "ML Worker Integration"
        direction TB
        MLWorker[ML Worker]
        Evidence[Evidence Generation]
        Signing[Hardware Signing]
        Timestamp[Trusted Timestamping]
        
        MLWorker --> Evidence
        Evidence --> Signing
        Evidence --> Timestamp
    end
    
    Entity --> DBActor
    System --> Governance
    Scheduler --> MLWorker
    
    classDef coreComponent fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef databaseComponent fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef governanceComponent fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef mlComponent fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    
    class World,Entity,Component,System,Scheduler coreComponent
    class DBActor,SQLite,Migrations,Queries databaseComponent
    class Governance,Policies,Audit,KillSwitch governanceComponent
    class MLWorker,Evidence,Signing,Timestamp mlComponent`,

  'ml-evidence-generation': `sequenceDiagram
    participant Agent as AI Agent
    participant ML as ML Worker
    participant Core as Core Layer
    participant HW as Hardware
    participant TSA as Timestamp Authority
    participant DB as Evidence DB
    
    Agent->>ML: Submit Query Request
    ML->>Core: Validate Query & Permissions
    Core->>ML: Query Approved (with runId)
    
    ML->>ML: Execute ML Inference
    Note over ML: Generate embeddings/chat completion
    
    ML->>Core: Create Evidence Bundle
    Core->>DB: Store Raw Results
    Core->>HW: Request Hardware Signature
    HW->>HW: Sign Evidence Head
    HW->>Core: Return Signature
    
    Core->>TSA: Request Trusted Timestamp
    TSA->>TSA: Generate RFC3161 Timestamp
    TSA->>Core: Return Timestamp Token
    
    Core->>DB: Store Complete Evidence Bundle
    Note over DB: Includes: results, signature, timestamp, metadata
    
    Core->>Agent: Return Evidence Receipt
    Note over Agent: Contains: bundleId, verificationUrl, hash
    
    Agent->>Core: Request Verification (optional)
    Core->>DB: Retrieve Evidence Bundle
    Core->>HW: Verify Hardware Signature
    Core->>TSA: Verify Timestamp Token
    Core->>Agent: Return Verification Result
    
    participant Auditor as External Auditor
    
    Note over Auditor: Air-gapped verification possible
    Auditor->>DB: Download Evidence Bundle
    Auditor->>HW: Verify Signature (offline)
    Auditor->>TSA: Verify Timestamp (offline)
    Auditor->>Auditor: Generate Verification Report`
};

function ensureDirectories() {
  const dirs = [
    'diagrams/generated/svg',
    'diagrams/generated/png'
  ];
  
  dirs.forEach(dir => {
    const fullPath = path.join(__dirname, '..', dir);
    if (!fs.existsSync(fullPath)) {
      fs.mkdirSync(fullPath, { recursive: true });
      console.log(`Created directory: ${fullPath}`);
    }
  });
}

function generateMermaidDiagrams() {
  console.log('🎨 Generating pure Mermaid diagrams...\n');
  
  Object.entries(mermaidTemplates).forEach(([name, mermaidContent]) => {
    const svgPath = path.join(__dirname, '..', `diagrams/generated/svg/${name}.svg`);
    const pngPath = path.join(__dirname, '..', `diagrams/generated/png/${name}.png`);
    
    // Write pure Mermaid file
    const mmdPath = path.join(__dirname, '..', `diagrams/source/${name}.mmd`);
    fs.writeFileSync(mmdPath, mermaidContent);
    console.log(`✓ Created pure Mermaid: ${name}.mmd`);
    
    // Generate using Mermaid CLI
    try {
      const { execSync } = require('child_process');
      const command = [
        'node',
        path.join(__dirname, '../../node_modules/@mermaid-js/mermaid-cli/src/cli.js'),
        '--input', mmdPath,
        '--output', svgPath,
        '--outputFormat', 'svg',
        '--theme', 'default',
        '--backgroundColor', 'transparent'
      ].join(' ');
      
      execSync(command, { stdio: 'inherit' });
      console.log(`✓ Generated SVG: ${name}.svg`);
      
      // Generate PNG
      const pngCommand = [
        'node',
        path.join(__dirname, '../../node_modules/@mermaid-js/mermaid-cli/src/cli.js'),
        '--input', mmdPath,
        '--output', pngPath,
        '--outputFormat', 'png',
        '--theme', 'default',
        '--backgroundColor', 'white',
        '--width', '1200'
      ].join(' ');
      
      execSync(pngCommand, { stdio: 'inherit' });
      console.log(`✓ Generated PNG: ${name}.png`);
      
    } catch (error) {
      console.error(`✗ Failed to generate ${name}:`, error.message);
    }
  });
}

function generateManifest() {
  const diagrams = Object.keys(mermaidTemplates).map(name => ({
    name: name.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
    category: name.includes('overview') ? 'architecture' : name.includes('pipeline') ? 'workflows' : name.includes('components') ? 'architecture' : name.includes('evidence') ? 'data-flows' : 'other',
    svg: `/diagrams/generated/svg/${name}.svg`,
    png: `/diagrams/generated/png/${name}.png`
  }));
  
  const manifest = {
    generated: new Date().toISOString(),
    diagrams: diagrams
  };
  
  const manifestPath = path.join(__dirname, '..', 'diagrams/generated/manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  console.log(`✓ Generated manifest: ${manifestPath}`);
}

function main() {
  try {
    ensureDirectories();
    generateMermaidDiagrams();
    generateManifest();
    console.log('\n🎉 Fixed diagram generation complete!');
    console.log('📋 Generated pure Mermaid files without markdown headers');
    console.log('🔧 All diagrams should now render correctly');
  } catch (error) {
    console.error('❌ Generation failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { main, generateMermaidDiagrams };