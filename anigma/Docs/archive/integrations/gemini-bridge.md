# Gemini + anigma-mcp Bridge (In Development)

This guide covers the HTTP bridge server that will enable Google Gemini API to use anigma-mcp tools locally.

## Status

🔄 **In Development** - Bridge server skeleton is being built in `Packages/AnigmaGeminiBridge/`

## Architecture

```
┌──────────────────────┐
│  Gemini API Client   │
│  (Python, Node, etc) │
└──────────┬───────────┘
           │ HTTP REST
           ▼
┌──────────────────────────────────────┐
│   anigma-gemini-bridge Server        │
│   Translates Gemini ↔ MCP protocols  │
└──────────┬───────────────────────────┘
           │ JSON-RPC stdio
           ▼
┌──────────────────────┐
│  anigma-mcp Server   │
│  (17 tools)          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  PlatformRuntime     │
│  + Governance        │
│  + Evidence          │
└──────────────────────┘
```

## What You'll Be Able To Do

Once complete, you'll use Gemini's API to access anigma-mcp tools locally:

```python
import requests

# Start the bridge first:
# .build/release/anigma-gemini-bridge --port 8080

BRIDGE_URL = "http://localhost:8080"

# List available tools
response = requests.get(f"{BRIDGE_URL}/v1/tools")
tools = response.json()
print(f"Found {len(tools['function_declarations'])} tools")

# Call a tool
response = requests.post(
    f"{BRIDGE_URL}/v1/tools/call",
    json={
        "name": "read_file",
        "arguments": {"file_path": "CLAUDE.md"}
    }
)

result = response.json()
print(result["response"]["content"])
```

## Development Status

### Completed ✅
- Package structure (`Packages/AnigmaGeminiBridge/`)
- HTTP routing skeleton (Hummingbird)
- MCP client foundation (subprocess management)
- Protocol translation helpers

### In Progress 🔄
- Complete HTTP request handling
- Robust JSON-RPC communication
- Full protocol translation
- Error handling and logging

### TODO
- Testing and verification
- Performance optimization
- Documentation
- Example scripts

## API Endpoints (When Ready)

### GET /health
Health check endpoint

```bash
curl http://localhost:8080/health
# { "status": "healthy", "message": "..." }
```

### GET /v1/tools
List available tools in Gemini Function Calling format

```bash
curl http://localhost:8080/v1/tools
# {
#   "function_declarations": [
#     { "name": "read_file", "description": "...", "parameters": {...} },
#     ...
#   ]
# }
```

### POST /v1/tools/call
Execute a tool via Gemini format

```bash
curl -X POST http://localhost:8080/v1/tools/call \
  -H "Content-Type: application/json" \
  -d '{
    "name": "read_file",
    "arguments": {"file_path": "/path/to/file.txt"}
  }'
# {
#   "name": "read_file",
#   "response": { "content": "...", "success": true }
# }
```

### GET /metrics
Get bridge metrics and statistics

```bash
curl http://localhost:8080/metrics
# { "uptime": 3600, "status": "running", ... }
```

## Building the Bridge (Once Ready)

```bash
# Build the bridge
swift build -c release --product anigma-gemini-bridge

# Run it
.build/release/anigma-gemini-bridge --port 8080

# In another terminal, test it
curl http://localhost:8080/health
```

## Using with Gemini API

### Python Example

```python
import requests
import os
from google import genai

# Start the bridge
os.system(".build/release/anigma-gemini-bridge &")

# Configure Gemini client
client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

# Define anigma tools via bridge
response = requests.get("http://localhost:8080/v1/tools")
tools_schema = response.json()

# Create a client with our tools
model = client.models.generate_content_config(
    model="gemini-2.5-pro",
    tools=tools_schema  # Gemini function declarations
)

# Now Gemini can call anigma-mcp tools
response = model.generate_content(
    "Read the CLAUDE.md file using anigma and summarize it"
)
```

### Node.js Example

```javascript
const axios = require('axios');
const { GoogleGenerativeAI } = require("@google/generative-ai");

const BRIDGE_URL = "http://localhost:8080";

// Get tools from bridge
const toolsRes = await axios.get(`${BRIDGE_URL}/v1/tools`);
const tools = toolsRes.data.function_declarations;

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({
  model: "gemini-2.5-pro",
  tools: tools,
});

// Make a request
const result = await model.generateContent(
  "Use anigma tools to search for TODO comments"
);
```

## Benefits

✅ **Keep data local** - No cloud processing of your code
✅ **Use Gemini's capabilities** - Advanced reasoning + local tools
✅ **Hybrid approach** - Inference in cloud, tools run locally
✅ **Zero setup hassle** - Bridge handles protocol translation
✅ **Full governance** - All operations logged and audited

## Comparison

| Aspect | Cloud-Only | Local MCP | Bridge |
|--------|-----------|----------|--------|
| Data Privacy | No | Yes | Yes* |
| Processing | Remote | Local | Local |
| Latency | Network-bound | Fast | Fast + inference |
| Cost | Per-request | Free | Free (+ Gemini API) |
| Control | Limited | Full | Full |

*Bridge sends queries to Gemini Cloud, but tool execution stays local

## Roadmap

1. **Phase 1:** Complete HTTP server (Hummingbird integration)
2. **Phase 2:** Full protocol translation (Gemini ↔ MCP)
3. **Phase 3:** Error handling and resilience
4. **Phase 4:** Testing and documentation
5. **Phase 5:** Performance optimization
6. **Phase 6:** Production release

## Contributing

Interested in helping develop the bridge?

Areas to help:
- Complete HTTP request handling
- Protocol translation edge cases
- Error handling and logging
- Testing and benchmarking
- Documentation and examples

## Troubleshooting (When Available)

### Bridge won't start

```bash
# Check port
lsof -i :8080

# Check anigma-mcp binary
/usr/local/bin/anigma-mcp
```

### Tool calls timeout

Default timeout is 30 seconds. For longer operations:
```python
response = requests.post(
    f"{BRIDGE_URL}/v1/tools/call",
    json={...},
    timeout=60  # Increase timeout
)
```

### Empty tool results

Rebuild codebase index first:
```
POST /v1/tools/call with name: "digest_codebase"
```

## Integration Examples

Coming soon:

- Gemini CLI wrapper
- Jupyter notebook extension
- VS Code extension
- GitHub Actions integration
- CI/CD pipeline integration

## Next Steps

1. ✅ Claude Desktop - Working
2. ✅ Codex CLI - Working
3. ✅ Zed Editor - [Configure it](./zed-editor.md)
4. 🔄 Gemini Bridge - [Track progress](https://github.com/your-repo)

## More Information

- [Main Integration Guide](../AI_TOOLS_INTEGRATION.md)
- [Claude Desktop Setup](./claude-desktop.md)
- [Codex CLI Setup](./codex-cli.md)
- [Zed Editor Setup](./zed-editor.md)
- [Bridge Source Code](../Packages/AnigmaGeminiBridge/)
