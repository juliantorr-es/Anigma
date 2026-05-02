import Foundation
import CoreGraphics
import AnigmaNativeShims
import PDFNative
import CapsuleCore
import TelemetryCore

public final class PDFDocument {
    internal let handle: CapsuleHandle<AnyObject>
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "pdfium-v1"
    
    public init(
        path: String,
        password: String? = nil,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "PDFDocument.initPath",
            category: "pdf.init",
            correlationID: nil,
            tags: [
                "source": "path",
                "has_password": "\(password != nil)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        var raw: anigma_pdf_document_t?
        var err = anigma_capsule_error_t()
        
        let status = path.withCString { pStr in
            if let pass = password {
                return pass.withCString { passStr in
                    anigma_pdf_document_create_from_path(pStr, passStr, &raw, &err)
                }
            } else {
                return anigma_pdf_document_create_from_path(pStr, nil, &raw, &err)
            }
        }
        
        guard status == ANIGMA_OK, let h = raw else {
            resolvedDiagnostics.event(
                level: .error,
                category: "pdf.init",
                message: "Failed to open PDF from path (status: \(status))",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw capsuleError(status: status, error: err)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_pdf_document_destroy)
        )
        self.diagnostics = resolvedDiagnostics
        span.end(status: .ok)
    }
    
    public init(
        data: Data,
        password: String? = nil,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "PDFDocument.initData",
            category: "pdf.init",
            correlationID: nil,
            tags: [
                "source": "data",
                "input_bytes": "\(data.count)",
                "has_password": "\(password != nil)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        var raw: anigma_pdf_document_t?
        var err = anigma_capsule_error_t()
        
        let status = data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return ANIGMA_ERR_INVALID_ARG }
            
            if let pass = password {
                return pass.withCString { passStr in
                    anigma_pdf_document_create_from_bytes(base, data.count, passStr, &raw, &err)
                }
            } else {
                return anigma_pdf_document_create_from_bytes(base, data.count, nil, &raw, &err)
            }
        }
        
        guard status == ANIGMA_OK, let h = raw else {
            resolvedDiagnostics.event(
                level: .error,
                category: "pdf.init",
                message: "Failed to open PDF from data (status: \(status))",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw capsuleError(status: status, error: err)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_pdf_document_destroy)
        )
        self.diagnostics = resolvedDiagnostics
        span.end(status: .ok)
    }
    
    public var pageCount: Int {
        let span = diagnostics.beginSpan(
            name: "PDFDocument.pageCount",
            category: "pdf.page_count",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var count: Int32 = 0
        var err = anigma_capsule_error_t()
        do {
            let status = try handle.withHandle { h in
                anigma_pdf_document_get_page_count(h, &count, &err)
            }
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "pdf.page_count",
                    message: "Failed to read page count (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                return 0
            }
            span.end(status: .ok)
        } catch {
            diagnostics.event(
                level: .error,
                category: "pdf.page_count",
                message: "Failed to read page count: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            return 0
        }
        return Int(count)
    }
    
    public func page(at index: Int) throws -> PDFPage {
        let span = diagnostics.beginSpan(
            name: "PDFDocument.page",
            category: "pdf.page",
            correlationID: nil,
            tags: [
                "page_index": "\(index)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        var rawPage: anigma_pdf_page_t?
        var err = anigma_capsule_error_t()
        
        let status = try handle.withHandle { h in
            anigma_pdf_page_load(h, Int32(index), &rawPage, &err)
        }
        
        guard status == ANIGMA_OK, let p = rawPage else {
            diagnostics.event(
                level: .error,
                category: "pdf.page",
                message: "Failed to load page (status: \(status))",
                correlationID: nil,
                tags: ["page_index": "\(index)"]
            )
            span.end(status: .error)
            throw capsuleError(status: status, error: err)
        }
        
        let pageHandle = CapsuleHandle<AnyObject>(
            rawHandle: p,
            destroyFunction: capsuleDestroyer(anigma_pdf_page_destroy)
        )
        
        span.end(status: .ok)
        return PDFPage(handle: pageHandle, diagnostics: diagnostics)
    }
}

public final class PDFPage {
    internal let handle: CapsuleHandle<AnyObject>
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "pdfium-v1"
    
    internal init(handle: CapsuleHandle<AnyObject>, diagnostics: CapsuleDiagnostics) {
        self.handle = handle
        self.diagnostics = diagnostics
    }
    
    public var size: CGSize {
        let span = diagnostics.beginSpan(
            name: "PDFPage.size",
            category: "pdf.page.size",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var w: Double = 0
        var h: Double = 0
        var err = anigma_capsule_error_t()
        do {
            let status = try handle.withHandle { ptr in
                anigma_pdf_page_get_size(ptr, &w, &h, &err)
            }
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "pdf.page.size",
                    message: "Failed to read page size (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                return .zero
            }
            span.end(status: .ok)
        } catch {
            diagnostics.event(
                level: .error,
                category: "pdf.page.size",
                message: "Failed to read page size: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            return .zero
        }
        return CGSize(width: w, height: h)
    }
    
    public var text: String {
        let span = diagnostics.beginSpan(
            name: "PDFPage.text",
            category: "pdf.page.text",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var textPtr: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        do {
            let status = try handle.withHandle { ptr in
                anigma_pdf_page_get_text(ptr, &textPtr, &err)
            }
            if status == ANIGMA_OK, let cStr = textPtr {
                let str = String(cString: cStr)
                free(cStr)
                span.end(status: .ok)
                return str
            }
            diagnostics.event(
                level: .error,
                category: "pdf.page.text",
                message: "Failed to extract text (status: \(status))",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            return ""
        } catch {
            diagnostics.event(
                level: .error,
                category: "pdf.page.text",
                message: "Failed to extract text: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            return ""
        }
    }
    
    public func render(width: Int, height: Int) throws -> PDFBitmap {
        let span = diagnostics.beginSpan(
            name: "PDFPage.render",
            category: "pdf.page.render",
            correlationID: nil,
            tags: [
                "width": "\(width)",
                "height": "\(height)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        var rawBitmap: anigma_pdf_bitmap_t?
        var err = anigma_capsule_error_t()
        
        var status = anigma_pdf_bitmap_create(Int32(width), Int32(height), true, &rawBitmap, &err)
        guard status == ANIGMA_OK, let bmp = rawBitmap else {
            diagnostics.event(
                level: .error,
                category: "pdf.page.render",
                message: "Failed to create bitmap (status: \(status))",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw capsuleError(status: status, error: err)
        }
        
        let bitmapHandle = CapsuleHandle<AnyObject>(
            rawHandle: bmp,
            destroyFunction: capsuleDestroyer(anigma_pdf_bitmap_destroy)
        )
        
        // Render
        status = try handle.withHandle { pagePtr in
            try bitmapHandle.withHandle { bmpPtr in
                anigma_pdf_page_render_to_bitmap(
                    pagePtr, bmpPtr,
                    0, 0, Int32(width), Int32(height),
                    0, 0x10,
                    &err
                )
            }
        }
        
        if status != ANIGMA_OK {
            diagnostics.event(
                level: .error,
                category: "pdf.page.render",
                message: "Render failed (status: \(status))",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw capsuleError(status: status, error: err)
        }
        
        span.end(status: .ok)
        return PDFBitmap(handle: bitmapHandle, width: width, height: height, diagnostics: diagnostics)
    }
}

public final class PDFBitmap {
    internal let handle: CapsuleHandle<AnyObject>
    public let width: Int
    public let height: Int
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "pdfium-v1"
    
    internal init(handle: CapsuleHandle<AnyObject>, width: Int, height: Int, diagnostics: CapsuleDiagnostics) {
        self.handle = handle
        self.width = width
        self.height = height
        self.diagnostics = diagnostics
    }
    
    public func withUnsafeBuffer<T>(_ body: (UnsafeBufferPointer<UInt8>, Int) throws -> T) throws -> T {
        let span = diagnostics.beginSpan(
            name: "PDFBitmap.withUnsafeBuffer",
            category: "pdf.bitmap.buffer",
            correlationID: nil,
            tags: [
                "width": "\(width)",
                "height": "\(height)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        var buffer: UnsafeMutablePointer<UInt8>?
        var stride: Int32 = 0
        var err = anigma_capsule_error_t()
        
        let status = try handle.withHandle { ptr in
            anigma_pdf_bitmap_get_buffer(ptr, &buffer, &stride, &err)
        }
        
        guard status == ANIGMA_OK, let buf = buffer else {
            diagnostics.event(
                level: .error,
                category: "pdf.bitmap.buffer",
                message: "Failed to read bitmap buffer (status: \(status))",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw capsuleError(status: status, error: err)
        }
        
        let length = Int(stride) * height
        let ptr = UnsafeBufferPointer(start: buf, count: length)
        do {
            let value = try body(ptr, Int(stride))
            span.end(status: .ok)
            return value
        } catch {
            diagnostics.event(
                level: .error,
                category: "pdf.bitmap.buffer",
                message: "Bitmap buffer consumer failed: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleNativeError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleNativeError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
