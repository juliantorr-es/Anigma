//
//  OOXMLKit.swift
//  OOXMLKit
//
//  Format-level OOXML manipulation.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import ContainerKit

public protocol OOXMLPatchable: Sendable {
    func apply(patch: Data, to document: Data) throws -> Data
}

/// Thread-safe OOXML patcher using native XML manipulation.
public final class NativeOOXMLPatcher: OOXMLPatchable, @unchecked Sendable {
    public init() {}

    public func apply(patch: Data, to document: Data) throws -> Data {
        var ctx = anigma_ctx_t()

        // 1. Parse Document
        var docPtr: anigma_xml_doc_t?
        try document.withUnsafeNativeBytes { ptr, len in
            let res = anigma_xml_parse(&ctx, ptr, len, &docPtr)
            if res.status != ANIGMA_OK { throw NativeError(status: Int32(res.status.rawValue), context: "xml_parse") }
        }

        guard let xmlHandle = docPtr else { throw NativeError(status: -1, context: "xml_null") }
        defer {
            anigma_xml_destroy(xmlHandle)
        }

        // 2. Apply Patch
        try patch.withUnsafeNativeBytes { ptr, len in
            let res = anigma_xml_apply_patch(xmlHandle, &ctx, ptr, len)
            if res.status != ANIGMA_OK { throw NativeError(status: Int32(res.status.rawValue), context: "xml_patch") }
        }

        // 3. Serialize
        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let res = anigma_xml_serialize(xmlHandle, &ctx, &outBuf, &outLen)

        if res.status != ANIGMA_OK { throw NativeError(status: Int32(res.status.rawValue), context: "xml_serialize") }

        guard let buf = outBuf else { return Data() }
        defer { anigma_free_buffer(buf) }
        return Data(bytes: buf, count: outLen)
    }
}
