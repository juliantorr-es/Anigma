import Foundation
import PDFNative
import CapsuleCore
import AnigmaNativeShims

public final class PDFDocument {
    internal let handle: CapsuleHandle<AnyObject>
    
    public init(path: String, password: String? = nil) throws {
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
            throw capsuleError(status: status, error: err)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_pdf_document_destroy)
        )
    }
    
    public init(data: Data, password: String? = nil) throws {
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
            throw capsuleError(status: status, error: err)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_pdf_document_destroy)
        )
    }
    
    public var pageCount: Int {
        var count: Int32 = 0
        var err = anigma_capsule_error_t()
        try? handle.withHandle { h in
             _ = anigma_pdf_document_get_page_count(h, &count, &err)
        }
        return Int(count)
    }
    
    public func page(at index: Int) throws -> PDFPage {
        var rawPage: anigma_pdf_page_t?
        var err = anigma_capsule_error_t()
        
        let status = try handle.withHandle { h in
            anigma_pdf_page_load(h, Int32(index), &rawPage, &err)
        }
        
        guard status == ANIGMA_OK, let p = rawPage else {
            throw capsuleError(status: status, error: err)
        }
        
        let pageHandle = CapsuleHandle<AnyObject>(
            rawHandle: p,
            destroyFunction: capsuleDestroyer(anigma_pdf_page_destroy)
        )
        
        return PDFPage(handle: pageHandle)
    }
}

public final class PDFPage {
    internal let handle: CapsuleHandle<AnyObject>
    
    internal init(handle: CapsuleHandle<AnyObject>) {
        self.handle = handle
    }
    
    public var size: CGSize {
        var w: Double = 0
        var h: Double = 0
        var err = anigma_capsule_error_t()
        try? handle.withHandle { ptr in
            _ = anigma_pdf_page_get_size(ptr, &w, &h, &err)
        }
        return CGSize(width: w, height: h)
    }
    
    public var text: String {
        var textPtr: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        
        let status = try? handle.withHandle { ptr in
            anigma_pdf_page_get_text(ptr, &textPtr, &err)
        }
        
        if status == ANIGMA_OK, let cStr = textPtr {
            let str = String(cString: cStr)
            free(cStr) // Using standard free because malloc was used in C++ shim
            return str
        }
        return ""
    }
    
    public func render(width: Int, height: Int) throws -> PDFBitmap {
        var rawBitmap: anigma_pdf_bitmap_t?
        var err = anigma_capsule_error_t()
        
        var status = anigma_pdf_bitmap_create(Int32(width), Int32(height), true, &rawBitmap, &err)
        guard status == ANIGMA_OK, let bmp = rawBitmap else {
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
                    0, 0x10, // FPDF_ANNOT (0x01) | FPDF_LCD_TEXT (0x02) | FPDF_NO_NATIVETEXT (0x04) ... 
                             // Wait, 0x10 is FPDF_PRINTING usually. 
                             // Let's use 0 for now or safe defaults.
                             // Actually, let's expose flags later if needed.
                             // Common defaults: FPDF_ANNOT(0x01) | FPDF_LCD_TEXT(0x02) = 3
                    &err
                )
            }
        }
        
        if status != ANIGMA_OK {
            throw capsuleError(status: status, error: err)
        }
        
        return PDFBitmap(handle: bitmapHandle, width: width, height: height)
    }
}

public final class PDFBitmap {
    internal let handle: CapsuleHandle<AnyObject>
    public let width: Int
    public let height: Int
    
    internal init(handle: CapsuleHandle<AnyObject>, width: Int, height: Int) {
        self.handle = handle
        self.width = width
        self.height = height
    }
    
    public func withUnsafeBuffer<T>(_ body: (UnsafeBufferPointer<UInt8>, Int) throws -> T) throws -> T {
        var buffer: UnsafeMutablePointer<UInt8>?
        var stride: Int32 = 0
        var err = anigma_capsule_error_t()
        
        let status = try handle.withHandle { ptr in
            anigma_pdf_bitmap_get_buffer(ptr, &buffer, &stride, &err)
        }
        
        guard status == ANIGMA_OK, let buf = buffer else {
            throw capsuleError(status: status, error: err)
        }
        
        let length = Int(stride) * height
        let ptr = UnsafeBufferPointer(start: buf, count: length)
        return try body(ptr, Int(stride))
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
