#!/usr/bin/env node

/**
 * Diagram Generation Script
 * 
 * Generates SVG and PNG assets from Mermaid source files
 * for Anigma documentation visual enhancement.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const CONFIG = {
  sourceDir: path.join(__dirname, '../diagrams/source'),
  outputDir: path.join(__dirname, '../diagrams/generated'),
  svgDir: path.join(__dirname, '../diagrams/generated/svg'),
  pngDir: path.join(__dirname, '../diagrams/generated/png'),
  mermaidCli: path.join(__dirname, '../../node_modules/@mermaid-js/mermaid-cli/src/cli.js')
};

/**
 * Ensure output directories exist
 */
function ensureDirectories() {
  const dirs = [CONFIG.outputDir, CONFIG.svgDir, CONFIG.pngDir];
  dirs.forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
      console.log(`Created directory: ${dir}`);
    }
  });
}

/**
 * Find all Mermaid source files
 */
function findMermaidFiles() {
  const files = [];
  
  function scanDirectory(dir, category = '') {
    const items = fs.readdirSync(dir);
    
    for (const item of items) {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory()) {
        scanDirectory(fullPath, category ? `${category}/${item}` : item);
      } else       if (item.endsWith('.mmd')) {
        const basename = path.basename(item, '.mmd');
        files.push({
          source: fullPath,
          category: category,
          filename: basename,
          basename: basename
        });
      }
    }
  }
  
  scanDirectory(CONFIG.sourceDir);
  return files;
}

/**
 * Generate SVG from Mermaid source
 */
async function generateSVG(mermaidFile) {
  const outputPath = path.join(
    CONFIG.svgDir,
    mermaidFile.category,
    `${mermaidFile.filename}.svg`
  );
  
  // Ensure category directory exists
  const categoryDir = path.dirname(outputPath);
  if (!fs.existsSync(categoryDir)) {
    fs.mkdirSync(categoryDir, { recursive: true });
  }
  
  try {
    const command = [
      'node',
      CONFIG.mermaidCli,
      '--input', mermaidFile.source,
      '--output', outputPath,
      '--outputFormat', 'svg',
      '--theme', 'default',
      '--backgroundColor', 'transparent'
    ].join(' ');
    
    execSync(command, { stdio: 'inherit' });
    console.log(`✓ Generated SVG: ${outputPath}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to generate SVG for ${mermaidFile.source}:`, error.message);
    return false;
  }
}

/**
 * Generate PNG from Mermaid source
 */
async function generatePNG(mermaidFile) {
  const outputPath = path.join(
    CONFIG.pngDir,
    mermaidFile.category,
    `${mermaidFile.filename}.png`
  );
  
  // Ensure category directory exists
  const categoryDir = path.dirname(outputPath);
  if (!fs.existsSync(categoryDir)) {
    fs.mkdirSync(categoryDir, { recursive: true });
  }
  
  try {
    const command = [
      'node',
      CONFIG.mermaidCli,
      '--input', mermaidFile.source,
      '--output', outputPath,
      '--outputFormat', 'png',
      '--theme', 'default',
      '--backgroundColor', 'white',
      '--width', '1200'
    ].join(' ');
    
    execSync(command, { stdio: 'inherit' });
    console.log(`✓ Generated PNG: ${outputPath}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to generate PNG for ${mermaidFile.source}:`, error.message);
    return false;
  }
}

/**
 * Generate diagram manifest for VitePress
 */
function generateManifest(files) {
  const manifest = {
    generated: new Date().toISOString(),
    diagrams: files.map(file => ({
      category: file.category,
      name: file.basename,
      source: `/diagrams/source/${file.category}/${file.filename}.mmd`,
      svg: `/diagrams/generated/svg/${file.category}/${file.filename}.svg`,
      png: `/diagrams/generated/png/${file.category}/${file.filename}.png`
    }))
  };
  
  const manifestPath = path.join(CONFIG.outputDir, 'manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  console.log(`✓ Generated manifest: ${manifestPath}`);
}

/**
 * Main generation process
 */
async function main() {
  console.log('🎨 Starting diagram generation...\n');
  
  try {
    // Check if Mermaid CLI is available
    if (!fs.existsSync(CONFIG.mermaidCli)) {
      console.error('❌ Mermaid CLI not found. Please install: npm install -g @mermaid-js/mermaid-cli');
      process.exit(1);
    }
    
    // Setup directories
    ensureDirectories();
    
    // Find all source files
    const files = findMermaidFiles();
    console.log(`📁 Found ${files.length} Mermaid files\n`);
    
    // Generate SVGs
    console.log('🔄 Generating SVG files...');
    let svgSuccess = 0;
    for (const file of files) {
      if (await generateSVG(file)) svgSuccess++;
    }
    console.log(`✅ Generated ${svgSuccess}/${files.length} SVG files\n`);
    
    // Generate PNGs
    console.log('🔄 Generating PNG files...');
    let pngSuccess = 0;
    for (const file of files) {
      if (await generatePNG(file)) pngSuccess++;
    }
    console.log(`✅ Generated ${pngSuccess}/${files.length} PNG files\n`);
    
    // Generate manifest
    generateManifest(files);
    
    console.log('🎉 Diagram generation complete!');
    
  } catch (error) {
    console.error('❌ Generation failed:', error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { main, findMermaidFiles, generateSVG, generatePNG };