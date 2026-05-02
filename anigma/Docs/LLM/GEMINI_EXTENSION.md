# Gemini Extension: Anigma MCP

## Mandatory: TD + Sidecar Workflow

This repository uses Sidecar `td` for task and session coordination. Reference: https://sidecar.haplab.com/docs/td

1. Start of every conversation/context window (or after `/clear`):
   ```bash
   td usage --new-session
   ```
2. Use a quiet status check after setup:
   ```bash
   td usage -q
   ```
3. Start implementation on a tracked issue:
   ```bash
   td start <issue-id>
   # Multi-issue work:
   td ws start "<work-session-name>"
   td ws tag <issue-id> [issue-id...]
   ```
4. Log progress as you go:
   ```bash
   td log "<progress note>"
   # or: td ws log "<progress note>"
   ```
5. Before ending context, record handoff (required):
   ```bash
   td handoff <issue-id> \
     --done "<completed and tested work>" \
     --remaining "<specific pending tasks>" \
     --decision "<why this approach was chosen>" \
     --uncertain "<open questions>"
   # or: td ws handoff
   ```
6. Completion flow: implementer runs `td review <issue-id>`; a different session runs `td approve <issue-id>`.
7. Never use `td close` for completed implementation work. Use `td close` only for admin closures (duplicate/won't-fix/cleanup).
8. Do not start a new session mid-work unless you are intentionally beginning a new context.

This extension allows Gemini (via Google AI Studio, Vertex AI, or Gemini API) to use the **Anigma MCP** tools.

## What is included?

**17 powerful tools** that give Gemini full access to the Anigma stack:
- **Codebase Indexing**: `digest_codebase`
- **Semantic Search**: `context_search`
- **Build & Test**: `swift_build`, `swift_test`
- **Governance & Evidence**: `verify_evidence_chain`, `get_module_status`
- **Code Modification**: `apply_patch` (unified diffs)
- **Data Access**: `database_query`, `read_file`, `list_artifacts`
- **Monitoring**: `get_system_health`, `list_active_alerts`

## Setup Instructions

### Option 1: Google AI Studio (Fastest)

1. Open [Google AI Studio](https://aistudio.google.com/).
2. Create a new prompt or select an existing one.
3. In the right-hand panel, click on **Tools** or **Function Calling**.
4. Click **Add Function**.
5. Copy and paste the contents of `gemini_tools.json` from this repository.
6. Note: You may need to provide a hosted URL for the MCP server if you want it to work in the cloud, or use a local proxy like `ngrok` if you are running the model locally.

### Option 2: Gemini CLI (Google Official)

If you are using the [gemini-cli](https://github.com/google-gemini/gemini-cli), you can use the local extension or point it to the bridge.

**Method A: Local Extension (Fastest)**
1. Ensure `anigma-mcp` is in your PATH.
2. Run gemini with the local extension:
   ```bash
   gemini --extension extension/index.js "How is the system health?"
   ```

**Method B: Using the Bridge (Recommended for multi-tool)**
1. Start the bridge:
   ```bash
   .build/release/anigma-gemini-bridge --port 8080 &
   ```
2. Configure your `gemini.config.json` (created in project root) to point to the bridge or include the functions directly.

### Option 3: Project Configuration
A `gemini.config.json` has been provided in the project root which includes all 17 anigma-mcp tool definitions for use with compatible Gemini clients.

When initializing the Gemini model in your code, include the tool definitions:

```python
import google.generativeai as genai
import json

# Load the generated tools
with open('gemini_tools.json', 'r') as f:
    tools_config = json.load(f)

model = genai.GenerativeModel(
    model_name='gemini-1.5-pro',
    tools=tools_config['tools']
)

# Start a chat
chat = model.start_chat()
response = chat.send_message("What is the current system health?")
print(response.text)
```

## How to Update Tools

If you add new tools to the `anigma-mcp` binary, run the update script:

```bash
bash Scripts/setup_gemini_extension.sh
```

This will rebuild the binary and regenerate `gemini_tools.json`.

## Technical Details

- **Format**: Gemini Function Declarations (JSON)
- **Compatibility**: Gemini 1.5 Pro, Gemini 1.5 Flash
- **Architecture**: MCP JSON-RPC over Standard I/O (bridged via API)
