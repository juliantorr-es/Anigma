#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

function startDevServer() {
  console.log('🚀 Starting VitePress development server...');
  
  const devProcess = spawn('npx', ['vitepress', 'dev'], {
    cwd: path.resolve(__dirname, '..'),
    stdio: 'inherit',
    shell: true
  });
  
  devProcess.on('error', (error) => {
    console.error('❌ Failed to start dev server:', error.message);
    process.exit(1);
  });
  
  devProcess.on('close', (code) => {
    console.log(`📚 Dev server exited with code ${code}`);
  });
  
  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down dev server...');
    devProcess.kill('SIGINT');
  });
  
  process.on('SIGTERM', () => {
    console.log('\n🛑 Shutting down dev server...');
    devProcess.kill('SIGTERM');
  });
}

if (require.main === module) {
  startDevServer();
}

module.exports = { startDevServer };