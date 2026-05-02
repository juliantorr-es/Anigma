const http = require('http');
const { spawn } = require('child_process');

/**
 * Anigma Gemini Extension
 * 
 * This extension forwards Gemini CLI tool calls to the Anigma bridge or binary.
 * Priority:
 * 1. HTTP Bridge (anigma-gemini-bridge) at localhost:8080
 * 2. Local daemon (anigmad --mcp) via subprocess
 */

const BRIDGE_URL = process.env.ANIGMA_BRIDGE_URL || 'http://localhost:8080';
const USE_BRIDGE = process.env.ANIGMA_USE_BRIDGE !== 'false';

/**
 * Execute tool via HTTP Bridge
 */
async function executeViaBridge(name, args) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${BRIDGE_URL}/v1/tools/call`);
    const data = JSON.stringify({ name, arguments: args });

    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
        timeout: 30000,
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
          try {
            const json = JSON.parse(body);
            if (json.error) {
              reject(new Error(json.error));
            } else {
              // Extract the result from the bridge response format
              // Bridge returns: { name: "...", response: { content: "...", success: true } }
              resolve(json.response || json);
            }
          } catch (e) {
            reject(new Error(`Failed to parse bridge response: ${body}`));
          }
        });
      }
    );

    req.on('error', (e) => reject(e));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Bridge request timed out'));
    });
    req.write(data);
    req.end();
  });
}

/**
 * Execute tool via local binary subprocess (Fallback)
 */
async function executeViaBinary(name, args) {
  return new Promise((resolve, reject) => {
    const process = spawn('anigmad', ['--mcp', name, JSON.stringify(args)]);
    let output = '';
    let error = '';

    process.stdout.on('data', (data) => output += data);
    process.stderr.on('data', (data) => error += data);

    process.on('close', (code) => {
      if (code !== 0) reject(new Error(error || 'Process exited with code ' + code));
      try {
        resolve(JSON.parse(output));
      } catch (e) {
        resolve(output); // Return raw if not JSON
      }
    });
  });
}

/**
 * Main execution entry point with fallback
 */
async function executeTool(name, args) {
  if (USE_BRIDGE) {
    try {
      return await executeViaBridge(name, args);
    } catch (e) {
      if (e.code === 'ECONNREFUSED' || e.message.includes('ECONNREFUSED')) {
        console.warn(`⚠️  Anigma bridge not found at ${BRIDGE_URL}, falling back to local binary...`);
      } else {
        throw e;
      }
    }
  }
  return await executeViaBinary(name, args);
}

module.exports = {
  // Map Gemini CLI tool calls to our execution bridge
  ...Object.fromEntries(
    [
      "trace_query", "digest_codebase", "list_models", "get_system_health", 
      "create_tool_contract", "list_artifacts", "context_purge", "get_module_status", 
      "context_search", "apply_patch", "database_query", "read_file", 
      "swift_test", "git_diff", "swift_build", "list_active_alerts", "verify_evidence_chain"
    ].map(name => [
      name, 
      (args) => executeTool(name, args)
    ])
  )
};
