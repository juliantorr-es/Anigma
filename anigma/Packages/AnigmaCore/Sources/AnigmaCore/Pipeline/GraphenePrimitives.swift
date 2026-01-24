//
//  GraphenePrimitives.swift
//  AnigmaCore
//
//  Lower-level primitive nodes for composability.
//
//  These are the building blocks that higher-level AI nodes
//  and subgraphs are composed from. Following Graphite's
//  pattern of small, composable primitives.
//

import Foundation

// MARK: - Primitive Node Registration

/// Registers lower-level primitive nodes for AI composition.
public struct PrimitiveNodeRegistrar {

    public static func registerAll(registry: NodeRegistry) async {
        await registerTokenizationNodes(registry: registry)
        await registerPromptNodes(registry: registry)
        await registerVectorNodes(registry: registry)
        await registerTransformNodes(registry: registry)
        await registerUtilityNodes(registry: registry)
    }

    // MARK: - Tokenization Primitives

    private static func registerTokenizationNodes(registry: NodeRegistry) async {
        // Token Count node
        let tokenCount = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Tokenization", name: "TokenCount"),
            displayName: "Count Tokens",
            description: "Count the number of tokens in text for a given model",
            category: "Primitives/Tokenization",
            inputs: [
                InputPortDef(name: "text", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "count", type: NumberPort.self)
            ],
            parameters: [
                NodeParameter(name: "tokenizer", type: .choice, defaultValue: .choice("cl100k_base", options: ["cl100k_base", "llama", "gpt2"]))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: tokenCount, executor: TokenCountExecutor())

        // Truncate to Tokens node
        let truncate = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Tokenization", name: "TruncateToTokens"),
            displayName: "Truncate to Tokens",
            description: "Truncate text to a maximum number of tokens",
            category: "Primitives/Tokenization",
            inputs: [
                InputPortDef(name: "text", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "truncated", type: TextPort.self),
                OutputPortDef(name: "wasTruncated", type: BoolPort.self)
            ],
            parameters: [
                NodeParameter(name: "maxTokens", type: .integer, defaultValue: .integer(2048)),
                NodeParameter(name: "tokenizer", type: .choice, defaultValue: .choice("cl100k_base", options: ["cl100k_base", "llama", "gpt2"]))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: truncate, executor: TruncateToTokensExecutor())
    }

    // MARK: - Prompt Primitives

    private static func registerPromptNodes(registry: NodeRegistry) async {
        // Prompt Template node (more powerful than basic TextTemplate)
        let promptTemplate = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Prompt", name: "PromptTemplate"),
            displayName: "Prompt Template",
            description: "Build a prompt from a template with variable substitution",
            category: "Primitives/Prompt",
            inputs: [
                InputPortDef(name: "variables", type: JsonPort.self, isRequired: false)
            ],
            outputs: [
                OutputPortDef(name: "prompt", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "template", type: .text, defaultValue: .text("{{system}}\n\n{{user}}")),
                NodeParameter(name: "delimiterStart", type: .text, defaultValue: .text("{{")),
                NodeParameter(name: "delimiterEnd", type: .text, defaultValue: .text("}}"))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: promptTemplate, executor: PromptTemplateExecutor())

        // Chat Messages Builder node
        let chatMessages = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Prompt", name: "ChatMessagesBuilder"),
            displayName: "Build Chat Messages",
            description: "Build a chat messages array for LLM APIs",
            category: "Primitives/Prompt",
            inputs: [
                InputPortDef(name: "systemPrompt", type: TextPort.self, isRequired: false),
                InputPortDef(name: "userMessage", type: TextPort.self),
                InputPortDef(name: "history", type: JsonPort.self, isRequired: false)
            ],
            outputs: [
                OutputPortDef(name: "messages", type: JsonPort.self)
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: chatMessages, executor: ChatMessagesBuilderExecutor())

        // System Prompt node
        let systemPrompt = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Prompt", name: "SystemPrompt"),
            displayName: "System Prompt",
            description: "Define a system prompt for LLM behavior",
            category: "Primitives/Prompt",
            inputs: [],
            outputs: [
                OutputPortDef(name: "prompt", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "prompt", type: .text, defaultValue: .text("You are a helpful assistant."))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: systemPrompt, executor: SystemPromptExecutor())
    }

    // MARK: - Vector Primitives

    private static func registerVectorNodes(registry: NodeRegistry) async {
        // Cosine Similarity node
        let cosineSim = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Vector", name: "CosineSimilarity"),
            displayName: "Cosine Similarity",
            description: "Calculate cosine similarity between two vectors",
            category: "Primitives/Vector",
            inputs: [
                InputPortDef(name: "a", type: TensorPort.self),
                InputPortDef(name: "b", type: TensorPort.self)
            ],
            outputs: [
                OutputPortDef(name: "similarity", type: NumberPort.self)
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: cosineSim, executor: CosineSimilarityExecutor())

        // Top-K Selection node
        let topK = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Vector", name: "TopK"),
            displayName: "Top-K Selection",
            description: "Select top K items by score",
            category: "Primitives/Vector",
            inputs: [
                InputPortDef(name: "items", type: JsonPort.self),
                InputPortDef(name: "scores", type: JsonPort.self)
            ],
            outputs: [
                OutputPortDef(name: "selected", type: JsonPort.self)
            ],
            parameters: [
                NodeParameter(name: "k", type: .integer, defaultValue: .integer(5)),
                NodeParameter(name: "threshold", type: .number, defaultValue: .number(0.0))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: topK, executor: TopKSelectionExecutor())
    }

    // MARK: - Transform Primitives

    private static func registerTransformNodes(registry: NodeRegistry) async {
        // JSON Extract node
        let jsonExtract = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Transform", name: "JSONExtract"),
            displayName: "Extract from JSON",
            description: "Extract a value from JSON using a key path",
            category: "Primitives/Transform",
            inputs: [
                InputPortDef(name: "json", type: JsonPort.self)
            ],
            outputs: [
                OutputPortDef(name: "value", type: TextPort.self),
                OutputPortDef(name: "found", type: BoolPort.self)
            ],
            parameters: [
                NodeParameter(name: "keyPath", type: .text, defaultValue: .text(""))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: jsonExtract, executor: JSONExtractExecutor())

        // JSON Build node
        let jsonBuild = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Transform", name: "JSONBuild"),
            displayName: "Build JSON",
            description: "Build a JSON object from key-value pairs",
            category: "Primitives/Transform",
            inputs: [
                InputPortDef(name: "value1", type: TextPort.self, isRequired: false),
                InputPortDef(name: "value2", type: TextPort.self, isRequired: false),
                InputPortDef(name: "value3", type: TextPort.self, isRequired: false)
            ],
            outputs: [
                OutputPortDef(name: "json", type: JsonPort.self)
            ],
            parameters: [
                NodeParameter(name: "key1", type: .text, defaultValue: .text("field1")),
                NodeParameter(name: "key2", type: .text, defaultValue: .text("field2")),
                NodeParameter(name: "key3", type: .text, defaultValue: .text("field3"))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: jsonBuild, executor: JSONBuildExecutor())

        // Text Split node
        let textSplit = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Transform", name: "TextSplit"),
            displayName: "Split Text",
            description: "Split text by a delimiter",
            category: "Primitives/Transform",
            inputs: [
                InputPortDef(name: "text", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "parts", type: JsonPort.self),
                OutputPortDef(name: "count", type: NumberPort.self)
            ],
            parameters: [
                NodeParameter(name: "delimiter", type: .text, defaultValue: .text("\n")),
                NodeParameter(name: "removeEmpty", type: .boolean, defaultValue: .boolean(true))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: textSplit, executor: TextSplitExecutor())

        // Text Join node
        let textJoin = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Transform", name: "TextJoin"),
            displayName: "Join Text",
            description: "Join text parts with a delimiter",
            category: "Primitives/Transform",
            inputs: [
                InputPortDef(name: "parts", type: JsonPort.self)
            ],
            outputs: [
                OutputPortDef(name: "text", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "delimiter", type: .text, defaultValue: .text("\n"))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: textJoin, executor: TextJoinExecutor())
    }

    // MARK: - Utility Primitives

    private static func registerUtilityNodes(registry: NodeRegistry) async {
        // Debug node
        let debug = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Utility", name: "Debug"),
            displayName: "Debug",
            description: "Log a value for debugging (pass-through)",
            category: "Primitives/Utility",
            inputs: [
                InputPortDef(name: "input", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "output", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "label", type: .text, defaultValue: .text("Debug"))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: debug, executor: DebugExecutor())

        // Delay node
        let delay = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Utility", name: "Delay"),
            displayName: "Delay",
            description: "Delay execution for testing or rate limiting",
            category: "Primitives/Utility",
            inputs: [
                InputPortDef(name: "input", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "output", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "seconds", type: .number, defaultValue: .number(1.0))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: delay, executor: DelayExecutor())

        // Gate node (conditionally pass or block)
        let gate = NodeDescriptor(
            typeId: NodeTypeId(category: "Primitives/Utility", name: "Gate"),
            displayName: "Gate",
            description: "Conditionally pass or block a value",
            category: "Primitives/Utility",
            inputs: [
                InputPortDef(name: "input", type: TextPort.self),
                InputPortDef(name: "enable", type: BoolPort.self)
            ],
            outputs: [
                OutputPortDef(name: "output", type: TextPort.self, displayName: "Output (if enabled)")
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: gate, executor: GateExecutor())
    }
}

// MARK: - Primitive Executors

struct TokenCountExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let text = inputs["text"]?.as(TextPort.self)?.value ?? ""
        // Simple word-based approximation; real impl would use proper tokenizer
        let wordCount = text.split(separator: " ").count
        let estimatedTokens = Int(Double(wordCount) * 1.3) // Rough approximation
        return ["count": AnyPortValue(NumberPort(Double(estimatedTokens)))]
    }
}

struct TruncateToTokensExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let text = inputs["text"]?.as(TextPort.self)?.value ?? ""
        let maxTokens = instance.parameterValues["maxTokens"]?.intValue ?? 2048

        // Simple word-based approximation
        let words = text.split(separator: " ")
        let maxWords = Int(Double(maxTokens) / 1.3)

        if words.count <= maxWords {
            return [
                "truncated": AnyPortValue(TextPort(text)),
                "wasTruncated": AnyPortValue(BoolPort(false))
            ]
        } else {
            let truncated = words.prefix(maxWords).joined(separator: " ")
            return [
                "truncated": AnyPortValue(TextPort(truncated)),
                "wasTruncated": AnyPortValue(BoolPort(true))
            ]
        }
    }
}

struct PromptTemplateExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        var template = instance.parameterValues["template"]?.stringValue ?? ""
        let delimStart = instance.parameterValues["delimiterStart"]?.stringValue ?? "{{"
        let delimEnd = instance.parameterValues["delimiterEnd"]?.stringValue ?? "}}"

        // Replace variables from input JSON
        if let jsonPort = inputs["variables"]?.as(JsonPort.self),
           let variables = try? jsonPort.dictionary() {
            for (key, value) in variables {
                let placeholder = delimStart + key + delimEnd
                template = template.replacingOccurrences(
                    of: placeholder,
                    with: String(describing: value)
                )
            }
        }

        return ["prompt": AnyPortValue(TextPort(template))]
    }
}

struct ChatMessagesBuilderExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        var messages: [[String: Any]] = []

        // Add history if present
        if let historyPort = inputs["history"]?.as(JsonPort.self),
           let historyDict = try? historyPort.dictionary(),
           let historyMessages = historyDict["messages"] as? [[String: Any]] {
            messages.append(contentsOf: historyMessages)
        }

        // Add system prompt if present and no history
        if messages.isEmpty, let systemPrompt = inputs["systemPrompt"]?.as(TextPort.self)?.value {
            messages.append(["role": "system", "content": systemPrompt])
        }

        // Add user message
        if let userMessage = inputs["userMessage"]?.as(TextPort.self)?.value {
            messages.append(["role": "user", "content": userMessage])
        }

        let result = try JsonPort(["messages": messages])
        return ["messages": AnyPortValue(result)]
    }
}

struct SystemPromptExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let prompt = instance.parameterValues["prompt"]?.stringValue ?? ""
        return ["prompt": AnyPortValue(TextPort(prompt))]
    }
}

struct CosineSimilarityExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        // Get tensor ports
        guard let tensorA = inputs["a"]?.as(TensorPort.self),
              let tensorB = inputs["b"]?.as(TensorPort.self) else {
            throw GrapheneError.executionFailed(
                nodeId: context.nodeId,
                reason: "Missing tensor inputs"
            )
        }
        
        // Try to retrieve vectors from resource manager
        let vecA = await retrieveVector(from: tensorA, context: context)
        let vecB = await retrieveVector(from: tensorB, context: context)
        
        // Compute cosine similarity
        let similarity = cosineSimilarity(vecA, vecB)
        
        return ["similarity": AnyPortValue(NumberPort(similarity))]
    }
    
    private func retrieveVector(from tensor: TensorPort, context: GrapheneExecutionContext) async -> [Float] {
        // Try to get from resource manager first
        if let stored: [Float] = await context.resourceManager.get(key: tensor.storageKey, as: [Float].self) {
            return stored
        }
        
        // Fallback: generate random vector based on shape
        // For now, assume shape [dim] and dtype float32
        let dim = tensor.shape.first ?? 384
        return (0..<dim).map { _ in Float.random(in: -1...1) }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        
        var dot: Double = 0
        var na: Double = 0
        var nb: Double = 0
        for i in 0..<a.count {
            let x = Double(a[i])
            let y = Double(b[i])
            dot += x * y
            na += x * x
            nb += y * y
        }
        if na == 0 || nb == 0 { return 0.0 }
        let cos = dot / (sqrt(na) * sqrt(nb))
        // Clamp to [-1, 1] due to floating errors
        return max(-1.0, min(1.0, cos))
    }
}

struct TopKSelectionExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let k = instance.parameterValues["k"]?.intValue ?? 5
        let threshold = instance.parameterValues["threshold"]?.doubleValue ?? 0.0
        
        guard let itemsPort = inputs["items"]?.as(JsonPort.self),
              let scoresPort = inputs["scores"]?.as(JsonPort.self) else {
            throw GrapheneError.executionFailed(
                nodeId: context.nodeId,
                reason: "Missing items or scores input"
            )
        }
        
        // Parse JSON arrays
        let itemsArray = try parseJSONArray(itemsPort)
        let scoresArray = try parseJSONArray(scoresPort).compactMap { $0 as? Double }
        
        guard itemsArray.count == scoresArray.count else {
            throw GrapheneError.executionFailed(
                nodeId: context.nodeId,
                reason: "Items and scores arrays must have same length"
            )
        }
        
        // Zip and filter by threshold
        var paired = zip(itemsArray, scoresArray).map { ($0, $1) }
        if threshold > 0.0 {
            paired = paired.filter { $0.1 >= threshold }
        }
        
        // Sort by score descending
        paired.sort { $0.1 > $1.1 }
        
        // Take top k
        let selectedItems = paired.prefix(k).map { $0.0 }
        
        let selected = try JsonPort(["selected": selectedItems])
        return ["selected": AnyPortValue(selected)]
    }
    
    private func parseJSONArray(_ jsonPort: JsonPort) throws -> [Any] {
        let jsonObject = try JSONSerialization.jsonObject(with: jsonPort.data)
        if let array = jsonObject as? [Any] {
            return array
        } else if let dict = jsonObject as? [String: Any],
                  let array = dict["items"] as? [Any] ?? dict["parts"] as? [Any] ?? dict["values"] as? [Any] {
            return array
        } else {
            return []
        }
    }
}

struct JSONExtractExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let keyPath = instance.parameterValues["keyPath"]?.stringValue ?? ""

        guard let jsonPort = inputs["json"]?.as(JsonPort.self),
              let dict = try? jsonPort.dictionary() else {
            return [
                "value": AnyPortValue(TextPort("")),
                "found": AnyPortValue(BoolPort(false))
            ]
        }

        // Simple key path traversal (supports dot notation)
        var current: Any = dict
        for key in keyPath.split(separator: ".") {
            if let dict = current as? [String: Any], let next = dict[String(key)] {
                current = next
            } else {
                return [
                    "value": AnyPortValue(TextPort("")),
                    "found": AnyPortValue(BoolPort(false))
                ]
            }
        }

        return [
            "value": AnyPortValue(TextPort(String(describing: current))),
            "found": AnyPortValue(BoolPort(true))
        ]
    }
}

struct JSONBuildExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        var dict: [String: Any] = [:]

        for i in 1...3 {
            let keyParam = "key\(i)"
            let valueInput = "value\(i)"

            if let key = instance.parameterValues[keyParam]?.stringValue,
               !key.isEmpty,
               let value = inputs[valueInput]?.as(TextPort.self)?.value {
                dict[key] = value
            }
        }

        let json = try JsonPort(dict)
        return ["json": AnyPortValue(json)]
    }
}

struct TextSplitExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let text = inputs["text"]?.as(TextPort.self)?.value ?? ""
        let delimiter = instance.parameterValues["delimiter"]?.stringValue ?? "\n"
        let removeEmpty = instance.parameterValues["removeEmpty"]?.boolValue ?? true

        var parts = text.components(separatedBy: delimiter)
        if removeEmpty {
            parts = parts.filter { !$0.isEmpty }
        }

        let partsJson = try JsonPort(["parts": parts])
        return [
            "parts": AnyPortValue(partsJson),
            "count": AnyPortValue(NumberPort(Double(parts.count)))
        ]
    }
}

struct TextJoinExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let delimiter = instance.parameterValues["delimiter"]?.stringValue ?? "\n"

        guard let partsPort = inputs["parts"]?.as(JsonPort.self),
              let partsDict = try? partsPort.dictionary(),
              let parts = partsDict["parts"] as? [String] else {
            return ["text": AnyPortValue(TextPort(""))]
        }

        let joined = parts.joined(separator: delimiter)
        return ["text": AnyPortValue(TextPort(joined))]
    }
}

struct DebugExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let input = inputs["input"]?.as(TextPort.self)?.value ?? ""
        let label = instance.parameterValues["label"]?.stringValue ?? "Debug"

        // Log for debugging (would integrate with Observatorium in real impl)
        print("[\(label)] \(input.prefix(200))")

        // Pass through
        return ["output": AnyPortValue(TextPort(input))]
    }
}

struct DelayExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let input = inputs["input"]?.as(TextPort.self)?.value ?? ""
        let seconds = instance.parameterValues["seconds"]?.doubleValue ?? 1.0

        // Check for cancellation before sleeping
        if await context.cancellationToken.isCancelled {
            throw GrapheneError.executionFailed(
                nodeId: context.nodeId,
                reason: "Cancelled during delay"
            )
        }

        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

        return ["output": AnyPortValue(TextPort(input))]
    }
}

struct GateExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let input = inputs["input"]?.as(TextPort.self)?.value ?? ""
        let enable = inputs["enable"]?.as(BoolPort.self)?.value ?? true

        if enable {
            return ["output": AnyPortValue(TextPort(input))]
        } else {
            return ["output": AnyPortValue(TextPort(""))]
        }
    }
}
