import Foundation
import AnigmaPrimitives

/// High-level interface for deterministic text processing.
public final class TextPipelineCapsule {
    private let wrapper: TextPipelineCapsuleWrapper
    
    public init() throws {
        self.wrapper = try TextPipelineCapsuleWrapper()
    }
    
    /// Normalize text to NFC form.
    public func normalizeNFC(_ text: String) throws -> String {
        return try wrapper.normalizeNFC(text)
    }
    
    /// Convert text to lowercase.
    public func toLowercase(_ text: String) throws -> String {
        return try wrapper.toLowercase(text)
    }
    
    /// Remove diacritics from text.
    public func stripDiacritics(_ text: String) throws -> String {
        return try wrapper.stripDiacritics(text)
    }
    
    /// Fold text to ASCII for indexing.
    public func foldToASCII(_ text: String) throws -> String {
        return try wrapper.foldToASCII(text)
    }
    
    /// Validate UTF-8 encoding.
    public func validateUTF8(_ text: String) throws -> Bool {
        return try wrapper.validateUTF8(text)
    }
    
    /// Apply full transformation pipeline (normalize -> case -> diacritics -> fold).
    /// - Returns: The transformed text bytes.
    public func transform(_ text: String) throws -> Data {
        return try wrapper.transform(text)
    }
}
