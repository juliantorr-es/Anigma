#!/usr/bin/env python3
import json
import subprocess
import os
import sys

def main():
    # Find the binary
    binary_paths = [
        ".build/arm64-apple-macosx/release/anigma-mcp",
        ".build/release/anigma-mcp",
        "anigma-mcp"
    ]
    
    binary = None
    for path in binary_paths:
        if os.path.exists(path):
            binary = path
            break
            
    if not binary:
        print("Error: anigma-mcp binary not found. Build it with 'swift build -c release --product anigma-mcp'")
        sys.exit(1)
        
    # Call tools/list
    payload = {"jsonrpc": "2.0", "method": "tools/list", "id": 1, "params": {}}
    process = subprocess.Popen(
        [binary],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    stdout, stderr = process.communicate(input=json.dumps(payload))
    
    # Filter stdout to find the JSON line
    json_response = None
    for line in stdout.splitlines():
        line = line.strip()
        if line.startswith('{"id":') or (line.startswith('{') and '"jsonrpc":"2.0"' in line):
            try:
                json_response = json.loads(line)
                if "result" in json_response:
                    break
            except:
                continue
            
    if not json_response or "result" not in json_response:
        print(f"Error: Could not get tools from binary.\nStdout: {stdout}\nStderr: {stderr}")
        sys.exit(1)
        
    mcp_tools = json_response["result"]["tools"]
    gemini_tools = []
    
    for tool in mcp_tools:
        gemini_tool = {
            "name": tool["name"],
            "description": tool["description"],
            "parameters": tool["inputSchema"]
        }
        # Gemini expects 'type' in uppercase for some versions, but 'object' is standard.
        # Ensure it has 'type': 'object'
        if "type" not in gemini_tool["parameters"]:
            gemini_tool["parameters"]["type"] = "object"
            
        gemini_tools.append(gemini_tool)
        
    print(json.dumps(gemini_tools, indent=2))

if __name__ == "__main__":
    main()
