import Foundation
import AnigmaNativeShims
import MarkdownNative

public struct MarkdownCapsuleError: Error, Sendable, CustomStringConvertible {
    public let status: anigma_status_t
    public let code: anigma_status_t
    public let message: String

    public var description: String {
        "MarkdownCapsuleError(status: \(status), code: \(code), message: \(message))"
    }
}

public final class MarkdownDocument {
    private var handle: anigma_markdown_node_t

    public init(markdown: String, options: Int32 = 0) throws {
        var raw: anigma_markdown_node_t?
        var err = anigma_capsule_error_t()

        let status = markdown.withCString { cString in
            anigma_markdown_parse_string(cString, markdown.utf8.count, options, &raw, &err)
        }

        guard status == ANIGMA_OK, let valid = raw else {
            throw capsuleError(status: status, error: err)
        }

        handle = valid
    }

    deinit {
        var err = anigma_capsule_error_t()
        _ = anigma_markdown_node_destroy(handle, &err)
    }

    public func renderHTML(options: Int32 = 0) throws -> String {
        var output: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        let status = anigma_markdown_render_html(handle, options, &output, &err)
        guard status == ANIGMA_OK, let out = output else {
            throw capsuleError(status: status, error: err)
        }
        defer { free(out) }
        return String(cString: out)
    }

    public func renderPlaintext(options: Int32 = 0, width: Int32 = 0) throws -> String {
        var output: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        let status = anigma_markdown_render_plaintext(handle, options, width, &output, &err)
        guard status == ANIGMA_OK, let out = output else {
            throw capsuleError(status: status, error: err)
        }
        defer { free(out) }
        return String(cString: out)
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> MarkdownCapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return MarkdownCapsuleError(status: error.code, code: error.code, message: message)
}
