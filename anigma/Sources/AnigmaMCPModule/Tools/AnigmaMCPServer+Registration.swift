//
//  AnigmaMCPServer+Registration.swift
//  AnigmaMCPModule
//
//  Tool registration and listing for MCP server.
//

import Foundation
import MCP
import AnigmaPrimitives

extension AnigmaMCPServer {
    nonisolated func registerDefaultTools() {
        // 1. read_file
        toolRegistry.register(contract: ToolContract(
            toolName: "read_file",
            toolDescription: "Securely reads the content of a file within the project directory.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Relative path to the file to read" },
                    "cache": { "type": "boolean", "description": "Use cached content when available", "default": true }
                },
                "required": ["file_path"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["filesystem"]
        ))

        // 1.1 chat
        toolRegistry.register(contract: ToolContract(
            toolName: "chat",
            toolDescription: "Interact with local frontier ML models (Llama 3.1, Qwen 2.5, Phi-3.5).",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "message": { "type": "string", "description": "Message to send to the model" },
                    "model_id": {
                        "type": "string",
                        "description": "Model to use",
                        "enum": ["llama-3.1-8b-instruct-4bit", "qwen-2.5-7b-coder-4bit", "phi-3.5-mini-instruct-4bit"],
                        "default": "llama-3.1-8b-instruct-4bit"
                    },
                    "max_tokens": { "type": "integer", "default": 512 },
                    "temperature": { "type": "number", "default": 0.7 }
                },
                "required": ["message"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "inference"]
        ))

        // 2. swift_build
        toolRegistry.register(contract: ToolContract(
            toolName: "swift_build",
            toolDescription: "Triggers a deterministic build of a Swift package.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "package_path": { "type": "string", "description": "Path to the directory containing Package.swift" },
                    "target": { "type": "string", "description": "Optional target name to build" },
                    "configuration": { "type": "string", "enum": ["debug", "release"], "default": "debug" }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["shell", "build"]
        ))

        // 3. apply_patch
        toolRegistry.register(contract: ToolContract(
            toolName: "apply_patch",
            toolDescription: "Applies a unified diff patch with pre-flight validation for Swift concurrency, Sendable conformance, data races, and best practices.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "patch": { "type": "string", "description": "The unified diff patch content to apply" },
                    "target_files": { "type": "array", "items": { "type": "string" }, "description": "Optional allowlist of files to verify/apply" },
                    "rollback_on_failure": { "type": "boolean", "default": true, "description": "Rollback changes if verification or validation fails" },
                    "skip_validation": { "type": "boolean", "default": false, "description": "Skip Swift code validation (strict concurrency, Sendable, best practices)" }
                },
                "required": ["patch"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["filesystem", "write"],
            modifiesSystem: true
        ))

        // 4. git_diff
        toolRegistry.register(contract: ToolContract(
            toolName: "git_diff",
            toolDescription: "Inspects current changes in the repository.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Optional path filter" }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["shell", "git"]
        ))

        // 5. swift_test
        toolRegistry.register(contract: ToolContract(
            toolName: "swift_test",
            toolDescription: "Executes the project test suite.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "filter": { "type": "string", "description": "Specific test pattern to run" },
                    "verbose": { "type": "boolean", "description": "Enable verbose output", "default": false }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["shell", "test"]
        ))

        // 6. trace_query
        toolRegistry.register(contract: ToolContract(
            toolName: "trace_query",
            toolDescription: "Queries the system's execution history.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "taskId": { "type": "string" },
                    "limit": { "type": "integer", "default": 10 },
                    "offset": { "type": "integer", "default": 0 }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["database", "trace"]
        ))

        // 7. context_search
        toolRegistry.register(contract: ToolContract(
            toolName: "context_search",
            toolDescription: "Semantic and full-text search across project context.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "query": { "type": "string" },
                    "limit": { "type": "integer", "default": 10 }
                },
                "required": ["query"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["context", "search"]
        ))

        // 8. list_artifacts
        toolRegistry.register(contract: ToolContract(
            toolName: "list_artifacts",
            toolDescription: "Lists items in the project's artifact repository.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "media_type": { "type": "string" },
                    "limit": { "type": "integer", "default": 50 }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["artifacts", "read"]
        ))

        // 9. list_models
        toolRegistry.register(contract: ToolContract(
            toolName: "list_models",
            toolDescription: "Lists all registered local ML models.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "task": { "type": "string", "enum": ["inference", "embedding", "transcription", "classification", "image_generation", "speech_synthesis"] }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "read"]
        ))

        // 9.1 download_model
        toolRegistry.register(contract: ToolContract(
            toolName: "download_model",
            toolDescription: "Downloads a HuggingFace model into the local registry.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "repo": { "type": "string", "description": "HuggingFace repo id" },
                    "revision": { "type": "string", "description": "Repo revision", "default": "main" }
                },
                "required": ["repo"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "write"]
        ))

        // 9.2 import_local_model
        toolRegistry.register(contract: ToolContract(
            toolName: "import_local_model",
            toolDescription: "Registers a local model path into the registry.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Local file or directory path" },
                    "model_id": { "type": "string", "description": "Explicit model id" },
                    "task": { "type": "string", "enum": ["inference", "embedding", "transcription", "classification", "image_generation", "speech_synthesis"] },
                    "backend": { "type": "string", "enum": ["mlx", "gguf", "coreml"] },
                    "trust_tier": { "type": "string", "enum": ["first_class", "compatible", "experimental", "quarantined"] },
                    "license": { "type": "string", "description": "Declared license string" }
                },
                "required": ["path"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "write"]
        ))

        // 9.3 delete_model
        toolRegistry.register(contract: ToolContract(
            toolName: "delete_model",
            toolDescription: "Deletes a model from the registry (optionally deletes files).",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" },
                    "delete_files": { "type": "boolean", "default": false }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "write"]
        ))

        // 9.4 verify_model
        toolRegistry.register(contract: ToolContract(
            toolName: "verify_model",
            toolDescription: "Verifies model integrity against stored hashes.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "read"]
        ))

        // 9.5 run_model
        toolRegistry.register(contract: ToolContract(
            toolName: "run_model",
            toolDescription: "Runs a model inference task using ml-worker.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" },
                    "task": { "type": "string", "enum": ["chat", "summarize", "classify", "transcribe"], "default": "chat" },
                    "prompt": { "type": "string" },
                    "input_path": { "type": "string" },
                    "seed": { "type": "integer", "default": 42 },
                    "max_tokens": { "type": "integer" },
                    "temperature": { "type": "number" },
                    "top_p": { "type": "number" },
                    "output_dir": { "type": "string" },
                    "output_path": { "type": "string" }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "inference"]
        ))

        // 9.6 run_embedding
        toolRegistry.register(contract: ToolContract(
            toolName: "run_embedding",
            toolDescription: "Generates embeddings using a registered model.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" },
                    "text": { "type": "string" },
                    "input_path": { "type": "string" },
                    "seed": { "type": "integer", "default": 42 },
                    "output_dir": { "type": "string" }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "embedding"]
        ))

        // 10. digest_codebase
        toolRegistry.register(contract: ToolContract(
            toolName: "digest_codebase",
            toolDescription: "Crawls and indexes the entire project for searchable knowledge.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "path": { "type": "string" }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["context", "indexing"]
        ))

        // 10.1 codebase_index_purge
        toolRegistry.register(contract: ToolContract(
            toolName: "codebase_index_purge",
            toolDescription: "Clears the codebase index and optional search history.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "include_search_history": { "type": "boolean", "default": false }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["context", "administrative"]
        ))

        // 11. context_purge
        toolRegistry.register(contract: ToolContract(
            toolName: "context_purge",
            toolDescription: "Clears the search index.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["context", "administrative"]
        ))

        // 12. get_system_health
        toolRegistry.register(contract: ToolContract(
            toolName: "get_system_health",
            toolDescription: "Retrieves overall system health summary.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["observability", "health"]
        ))

        // 13. list_active_alerts
        toolRegistry.register(contract: ToolContract(
            toolName: "list_active_alerts",
            toolDescription: "Lists active system alerts.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["observability", "alerts"]
        ))

        // 14. database_query
        toolRegistry.register(contract: ToolContract(
            toolName: "database_query",
            toolDescription: "Executes read-only SQL query against project database.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "sql": { "type": "string" },
                    "parameters": { "type": "object", "additionalProperties": { "type": "string" } }
                },
                "required": ["sql"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["database", "read"]
        ))

        // 15. create_tool_contract
        toolRegistry.register(contract: ToolContract(
            toolName: "create_tool_contract",
            toolDescription: "Dynamically registers a new tool capability.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "name": { "type": "string" },
                    "description": { "type": "string" },
                    "input_schema_json": { "type": "string" },
                    "capabilities": { "type": "array", "items": { "type": "string" } }
                },
                "required": ["name", "description", "input_schema_json"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["governance", "registration"]
        ))

        // 16. verify_evidence_chain
        toolRegistry.register(contract: ToolContract(
            toolName: "verify_evidence_chain",
            toolDescription: "Verifies integrity of operation history for a session.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "session_id": { "type": "string" }
                },
                "required": ["session_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["governance", "verification"]
        ))

        // 17. get_module_status
        toolRegistry.register(contract: ToolContract(
            toolName: "get_module_status",
            toolDescription: "Returns initialization status of MCP server modules.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["mcp", "status"]
        ))

        // 18. delegate
        toolRegistry.register(contract: ToolContract(
            toolName: "delegate",
            toolDescription: "Delegates a task to a specialized sub-agent (CLI wrapper or cloud API).",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "summary": { "type": "string", "description": "Short summary of the task to delegate" },
                    "details": { "type": "string", "description": "Detailed instructions for the sub-agent" },
                    "providerId": { "type": "string", "description": "Optional: force a specific provider (e.g. 'cloud-deepseek')" },
                    "requiredCapabilities": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional: capabilities required (e.g. ['chat', 'tools'])"
                    }
                },
                "required": ["summary"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["orchestration", "delegation"]
        ))
    }

    func getTools() -> [MCP.Tool] {
        return AnigmaMCPBridge().getTools()
    }
}
