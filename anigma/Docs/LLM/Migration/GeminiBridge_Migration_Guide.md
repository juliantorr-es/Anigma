# AnigmaGeminiBridge Migration Guide

## Overview

This guide provides instructions for migrating from the legacy `AnigmaGeminiBridge` to the new unified LLM Provider Framework introduced in Phase 6.

## Retirement Notice

**🚫 RETIRED**: `AnigmaGeminiBridge` has been **completely removed** from the codebase as of Phase 6 completion. All Gemini functionality has been **fully migrated** to the new `GeminiProvider` class which is part of the unified LLM Provider Framework.

## Migration Timeline

- **Phase 6 (Completed)**: New unified LLM Provider Framework introduced
- **Phase 6 (Completed)**: AnigmaGeminiBridge fully retired and removed
- **Current Status**: All code now uses the new unified framework

**Important**: The AnigmaGeminiBridge has been physically removed from the codebase. Any remaining references in your code must be migrated immediately.

## Key Changes

### Before (Legacy AnigmaGeminiBridge)

```swift
// Old approach using AnigmaGeminiBridge
let bridge = AnigmaGeminiBridge(apiKey: "your-api-key")
let input = AnigmaGeminiBridgeWorkerInput(
    requestId: "req-123",
    operation: .generateContent,
    payload: ["prompt": "Hello, world!", "model": "gemini-pro"],
    clientId: "client-1"
)

let result = try await bridge.executeOperation(input, port: 8080)
```

### After (New Unified LLM Provider Framework)

```swift
// New approach using GeminiProvider
var provider = GeminiProvider(apiKey: "your-api-key")

let request = GenerateContentRequest(
    model: "gemini-3.1-pro",
    prompt: "Hello, world!",
    maxTokens: 1000,
    temperature: 0.7
)

let response = try await provider.generateContent(request: request)
print("Generated content: \\(response.content)")
```

## Migration Steps

### 1. Update Imports

**Before:**
```swift
import AnigmaGeminiBridge
```

**After:**
```swift
import SubprocessPooling
```

### 2. Replace Bridge Initialization

**Before:**
```swift
let bridge = AnigmaGeminiBridge(apiKey: "your-api-key")
```

**After:**
```swift
var provider = GeminiProvider(apiKey: "your-api-key")
```

### 3. Update Generate Content Calls

**Before:**
```swift
let input = AnigmaGeminiBridgeWorkerInput(
    requestId: "req-123",
    operation: .generateContent,
    payload: [
        "prompt": "Write a poem about Swift",
        "model": "gemini-pro",
        "maxTokens": 500
    ],
    clientId: "client-1"
)

let result = try await bridge.executeOperation(input, port: 8080)
if let content = result["content"] as? String {
    print(content)
}
```

**After:**
```swift
let request = GenerateContentRequest(
    model: "gemini-3.1-pro",
    prompt: "Write a poem about Swift",
    maxTokens: 500,
    temperature: 0.7
)

let response = try await provider.generateContent(request: request)
print("Generated content: \\(response.content)")
print("Usage: \\(response.usage.inputTokens) input tokens, \\(response.usage.outputTokens) output tokens")
```

### 4. Update Model Listing

**Before:**
```swift
let input = AnigmaGeminiBridgeWorkerInput(
    requestId: "req-123",
    operation: .listModels,
    payload: nil,
    clientId: "client-1"
)

let result = try await bridge.executeOperation(input, port: 8080)
if let models = result["models"] as? [[String: Any]] {
    for model in models {
        print(model["name"] as? String ?? "")
    }
}
```

**After:**
```swift
let models = try await provider.listModels()
for model in models {
    print("\\(model.name) (\\(model.id)) - Max tokens: \\(model.maxTokens)")
}
```

### 5. Update Embedding Creation

**Before:**
```swift
let input = AnigmaGeminiBridgeWorkerInput(
    requestId: "req-123",
    operation: .generateContent, // No direct embedding support
    payload: [
        "prompt": "Embed this text",
        "model": "embedding-001"
    ],
    clientId: "client-1"
)

let result = try await bridge.executeOperation(input, port: 8080)
```

**After:**
```swift
let embeddingRequest = EmbeddingRequest(
    model: "embedding-002",
    input: "Embed this text"
)

let embeddingResponse = try await provider.createEmbedding(request: embeddingRequest)
print("Embedding dimension: \\(embeddingResponse.embedding.count)")
```

## API Changes Summary

### Deprecated Operations

| Legacy Operation | New Equivalent |
|----------------|----------------|
| `generateContent` | `provider.generateContent()` |
| `listModels` | `provider.listModels()` |
| `getModel` | `provider.supportedModels.contains()` |
| `startChat` | Use conversation management in client |
| `sendMessage` | Use conversation management in client |

### New Features Available

- **Unified Interface**: All LLM providers use the same interface
- **Better Error Handling**: Comprehensive error types and handling
- **Rate Limiting**: Built-in rate limiting per provider
- **Metrics**: Detailed usage metrics and provider health checks
- **Tool Calling**: Native support for function/tool calling
- **Multiple Providers**: Easy to switch between Gemini, Claude, OpenAI, etc.

## Daemon HTTP Endpoints

The new framework provides HTTP endpoints through the daemon:

### Generate Content
```bash
POST /llm/generate
{
  "ctx": {...},
  "provider": "gemini",
  "model": "gemini-3.1-pro",
  "prompt": "Your prompt here"
}
```

### List Models
```bash
POST /llm/models/list
{
  "ctx": {...},
  "provider": "gemini"
}
```

### Create Embedding
```bash
POST /llm/embedding/create
{
  "ctx": {...},
  "provider": "gemini",
  "model": "embedding-002",
  "input": "Text to embed"
}
```

## Backward Compatibility

### Migration Path for Existing Code

1. **Identify all AnigmaGeminiBridge usages** in your codebase
2. **Replace with GeminiProvider** using the patterns above
3. **Update error handling** to use the new `LLMProviderError` types
4. **Test thoroughly** with the new provider
5. **Remove AnigmaGeminiBridge imports** once migration is complete

### Feature Parity

| Feature | Legacy Bridge | New Provider |
|---------|--------------|--------------|
| Content Generation | ✅ | ✅ (Enhanced) |
| Model Listing | ✅ | ✅ (Enhanced) |
| Embedding | ❌ | ✅ (New) |
| Tool Calling | ❌ | ✅ (New) |
| Rate Limiting | ❌ | ✅ (New) |
| Metrics | ❌ | ✅ (New) |
| Health Checks | ❌ | ✅ (New) |

## Testing the Migration

### Test Script

```swift
import XCTest
import SubprocessPooling

func testGeminiMigration() async {
    // Initialize the new provider
    var provider = GeminiProvider(apiKey: "test-key")
    
    // Test model listing
    let models = try? await provider.listModels()
    XCTAssertNotNil(models)
    XCTAssertFalse(models?.isEmpty ?? true)
    
    // Test content generation
    let request = GenerateContentRequest(
        model: "gemini-3.1-pro",
        prompt: "Hello from migration test!"
    )
    
    let response = try? await provider.generateContent(request: request)
    XCTAssertNotNil(response)
    XCTAssertFalse(response?.content.isEmpty ?? true)
    
    // Test embedding
    let embeddingRequest = EmbeddingRequest(
        model: "embedding-002",
        input: "Test embedding"
    )
    
    let embeddingResponse = try? await provider.createEmbedding(request: embeddingRequest)
    XCTAssertNotNil(embeddingResponse)
    XCTAssertGreaterThan(embeddingResponse?.embedding.count ?? 0, 0)
    
    print("✅ Migration test passed!")
}
```

## Troubleshooting

### Common Issues

1. **Missing API Key**: Ensure you're passing the correct API key to the provider
2. **Model Not Found**: Check that you're using supported model IDs from `provider.supportedModels`
3. **Rate Limiting**: The new provider has built-in rate limiting (60 requests/minute by default)
4. **Token Errors**: Make sure your API key is valid and has the required permissions

### Error Handling

```swift
do {
    let response = try await provider.generateContent(request: request)
    // Success
} catch let error as LLMProviderError {
    switch error {
    case .invalidAPIKey:
        print("Invalid API key")
    case .rateLimitExceeded(let provider, let retryAfter):
        print("Rate limited. Retry after \\(retryAfter) seconds")
    case .modelNotFound(let provider, let model):
        print("Model \\(model) not found for provider \\(provider)")
    // Handle other cases...
    }
} catch {
    print("Unexpected error: \\(error)")
}
```

## Deprecation Warnings

In Phase 7, the following deprecation warnings will be added:

```swift
@available(*, deprecated, message: "Use GeminiProvider from the unified LLM Provider Framework instead")
public class AnigmaGeminiBridge { ... }
```

## Removal Plan

**Phase 8**: Complete removal of `AnigmaGeminiBridge` and all related code:
- Remove `AnigmaGeminiBridgeWorker.swift`
- Remove any remaining references in build systems
- Update documentation to remove legacy references

## Support

For migration assistance or issues, please:
1. Check the [Phase 6 Documentation](../Phase6_Unified_LLM_Framework.md)
2. Review the [LLM Provider API Reference](../../API/LLM_Provider_API.md)
3. Open an issue with the `migration` tag if you encounter problems

## Checklist

- [ ] Identified all AnigmaGeminiBridge usages in codebase
- [ ] Replaced with GeminiProvider equivalents
- [ ] Updated error handling for new error types
- [ ] Tested content generation with new provider
- [ ] Tested model listing with new provider
- [ ] Tested embedding creation (if used)
- [ ] Updated any daemon HTTP calls to use new endpoints
- [ ] Removed AnigmaGeminiBridge imports
- [ ] Verified all tests pass with new implementation
- [ ] Updated documentation and comments

## Conclusion

The migration from `AnigmaGeminiBridge` to the new `GeminiProvider` offers significant improvements:
- **Unified interface** across all LLM providers
- **Better performance** with direct API calls
- **Enhanced features** like embedding, tool calling, and rate limiting
- **Improved error handling** and metrics
- **Future-proof** architecture for adding new providers

While the migration requires code changes, the new framework provides a much more robust and maintainable foundation for LLM integration in Anigma.