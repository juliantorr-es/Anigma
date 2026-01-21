#!/usr/bin/env node

/**
 * Simple Diagram Generator for Anigma
 * Creates basic SVG diagrams without complex Mermaid parsing
 */

const fs = require('fs');
const path = require('path');

// Simple SVG templates
const templates = {
  'two-tier-overview': `<svg viewBox="0 0 800 600" xmlns="http://www.w3.org/2000/svg">
    <style>
      .core-layer { fill: #e1f5fe; stroke: #01579b; stroke-width: 2px; }
      .capability-layer { fill: #f3e5f5; stroke: #4a148c; stroke-width: 2px; }
      .text { font-family: Arial, sans-serif; font-size: 14px; fill: #333; }
      .title { font-weight: bold; font-size: 16px; }
      .arrow { stroke: #666; stroke-width: 2px; fill: none; }
    </style>
    
    <!-- Core Layer -->
    <rect x="50" y="50" width="700" height="120" class="core-layer" rx="8"/>
    <text x="400" y="90" text-anchor="middle" class="title">Core Governance Layer</text>
    <text x="400" y="110" text-anchor="middle" class="text">Production-hardened, court-safe substrate</text>
    
    <!-- Arrow -->
    <line x1="400" y1="170" x2="400" y2="220" class="arrow"/>
    <polygon points="395,220 400,230 405,220" class="arrow"/>
    
    <!-- Capability Layer -->
    <rect x="50" y="240" width="700" height="120" class="capability-layer" rx="8"/>
    <text x="400" y="280" text-anchor="middle" class="title">Capability Modules</text>
    <text x="400" y="300" text-anchor="middle" class="text">Feature-rich ecosystem with clear contracts</text>
    
    <!-- Module boxes -->
    <g transform="translate(80, 320)">
      <rect x="0" y="0" width="120" height="40" fill="#e8f5e8" stroke="#388e3c" stroke-width="1px" rx="4"/>
      <text x="60" y="25" text-anchor="middle" class="text" font-size="12px">Harmonia</text>
    </g>
    <g transform="translate(220, 320)">
      <rect x="0" y="0" width="120" height="40" fill="#e8f5e8" stroke="#388e3c" stroke-width="1px" rx="4"/>
      <text x="60" y="25" text-anchor="middle" class="text" font-size="12px">Diaplasion</text>
    </g>
    <g transform="translate(360, 320)">
      <rect x="0" y="0" width="120" height="40" fill="#e8f5e8" stroke="#388e3c" stroke-width="1px" rx="4"/>
      <text x="60" y="25" text-anchor="middle" class="text" font-size="12px">Accessum</text>
    </g>
    <g transform="translate(500, 320)">
      <rect x="0" y="0" width="120" height="40" fill="#e8f5e8" stroke="#388e3c" stroke-width="1px" rx="4"/>
      <text x="60" y="25" text-anchor="middle" class="text" font-size="12px">Outlineum</text>
    </g>
  </svg>`,
  
  'agent-pipeline': `<svg viewBox="0 0 900 700" xmlns="http://www.w3.org/2000/svg">
    <style>
      .agent-node { fill: #e1f5fe; stroke: #01579b; stroke-width: 2px; }
      .process-node { fill: #f3e5f5; stroke: #4a148c; stroke-width: 2px; }
      .handoff-node { fill: #fff3e0; stroke: #f57c00; stroke-width: 2px; }
      .start-end-node { fill: #e8f5e8; stroke: #388e3c; stroke-width: 2px; }
      .text { font-family: Arial, sans-serif; font-size: 12px; fill: #333; }
      .title { font-weight: bold; font-size: 14px; }
      .arrow { stroke: #666; stroke-width: 2px; fill: none; }
    </style>
    
    <!-- Start -->
    <circle cx="100" cy="80" r="30" class="start-end-node"/>
    <text x="100" y="130" text-anchor="middle" class="title">Start Task</text>
    
    <!-- Decision -->
    <rect x="200" y="50" width="120" height="60" class="agent-node" rx="8"/>
    <text x="260" y="75" text-anchor="middle" class="title">Agent Type</text>
    <text x="260" y="95" text-anchor="middle" class="text">Architect</text>
    
    <!-- Arrow -->
    <line x1="320" y1="80" x2="380" y2="80" class="arrow"/>
    <polygon points="375,80 385,75 385,85" class="arrow"/>
    
    <!-- Architect Process -->
    <rect x="400" y="50" width="100" height="40" class="process-node" rx="4"/>
    <text x="450" y="65" text-anchor="middle" class="text">Analyze</text>
    
    <line x1="500" y1="70" x2="550" y2="70" class="arrow"/>
    <polygon points="545,70 550,65 550,75" class="arrow"/>
    
    <rect x="560" y="50" width="100" height="40" class="process-node" rx="4"/>
    <text x="610" y="65" text-anchor="middle" class="text">Search</text>
    
    <line x1="660" y1="70" x2="710" y2="70" class="arrow"/>
    <polygon points="655,70 660,65 660,75" class="arrow"/>
    
    <rect x="720" y="50" width="100" height="40" class="process-node" rx="4"/>
    <text x="770" y="65" text-anchor="middle" class="text">Create Spec</text>
    
    <line x1="820" y1="70" x2="870" y2="70" class="arrow"/>
    <polygon points="815,70 820,65 820,75" class="arrow"/>
    
    <rect x="880" y="50" width="100" height="40" class="process-node" rx="4"/>
    <text x="930" y="65" text-anchor="middle" class="text">No File Writes</text>
    
    <!-- Continue to other agents... -->
    <text x="500" y="200" text-anchor="middle" class="text" font-style="italic">... continues to Builder, Validator, Scribe, Tech-Debt Scout</text>
  </svg>`
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

function generateDiagrams() {
  console.log('🎨 Generating simple SVG diagrams...\n');
  
  Object.entries(templates).forEach(([name, svg]) => {
    const svgPath = path.join(__dirname, '..', `diagrams/generated/svg/${name}.svg`);
    const pngPath = path.join(__dirname, '..', `diagrams/generated/png/${name}.png`);
    
    // Write SVG
    fs.writeFileSync(svgPath, svg);
    console.log(`✓ Generated SVG: ${name}`);
    
    // Simple PNG placeholder (would need proper rasterization library)
    const pngPlaceholder = `<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
      <rect width="400" height="300" fill="#f0f0f0"/>
      <text x="200" y="150" text-anchor="middle" fill="#666" font-family="Arial">PNG: ${name}</text>
    </svg>`;
    fs.writeFileSync(pngPath, pngPlaceholder);
    console.log(`✓ Generated PNG placeholder: ${name}`);
  });
  
  // Generate simple manifest
  const manifest = {
    generated: new Date().toISOString(),
    diagrams: Object.keys(templates).map(name => ({
      name: name.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
      category: name.includes('overview') ? 'architecture' : name.includes('pipeline') ? 'workflows' : 'other',
      svg: `/diagrams/generated/svg/${name}.svg`,
      png: `/diagrams/generated/png/${name}.png`
    }))
  };
  
  const manifestPath = path.join(__dirname, '..', 'diagrams/generated/manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  console.log(`✓ Generated manifest: ${manifestPath}`);
}

function main() {
  try {
    ensureDirectories();
    generateDiagrams();
    console.log('\n🎉 Simple diagram generation complete!');
  } catch (error) {
    console.error('❌ Generation failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { main, generateDiagrams };