import Foundation
#if canImport(llama)
import llama
#endif

/// llama.cpp-based inference provider for local LLM execution
@available(macOS 13.0, *)
public actor LlamaCppProvider {
    private var context: OpaquePointer?
    private var model: OpaquePointer?
    private let modelPath: String
    private let contextSize: Int
    private let threads: Int

    public init(modelPath: String, contextSize: Int = 2048, threads: Int = 0) {
        self.modelPath = modelPath
        self.contextSize = contextSize
        self.threads = threads == 0 ? ProcessInfo.processInfo.activeProcessorCount : threads
    }

    deinit {
        #if canImport(llama)
        if let ctx = context {
            llama_free(ctx)
        }
        if let mdl = model {
            llama_free_model(mdl)
        }
        #endif
    }

    public func initialize() async throws {
        #if canImport(llama)
        var params = llama_context_default_params()
        params.n_ctx = UInt32(contextSize)
        params.n_threads = Int32(threads)

        model = llama_load_model_from_file(modelPath, llama_model_default_params())
        guard let model = model else {
            throw LlamaCppError.modelLoadFailed
        }

        context = llama_new_context_with_model(model, params)
        guard context != nil else {
            throw LlamaCppError.contextCreationFailed
        }
        #else
        throw LlamaCppError.notAvailable
        #endif
    }

    public func generate(prompt: String, maxTokens: Int = 512, temperature: Float = 0.7) async throws -> String {
        #if canImport(llama)
        guard let context = context, let model = model else {
            throw LlamaCppError.notInitialized
        }

        // Tokenize prompt
        var tokens = [llama_token](repeating: 0, count: prompt.utf8.count + 1)
        let nTokens = llama_tokenize(model, prompt, Int32(prompt.utf8.count), &tokens, Int32(tokens.count), true, false)
        tokens = Array(tokens.prefix(Int(nTokens)))

        // Evaluate prompt
        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in tokens.enumerated() {
            llama_batch_add(&batch, token, Int32(i), [0], false)
        }
        batch.logits[Int(batch.n_tokens) - 1] = 1

        if llama_decode(context, batch) != 0 {
            throw LlamaCppError.decodeFailed
        }

        // Generate tokens
        var result = ""
        var nCur = Int(batch.n_tokens)

        for _ in 0..<maxTokens {
            let logits = llama_get_logits_ith(context, batch.n_tokens - 1)
            let nVocab = llama_n_vocab(model)

            var candidates = [llama_token_data]()
            candidates.reserveCapacity(Int(nVocab))
            for i in 0..<Int(nVocab) {
                candidates.append(llama_token_data(id: Int32(i), logit: logits![i], p: 0.0))
            }

            var candidatesP = llama_token_data_array(
                data: &candidates,
                size: candidates.count,
                sorted: false
            )

            llama_sample_temp(context, &candidatesP, temperature)
            let newToken = llama_sample_token(context, &candidatesP)

            // Check for EOS
            if llama_token_is_eog(model, newToken) {
                break
            }

            // Decode token
            var buffer = [CChar](repeating: 0, count: 32)
            let n = llama_token_to_piece(model, newToken, &buffer, Int32(buffer.count), false)
            if n > 0 {
                result += String(cString: buffer)
            }

            // Prepare next batch
            batch.n_tokens = 0
            llama_batch_add(&batch, newToken, Int32(nCur), [0], true)
            nCur += 1

            if llama_decode(context, batch) != 0 {
                throw LlamaCppError.decodeFailed
            }
        }

        return result
        #else
        throw LlamaCppError.notAvailable
        #endif
    }
}

public enum LlamaCppError: Error {
    case notAvailable
    case notInitialized
    case modelLoadFailed
    case contextCreationFailed
    case decodeFailed
    case tokenizationFailed
}

#if canImport(llama)
extension LlamaCppProvider {
    public func embed(text: String) async throws -> [Float] {
        guard let context = context, let model = model else {
            throw LlamaCppError.notInitialized
        }

        // Tokenize
        var tokens = [llama_token](repeating: 0, count: text.utf8.count + 1)
        let nTokens = llama_tokenize(model, text, Int32(text.utf8.count), &tokens, Int32(tokens.count), true, false)
        tokens = Array(tokens.prefix(Int(nTokens)))

        // Create batch for embeddings
        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in tokens.enumerated() {
            llama_batch_add(&batch, token, Int32(i), [0], false)
        }

        if llama_decode(context, batch) != 0 {
            throw LlamaCppError.decodeFailed
        }

        // Get embeddings
        let embdSize = Int(llama_n_embd(model))
        let embeddings = llama_get_embeddings(context)
        guard let embeddings = embeddings else {
            throw LlamaCppError.decodeFailed
        }

        return Array(UnsafeBufferPointer(start: embeddings, count: embdSize))
    }
}
#endif
